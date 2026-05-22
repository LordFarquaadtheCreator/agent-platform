import Foundation

public struct LoadWorkspaceUseCase {
    let agentRepository: AgentRepository
    let taskRepository: TaskRepository
    let taskScheduleRepository: TaskScheduleRepository
    let taskRunRepository: TaskRunRepository
    let contentRepository: GeneratedContentRepository
    let approvalQueueRepository: ApprovalQueueRepository
    let publicationRepository: PublicationTargetRepository

    public func execute() async throws -> WorkspaceSnapshot {
        let agentRecords = try await agentRepository.listAll()
        let taskRecords = try await taskRepository.listEnabled()
        let contentRecords = try await contentRepository.listRecent(limit: 100)
        let approvalRecords = try await approvalQueueRepository.listPending(limit: 100)

        async let agentsTask = buildAgents(from: agentRecords)
        async let tasksTask = buildTasks(from: taskRecords)
        async let contentTask = buildContent(from: contentRecords)
        async let approvalsTask = buildApprovals(from: approvalRecords)

        let agents = try await agentsTask
        let tasks = try await tasksTask
        let content = try await contentTask
        let approvals = try await approvalsTask

        let dashboard = DashboardSnapshot(
            activeAgentCount: agents.filter { $0.status == .running || $0.status == .idle }.count,
            pendingApprovalCount: approvals.count,
            scheduledTaskCount: tasks.filter(\.isEnabled).count,
            publishedContentCount: content.filter { $0.status == .published }.count,
            recentContent: Array(content.prefix(5))
        )

        return WorkspaceSnapshot(
            agents: agents,
            tasks: tasks,
            content: content,
            approvals: approvals
                .sorted { $0.submittedAt > $1.submittedAt },
            dashboard: dashboard
        )
    }

