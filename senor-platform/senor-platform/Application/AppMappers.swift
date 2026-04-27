import Foundation

extension Agent {
    nonisolated init(record: AgentRecord, taskCount: Int) {
        self.id = record.id
        self.displayName = record.displayName
        self.status = record.status
        self.nameSource = record.nameSource
        self.nameSeed = record.nameSeed
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
        self.taskCount = taskCount
    }
}

extension TaskTypeSummary {
    nonisolated init(record: TaskTypeRecord) {
        self.id = record.id
        self.name = record.name
        self.description = record.description
    }
}

extension TaskSummary {
    nonisolated init(record: TaskRecord, schedule: TaskScheduleRecord?, lastRun: TaskRunRecord?) {
        self.id = record.id
        self.agentId = record.agentId
        self.taskTypeId = record.taskTypeId
        self.name = record.taskName
        self.scheduleDescription = TaskSummary.describe(schedule: schedule)
        self.lastRun = lastRun?.completedAt ?? lastRun?.startedAt
        self.nextRun = schedule?.nextRunAt
        self.isEnabled = record.isEnabled
        self.createdAt = record.createdAt
    }

    nonisolated private static func describe(schedule: TaskScheduleRecord?) -> String {
        guard let schedule else { return "No schedule" }
        switch schedule.scheduleKind {
        case ScheduleKind.oneTime.rawValue:
            return "One-time"

        case ScheduleKind.recurring.rawValue:
            return "Recurring"

        default:
            return "Custom"
        }
    }
}

extension ContentSummary {
    nonisolated init(record: GeneratedContentRecord, status: ContentWorkflowStatus) {
        self.id = record.id
        self.agentId = record.agentId
        self.title = record.title
        self.previewImageURL = nil
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
        self.status = status
        self.version = record.currentVersion
    }
}
