import Foundation

/// Orchestrates the complete task execution pipeline
public final class TaskExecutionPipeline {
    private let taskRepository: TaskRepository
    private let taskRunRepository: TaskRunRepository
    private let contentRepository: GeneratedContentRepository
    private let approvalQueueRepository: ApprovalQueueRepository
    private let taskTypeRepository: TaskTypeRepository
    private let workerManager: WorkerProcessManager
    private let schemaValidator: TaskSchemaValidator
    private let logger = AppLogger.taskEngine

    public init(
        taskRepository: TaskRepository,
        taskRunRepository: TaskRunRepository,
        contentRepository: GeneratedContentRepository,
        approvalQueueRepository: ApprovalQueueRepository,
        taskTypeRepository: TaskTypeRepository,
        workerManager: WorkerProcessManager,
        schemaValidator: TaskSchemaValidator
    ) {
        self.taskRepository = taskRepository
        self.taskRunRepository = taskRunRepository
        self.contentRepository = contentRepository
        self.approvalQueueRepository = approvalQueueRepository
        self.taskTypeRepository = taskTypeRepository
        self.workerManager = workerManager
        self.schemaValidator = schemaValidator
    }

    /// Execute a task (called by SchedulerEngine when task is due)
    public func execute(task: TaskRecord, schedule: TaskScheduleRecord) async {
        let runId = UUID().uuidString
        let startTime = Date()

        do {
            // 1. Validate task metadata against schema
            try await validateTaskMetadata(task: task)

            // 2. Create task run record
            var run = TaskRunRecord(
                id: runId,
                taskId: task.id,
                agentId: task.agentId,
                triggerSource: schedule.scheduleKind == "one_time" && schedule.cronExpression.isEmpty
                    ? "manual" : "scheduled",
                scheduledFor: schedule.nextRunAt ?? Date()
            )
            run.status = "running"
            run.startedAt = startTime
            run = try await taskRunRepository.create(run: run)

            // 3. Spawn worker process
            let taskMetadata = parseTaskMetadata(task.taskMetadataJson)
            let arguments = buildArguments(metadata: taskMetadata, runId: runId)

            let spawnResult = try await workerManager.spawn(
                scriptPath: task.goScriptPath,
                arguments: arguments,
                environment: ["TASK_RUN_ID": runId],
                taskRunId: runId
            )

            // Update run with PID
            var runningRun = run
            runningRun.workerPid = spawnResult.pid
            runningRun.stdoutLogPath = spawnResult.stdoutPath
            runningRun.stderrLogPath = spawnResult.stderrPath
            _ = try await taskRunRepository.update(run: runningRun)

            // 4. Wait for completion
            let exit = await workerManager.wait(for: spawnResult.pid)

            // 5. Process result
            let completedRun = try await self.processResult(
                run: runningRun,
                exit: exit,
                task: task
            )

            logger.info("Task completed: \(task.taskName) (exit: \(exit.exitCode))")

        } catch {
            logger.error("Task execution failed: \(error)")

            // Record failure
            let failedRun = TaskRunRecord(
                id: runId,
                taskId: task.id,
                agentId: task.agentId,
                triggerSource: "scheduled",
                scheduledFor: schedule.nextRunAt ?? Date(),
                startedAt: startTime,
                completedAt: Date(),
                status: "failed",
                errorMessage: error.localizedDescription
            )
            _ = try? await taskRunRepository.create(run: failedRun)
        }
    }

    /// Retry a failed task run
    public func retry(runId: String) async throws {
        guard let originalRun = try await taskRunRepository.getById(id: runId) else {
            throw AppError.taskExecutionFailed("Run not found: \(runId)")
        }

        guard originalRun.status == "failed" else {
            throw AppError.taskExecutionFailed("Can only retry failed runs")
        }

        guard let task = try await taskRepository.getById(id: originalRun.taskId) else {
            throw AppError.taskExecutionFailed("Task not found: \(originalRun.taskId)")
        }

        // Create manual schedule for retry
        let schedule = TaskScheduleRecord(
            taskId: task.id,
            scheduleKind: "one_time",
            schedulePayloadJson: "{}",
            cronExpression: "",
            timezone: TimeZone.current.identifier,
            nextRunAt: Date(),
            isActive: true
        )

        logger.info("Retrying task: \(task.taskName) (original run: \(runId))")
        await execute(task: task, schedule: schedule)
    }

