import Foundation
import Combine

@MainActor
public final class AppRouter: ObservableObject {
    @Published public var selectedSection: AppSection = .dashboard
    @Published public var selectedAgentID: String?
    @Published public var selectedTaskID: String?
    @Published public var selectedContentID: String?
    @Published public var selectedDeviationID: String?
    @Published public var selectedPostID: String?
    @Published public var selectedMemberID: String?
    @Published public var selectedWorkflowID: String?
    @Published public var selectedExecutionID: String?

    public init() {}
}

public enum AppSheet: Identifiable, Equatable {
    case newAgent
    case newTask
    case settings
    case editContent(String)
    case versionHistory(String)

    public var id: String {
        switch self {
        case .newAgent: return "new-agent"
        case .newTask: return "new-task"
        case .settings: return "settings"
        case .editContent(let id): return "edit-\(id)"
        case .versionHistory(let id): return "history-\(id)"
        }
    }
}