    private func buildAgents(from records: [AgentRecord]) async throws -> [Agent] {
        try await withThrowingTaskGroup(of: Agent.self) { group in
            for record in records {
                group.addTask {
                    let taskCount = try await taskRepository.countByAgent(agentId: record.id)
                    return Agent(record: record, taskCount: taskCount)
                }
            }

            var agents: [Agent] = []
            for try await agent in group {
                agents.append(agent)
            }
            return agents.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    private func buildTasks(from records: [TaskRecord]) async throws -> [TaskSummary] {
        try await withThrowingTaskGroup(of: TaskSummary.self) { group in
            for record in records {
                group.addTask {
                    let schedule = try await taskScheduleRepository.getByTask(taskId: record.id)
                    let runs = try await taskRunRepository.listByTask(taskId: record.id, limit: 1)
                    return TaskSummary(record: record, schedule: schedule, lastRun: runs.first)
                }
            }

            var tasks: [TaskSummary] = []
            for try await task in group {
                tasks.append(task)
            }
            return tasks.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func buildContent(from records: [GeneratedContentRecord]) async throws -> [ContentSummary] {
        try await withThrowingTaskGroup(of: ContentSummary.self) { group in
            for record in records {
                group.addTask {
                    let status = try await resolveContentStatus(contentId: record.id)
                    return ContentSummary(record: record, status: status)
                }
            }

            var content: [ContentSummary] = []
            for try await item in group {
                content.append(item)
            }
            return content.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func buildApprovals(from records: [ApprovalQueueRecord]) async throws -> [ApprovalSummary] {
        try await withThrowingTaskGroup(of: ApprovalSummary?.self) { group in
            for record in records {
                group.addTask {
                    guard let content = try await contentRepository.getById(id: record.generatedContentId),
                          let agent = try await agentRepository.getById(id: content.agentId) else {
                        return nil
                    }

                    return ApprovalSummary(
                        id: record.id,
                        contentId: content.id,
                        contentTitle: content.title,
                        agentName: agent.displayName,
                        submittedAt: record.createdAt
                    )
                }
            }

            var approvals: [ApprovalSummary] = []
            for try await item in group {
                if let item {
                    approvals.append(item)
                }
            }
            return approvals
        }
    }

    private func resolveContentStatus(contentId: String) async throws -> ContentWorkflowStatus {
        let publications = try await publicationRepository.listByContent(contentId: contentId)
        if publications.contains(where: { $0.state == .published }) {
            return .published
        }

        guard let approval = try await approvalQueueRepository.getByContent(contentId: contentId) else {
            return .pending
        }

        switch approval.approvalStatus {
        case ApprovalStatus.approved.rawValue:
            return .approved

        case ApprovalStatus.rejected.rawValue:
            return .rejected

        default:
            return .pending
        }
    }
}

public struct LoadTaskCreationContextUseCase {
    let agentRepository: AgentRepository
    let taskTypeRepository: TaskTypeRepository

    public func execute() async throws -> TaskCreationContext {
        let agents = try await agentRepository.listAll()
        let taskTypes = try await taskTypeRepository.listAll()

        return TaskCreationContext(
            agents: agents.map { Agent(record: $0, taskCount: 0) }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            taskTypes: taskTypes.map(TaskTypeSummary.init(record:))
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        )
    }
}

public struct CreateAgentUseCase {
    let agentRepository: AgentRepository

    public func execute(_ draft: AgentDraft) async throws -> Agent {
        let record = AgentRecord(
            displayName: draft.displayName,
            status: draft.isActive ? .idle : .paused,
            nameSource: "manual",
            nameSeed: 0
        )
        let saved = try await agentRepository.create(agent: record)
        return Agent(record: saved, taskCount: 0)
    }
}

public struct CreateTaskUseCase {
    let taskRepository: TaskRepository
    let scheduleRepository: TaskScheduleRepository
    let settingsService: SettingsService

    public func execute(_ draft: TaskDraft) async throws -> TaskSummary {
        guard JSONUtils.validate(draft.metadataJSON) else {
            throw AppError.invalidJSON("Task metadata must be valid JSON")
        }

        let task = TaskRecord(
            agentId: draft.agentId,
            taskTypeId: draft.taskTypeId,
            taskName: draft.taskName,
            taskMetadataJson: draft.metadataJSON,
            goScriptPath: settingsService.taskScriptPath(),
            isEnabled: true
        )

        let savedTask = try await taskRepository.create(task: task)
        var scheduleRecord: TaskScheduleRecord?

        if let schedule = draft.schedule {
            scheduleRecord = try await createSchedule(taskId: savedTask.id, schedule: schedule)
        }

        return TaskSummary(record: savedTask, schedule: scheduleRecord, lastRun: nil)
    }

    private func createSchedule(taskId: String, schedule: ScheduleDraft) async throws -> TaskScheduleRecord {
        let spec = buildSpec(from: schedule)
        let compiler = ScheduleCompiler()
        let coder = ScheduleSpecCoder()
        let cronExpression = await compiler.compileToCron(spec)
        let nextRunAt = await compiler.nextRunTime(from: spec)

        let kind: ScheduleKind = {
            switch schedule {
            case .oneTime:
                return .oneTime

            case .daily, .weekly, .monthly:
                return .recurring
            }
        }()

        let record = TaskScheduleRecord(
            taskId: taskId,
            scheduleKind: kind.rawValue,
            schedulePayloadJson: coder.encode(spec),
            cronExpression: cronExpression,
            timezone: timezone(from: schedule),
            nextRunAt: nextRunAt,
            isActive: true
        )
        return try await scheduleRepository.create(schedule: record)
    }

    private func buildSpec(from schedule: ScheduleDraft) -> ScheduleSpec {
        switch schedule {
        case .oneTime(let date, _):
            return .oneTime(date: date)

        case .daily(let time, let timezone):
            return .daily(time: components(from: time), timezone: timezone)

        case .weekly(let time, let weekdays, let timezone):
            return .weekly(
                time: components(from: time),
                days: Array(weekdays).sorted { $0.rawValue < $1.rawValue },
                timezone: timezone
            )

        case .monthly(let time, let days, let timezone):
            return .monthly(
                time: components(from: time),
                days: Array(days).sorted(),
                timezone: timezone
            )
        }
    }

    private func components(from date: Date) -> ScheduleSpec.ScheduleTime {
        let values = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ScheduleSpec.ScheduleTime(
            hour: values.hour ?? 9,
            minute: values.minute ?? 0
        )
    }

    private func timezone(from schedule: ScheduleDraft) -> String {
        switch schedule {
        case .oneTime(_, let timezone),
             .daily(_, let timezone),
             .weekly(_, _, let timezone),
             .monthly(_, _, let timezone):
            return timezone
        }
    }
}

public struct ApproveContentUseCase {
    let approvalService: ApprovalService

    public func execute(contentId: String, approvedBy: String = "user") async throws {
        _ = try await approvalService.approve(contentId: contentId, approvedBy: approvedBy)
    }
}

public struct RejectContentUseCase {
    let approvalService: ApprovalService

    public func execute(contentId: String, reason: String?, rejectedBy: String = "user") async throws {
        _ = try await approvalService.reject(contentId: contentId, reason: reason, rejectedBy: rejectedBy)
    }
}

public struct PublishContentUseCase {
    let publicationService: PublicationService
    let settingsService: SettingsService

    public func execute(_ request: PublicationRequest) async throws {
        switch request.platform {
        case .deviantArt:
            _ = try await publicationService.publishToDeviantArt(
                contentId: request.contentId,
                title: request.title,
                category: request.category,
                isMature: request.isMature,
                tags: request.tags
            )

        case .patreon:
            throw AppError.publicationFailed("Patreon post creation is not supported by the public API v2")
        }
    }
}

public struct EditContentUseCase {
    let versioningService: ContentVersioningService

    public func execute(_ request: ContentEditRequest) async throws {
        _ = try await versioningService.editContent(
            contentId: request.contentId,
            newContentJson: request.json,
            changeReason: request.changeReason,
            editedBy: request.editedBy
        )
    }
}

public struct LoadContentEditorUseCase {
    let contentRepository: GeneratedContentRepository
    let versioningService: ContentVersioningService

    public func loadCurrentJSON(contentId: String) async throws -> String {
        guard let content = try await contentRepository.getById(id: contentId) else {
            throw AppError.invalidTaskConfiguration("Content not found: \(contentId)")
        }
        return JSONUtils.format(content.generatedContentJson) ?? content.generatedContentJson
    }

    public func loadHistory(contentId: String) async throws -> [VersionInfo] {
        try await versioningService.getVersionHistory(contentId: contentId)
    }

    public func restore(contentId: String, version: Int, changeReason: String?) async throws {
        _ = try await versioningService.restoreVersion(
            contentId: contentId,
            targetVersion: version,
            changeReason: changeReason
        )
    }
}
