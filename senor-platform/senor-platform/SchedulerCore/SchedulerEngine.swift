import Foundation
import GRDB
#if canImport(GRDB)
@preconcurrency import GRDB
#endif

/// Engine that polls schedules and triggers task execution
public actor SchedulerEngine {
    private let scheduleRepository: TaskScheduleRepository
    private let taskRepository: TaskRepository
    private let taskRunRepository: TaskRunRepository
    private let logger = AppLogger.scheduler

    private var isRunning: Bool = false
    private var pollTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 30.0 // Check every 30 seconds

    /// Callback for when a task is due (injected by TaskExecutionPipeline)
    private let onTaskDue: (@Sendable (TaskRecord, TaskScheduleRecord) async -> Void)?

    public init(
        scheduleRepository: TaskScheduleRepository,
        taskRepository: TaskRepository,
        taskRunRepository: TaskRunRepository,
        onTaskDue: (@Sendable (TaskRecord, TaskScheduleRecord) async -> Void)? = nil
    ) {
        self.scheduleRepository = scheduleRepository
        self.taskRepository = taskRepository
        self.taskRunRepository = taskRunRepository
        self.onTaskDue = onTaskDue
    }

    public func startup() async throws {
        logger.info("SchedulerEngine startup beginning...")
        isRunning = true
        logger.info("Starting polling loop...")
        startPolling()
        logger.info("Polling loop started, reconciling schedules...")

        // Reconcile any stale schedules
        try await reconcileSchedules()
        logger.info("SchedulerEngine startup complete")
    }

    public func shutdown() async throws {
        isRunning = false
        pollTask?.cancel()
        logger.info("SchedulerEngine shutdown")
    }

    // MARK: - Polling Loop

    private func startPolling() {
        pollTask = Task {
            while await self.isRunning {
                do {
                    try await self.checkAndTriggerDueTasks()
                } catch {
                    await MainActor.run {
                        self.logger.error("Error in polling loop: \(error)")
                    }
                }

                // Wait for next poll interval or cancellation
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
            }
        }
    }

    /// Check for due tasks and trigger them
    public func checkAndTriggerDueTasks() async throws {
        let now = Date()
        let dueSchedules = try await scheduleRepository.listDue(before: now)

        guard !dueSchedules.isEmpty else { return }

        logger.info("Found \(dueSchedules.count) due schedule(s)")

        for schedule in dueSchedules {
            // Load the task
            guard let task = try await taskRepository.getById(id: schedule.taskId) else {
                logger.error("Task not found for schedule: \(schedule.id)")
                continue
            }

            // Check if task is enabled
            guard task.isEnabled else {
                logger.debug("Skipping disabled task: \(task.id)")
                continue
            }

            // Trigger execution
            logger.info("Triggering task: \(task.taskName) (schedule: \(schedule.id))")
            await onTaskDue?(task, schedule)

            // Update next run time for recurring schedules
            try await updateNextRunTime(schedule: schedule)
        }
    }

    /// Manually trigger a task (one-time execution)
    public func triggerTaskNow(taskId: String) async throws {
        guard let task = try await taskRepository.getById(id: taskId) else {
            throw AppError.invalidTaskConfiguration("Task not found: \(taskId)")
        }

        // Create a one-time schedule for immediate execution
        let schedule = TaskScheduleRecord(
            taskId: taskId,
            scheduleKind: ScheduleKind.oneTime.rawValue,
            schedulePayloadJson: "{}",
            cronExpression: "",
            timezone: TimeZone.current.identifier,
            nextRunAt: Date(),
            isActive: true
        )

        logger.info("Manually triggering task: \(task.taskName)")
        await onTaskDue?(task, schedule)
    }

    /// Calculate and update next run time for a schedule
    private func updateNextRunTime(schedule: TaskScheduleRecord) async throws {
        guard schedule.scheduleKind == ScheduleKind.recurring.rawValue else {
            // One-time schedule - deactivate after execution
            var updated = schedule
            updated.isActive = false
            updated.nextRunAt = nil
            _ = try await scheduleRepository.update(schedule: updated)
            return
        }

        // Parse schedule spec and calculate next run
        guard let specData = schedule.schedulePayloadJson.data(using: .utf8),
              let spec = try? JSONDecoder().decode(ScheduleSpec.self, from: specData) else {
            logger.error("Failed to parse schedule spec: \(schedule.id)")
            return
        }

        let compiler = ScheduleCompiler()
        guard let nextRun = compiler.nextRunTime(from: spec, after: Date()) else {
            // No more runs scheduled
            var updated = schedule
            updated.isActive = false
            updated.nextRunAt = nil
            _ = try await scheduleRepository.update(schedule: updated)
            return
        }

        var updated = schedule
        updated.nextRunAt = nextRun
        _ = try await scheduleRepository.update(schedule: updated)

        logger.debug("Updated next run for schedule \(schedule.id) to \(nextRun)")
    }

    /// Reconcile schedules on startup (handle missed runs, etc.)
    private func reconcileSchedules() async throws {
        logger.info("Reconcile schedules starting...")
        let now = Date()
        let staleThreshold = now.addingTimeInterval(-3600) // 1 hour ago

        // Find schedules that are past due but still active
        logger.info("Fetching stale schedules...")
        let staleSchedules = try await scheduleRepository.listDue(before: staleThreshold)
        logger.info("Found \(staleSchedules.count) stale schedules")

        for schedule in staleSchedules {
            logger.warning("Reconciling stale schedule: \(schedule.id)")

            // For recurring schedules, recalculate next run from now
            if schedule.scheduleKind == ScheduleKind.recurring.rawValue {
                try await updateNextRunTime(schedule: schedule)
            } else {
                // One-time schedules that are way past due - deactivate
                var updated = schedule
                updated.isActive = false
                updated.nextRunAt = nil
                _ = try await scheduleRepository.update(schedule: updated)
            }
        }

        // Also check for any "running" task runs that may be orphaned
        logger.info("Checking for orphaned task runs...")
        let activeRuns = try await taskRunRepository.listActive()
        logger.info("Found \(activeRuns.count) active task runs")

        for run in activeRuns {
            // If running for more than 1 hour, mark as failed
            if let startTime = run.startedAt, startTime < staleThreshold {
                logger.warning("Marking stale task run as failed: \(run.id)")
                var updated = run
                updated.status = "failed"
                updated.completedAt = now
                updated.errorMessage = "Task timed out (running > 1 hour)"
                _ = try await taskRunRepository.update(run: updated)
            }
        }
        logger.info("Reconcile schedules complete")
    }

    /// Get next scheduled run time for a task
    public func getNextRunTime(taskId: String) async throws -> Date? {
        guard let schedule = try await scheduleRepository.getByTask(taskId: taskId) else {
            return nil
        }
        return schedule.nextRunAt
    }

    /// Preview upcoming runs for a schedule
    public func previewUpcomingRuns(scheduleId: String, count: Int) async throws -> [Date] {
        guard let schedule = try await scheduleRepository.getById(id: scheduleId) else {
            throw AppError.invalidScheduleConfiguration("Schedule not found: \(scheduleId)")
        }

        guard let specData = schedule.schedulePayloadJson.data(using: .utf8),
              let spec = try? JSONDecoder().decode(ScheduleSpec.self, from: specData) else {
            return []
        }

        let compiler = ScheduleCompiler()
        return compiler.nextRunTimes(from: spec, count: count, after: Date())
    }
}