    // MARK: - Private Methods

    private func validateTaskMetadata(task: TaskRecord) async throws {
        guard let taskType = try await taskTypeRepository.getById(id: task.taskTypeId) else {
            throw AppError.invalidTaskConfiguration("Task type not found: \(task.taskTypeId)")
        }

        let result = schemaValidator.validate(
            metadataJson: task.taskMetadataJson,
            schemaJson: taskType.jsonSchema
        )

        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    private func parseTaskMetadata(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func buildArguments(metadata: [String: Any], runId: String) -> [String] {
        var args: [String] = []

        // Add metadata as JSON argument
        if let metadataData = try? JSONSerialization.data(withJSONObject: metadata),
           let metadataString = String(data: metadataData, encoding: .utf8) {
            args.append("--metadata")
            args.append(metadataString)
        }

        args.append("--run-id")
        args.append(runId)

        return args
    }

    private func processResult(
        run: TaskRunRecord,
        exit: ProcessExit,
        task: TaskRecord
    ) async throws -> TaskRunRecord {
        var completedRun = run
        completedRun.completedAt = Date()
        completedRun.exitCode = exit.exitCode

        if exit.isSuccess {
            completedRun.status = "completed"

            // Try to read generated content from output
            do {
                let content = try await ingestGeneratedContent(
                    run: completedRun,
                    task: task
                )
                logger.info("Ingested content: \(content.id)")
            } catch {
                logger.error("Failed to ingest content: \(error)")
                completedRun.status = "failed"
                completedRun.errorMessage = "Content ingestion failed: \(error.localizedDescription)"
            }
        } else {
            completedRun.status = "failed"
            completedRun.errorMessage = exit.error ?? "Process exited with code \(exit.exitCode)"
        }

        return try await taskRunRepository.update(run: completedRun)
    }

    private func ingestGeneratedContent(
        run: TaskRunRecord,
        task: TaskRecord
    ) async throws -> GeneratedContentRecord {
        // Read stdout for JSON output
        guard let stdoutPath = run.stdoutLogPath,
              let data = FileManager.default.contents(atPath: stdoutPath),
              let output = String(data: data, encoding: .utf8) else {
            throw AppError.taskExecutionFailed("No output from worker")
        }

        // Parse JSON output
        guard let jsonData = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AppError.invalidJSON("Worker output is not valid JSON")
        }

        // Extract content
        let title = json["title"] as? String ?? "Untitled"
        let contentJson = (json["content"] as? [String: Any]) ?? json

        guard let contentData = try? JSONSerialization.data(withJSONObject: contentJson),
              let contentString = String(data: contentData, encoding: .utf8) else {
            throw AppError.invalidJSON("Failed to serialize content")
        }

        // Create generated content record
        let content = GeneratedContentRecord(
            taskRunId: run.id,
            agentId: task.agentId,
            title: title,
            generatedContentJson: contentString
        )
        let savedContent = try await contentRepository.create(content: content)

        // Create initial version
        let version = GeneratedContentVersionRecord(
            generatedContentId: savedContent.id,
            version: 1,
            contentSnapshotJson: contentString,
            changeReason: "Initial generation",
            editedBy: "agent"
        )
        _ = try await contentRepository.createVersion(version: version)

        // Add to approval queue
        let queueEntry = ApprovalQueueRecord(
            generatedContentId: savedContent.id,
            approvalStatus: "pending"
        )
        _ = try await approvalQueueRepository.create(entry: queueEntry)

        return savedContent
    }
}

