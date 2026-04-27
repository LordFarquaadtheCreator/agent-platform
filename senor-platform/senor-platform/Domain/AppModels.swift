import Foundation

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case dashboard
    case agents
    case tasks
    case content
    case approvals
    case tools
    case deviantArt
    case patreon
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .agents: return "Agents"
        case .tasks: return "Tasks"
        case .content: return "Content"
        case .approvals: return "Approvals"
        case .tools: return "Tools"
        case .deviantArt: return "DeviantArt"
        case .patreon: return "Patreon"
        case .settings: return "Settings"
        }
    }

    public var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .agents: return "cpu"
        case .tasks: return "list.bullet.rectangle"
        case .content: return "doc.text.image"
        case .approvals: return "checkmark.shield"
        case .tools: return "wrench"
        case .deviantArt: return "paintbrush"
        case .patreon: return "heart.fill"
        case .settings: return "gear"
        }
    }
}

public enum PublicationPlatform: String, CaseIterable, Identifiable, Sendable {
    case deviantArt = "deviantart"
    case patreon = "patreon"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .deviantArt: return "DeviantArt"
        case .patreon: return "Patreon"
        }
    }
}

public enum ContentWorkflowStatus: String, CaseIterable, Identifiable, Sendable {
    case pending
    case approved
    case published
    case rejected

    public var id: String { rawValue }

    public var title: String { rawValue.capitalized }
}

public struct Agent: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let status: AgentRuntimeStatus
    public let nameSource: String
    public let nameSeed: Int
    public let createdAt: Date
    public let updatedAt: Date
    public let taskCount: Int
}

public struct TaskTypeSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
}

public struct TaskSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let agentId: String
    public let taskTypeId: String
    public let name: String
    public let scheduleDescription: String
    public let lastRun: Date?
    public let nextRun: Date?
    public let isEnabled: Bool
    public let createdAt: Date
}

public struct ContentSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let agentId: String
    public let title: String
    public let previewImageURL: URL?
    public let createdAt: Date
    public let updatedAt: Date
    public let status: ContentWorkflowStatus
    public let version: Int
}

public struct ApprovalSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let contentId: String
    public let contentTitle: String
    public let agentName: String
    public let submittedAt: Date
}

public struct DashboardSnapshot: Sendable {
    public let activeAgentCount: Int
    public let pendingApprovalCount: Int
    public let scheduledTaskCount: Int
    public let publishedContentCount: Int
    public let recentContent: [ContentSummary]
}

public struct WorkspaceSnapshot: Sendable {
    public let agents: [Agent]
    public let tasks: [TaskSummary]
    public let content: [ContentSummary]
    public let approvals: [ApprovalSummary]
    public let dashboard: DashboardSnapshot
}

public struct TaskCreationContext: Sendable {
    public let agents: [Agent]
    public let taskTypes: [TaskTypeSummary]
}

public struct AgentDraft: Sendable {
    public let displayName: String
    public let isActive: Bool
    public let description: String
    public let workerScriptPath: String
    public let configJSON: String
}

public struct TaskDraft: Sendable {
    public let agentId: String
    public let taskTypeId: String
    public let taskName: String
    public let metadataJSON: String
    public let schedule: ScheduleDraft?
}

public enum ScheduleDraft: Sendable {
    case oneTime(Date, timezone: String)
    case daily(time: Date, timezone: String)
    case weekly(time: Date, weekdays: Set<ScheduleSpec.Weekday>, timezone: String)
    case monthly(time: Date, days: Set<Int>, timezone: String)
}

public struct PublicationRequest: Sendable {
    public let contentId: String
    public let platform: PublicationPlatform
    public let title: String?
    public let category: String?
    public let isMature: Bool
    public let tags: [String]?
    public let campaignId: String?
    public let isPaid: Bool?
    public let isPublic: Bool?
    public let tiers: [String]?
}

public struct ContentEditRequest: Sendable {
    public let contentId: String
    public let json: String
    public let changeReason: String?
    public let editedBy: String
}
