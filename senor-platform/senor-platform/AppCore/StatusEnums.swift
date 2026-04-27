import Foundation

/// Status values for approval workflow
public enum ApprovalStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case approved
    case rejected

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }

    public var color: String {
        switch self {
        case .pending: return "yellow"
        case .approved: return "green"
        case .rejected: return "red"
        }
    }

    public var isPending: Bool { self == .pending }
    public var isApproved: Bool { self == .approved }
    public var isRejected: Bool { self == .rejected }
}

/// Status values for task execution
public enum TaskRunStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    public var color: String {
        switch self {
        case .pending: return "gray"
        case .running: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        case .cancelled: return "orange"
        }
    }

    public var isTerminal: Bool {
        self == .completed || self == .failed || self == .cancelled
    }

    public var isActive: Bool {
        self == .running
    }
}

/// Status values for publication targets
public enum PublicationState: String, Codable, CaseIterable, Sendable {
    case pending
    case scheduled
    case publishing
    case published
    case failed

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .scheduled: return "Scheduled"
        case .publishing: return "Publishing"
        case .published: return "Published"
        case .failed: return "Failed"
        }
    }

    public var color: String {
        switch self {
        case .pending: return "gray"
        case .scheduled: return "blue"
        case .publishing: return "yellow"
        case .published: return "green"
        case .failed: return "red"
        }
    }
}

/// Schedule kind values
public enum ScheduleKind: String, Codable, CaseIterable, Sendable {
    case oneTime = "one_time"
    case recurring

    public var displayName: String {
        switch self {
        case .oneTime: return "One-time"
        case .recurring: return "Recurring"
        }
    }
}

/// Trigger source values
public enum TriggerSource: String, Codable, CaseIterable, Sendable {
    case manual
    case scheduled
    case api
    case retry

    public var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .scheduled: return "Scheduled"
        case .api: return "API"
        case .retry: return "Retry"
        }
    }
}
