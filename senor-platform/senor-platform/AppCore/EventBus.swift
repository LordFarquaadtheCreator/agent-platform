import Foundation
import Combine

/// Type-safe event bus for internal app communication
/// Replaces NotificationCenter anti-pattern with reactive streams
public final class EventBus: @unchecked Sendable {
    public static let shared = EventBus()

    private let refreshSubject = PassthroughSubject<RefreshEvent, Never>()
    private let actionSubject = PassthroughSubject<ActionEvent, Never>()
    private let stateSubject = PassthroughSubject<StateChangeEvent, Never>()

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Publishers

    public var refreshEvents: AnyPublisher<RefreshEvent, Never> {
        refreshSubject.eraseToAnyPublisher()
    }

    public var actionEvents: AnyPublisher<ActionEvent, Never> {
        actionSubject.eraseToAnyPublisher()
    }

    public var stateChangeEvents: AnyPublisher<StateChangeEvent, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - Emit Events

    public func refreshAllData() {
        refreshSubject.send(.all)
    }

    public func refresh(entities: RefreshEntity) {
        refreshSubject.send(.entities(entities))
    }

    public func createAgent(name: String? = nil) {
        actionSubject.send(.createAgent(name: name))
    }

    public func createTask(agentId: String? = nil) {
        actionSubject.send(.createTask(agentId: agentId))
    }

    public func stateChanged(_ change: StateChangeEvent) {
        stateSubject.send(change)
    }

    // MARK: - Subscriptions

    public func onRefresh(
        _ handler: @escaping (RefreshEvent) -> Void
    ) -> AnyCancellable {
        refreshEvents.sink(receiveValue: handler)
    }

    public func onAction(
        _ handler: @escaping (ActionEvent) -> Void
    ) -> AnyCancellable {
        actionEvents.sink(receiveValue: handler)
    }

    public func onStateChange(
        _ handler: @escaping (StateChangeEvent) -> Void
    ) -> AnyCancellable {
        stateChangeEvents.sink(receiveValue: handler)
    }
}

// MARK: - Event Types

public enum RefreshEvent: Sendable {
    case all
    case entities(RefreshEntity)
}

public enum RefreshEntity: Sendable {
    case agents
    case tasks
    case content
    case approvals
    case schedules
    case runs
}

public enum ActionEvent: Sendable {
    case createAgent(name: String?)
    case createTask(agentId: String?)
    case approveContent(id: String)
    case rejectContent(id: String)
    case publishContent(id: String, platform: String)
}

public enum StateChangeEvent: Sendable {
    case loading(Bool)
    case error(AppError)
    case authenticated(platform: String, userId: String)
    case disconnected(platform: String)
}

// MARK: - Migration Helpers

extension Notification.Name {
    /// Deprecated: Use EventBus instead
    public static let refreshAllData = Notification.Name("refreshAllData")
    public static let createAgentRequest = Notification.Name("createAgentRequest")
    public static let createTaskRequest = Notification.Name("createTaskRequest")
}
