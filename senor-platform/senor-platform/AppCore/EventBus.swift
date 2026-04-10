import Foundation
import Combine

/// Type-safe event bus for internal app communication
/// Replaces NotificationCenter anti-pattern with reactive streams
public final actor EventBus: Sendable {
    public static let shared = EventBus()

    private let refreshSubject = PassthroughSubject<RefreshEvent, Never>()
    private let actionSubject = PassthroughSubject<ActionEvent, Never>()
    private let stateSubject = PassthroughSubject<StateChangeEvent, Never>()

    // Use a separate actor-isolated storage for cancellables
    private final class SubscriptionStorage: @unchecked Sendable {
        private var cancellables = Set<AnyCancellable>()
        private let lock = NSLock()

        func insert(_ cancellable: AnyCancellable) {
            lock.lock()
            defer { lock.unlock() }
            cancellables.insert(cancellable)
        }

        func remove(_ cancellable: AnyCancellable) {
            lock.lock()
            defer { lock.unlock() }
            cancellables.remove(cancellable)
        }
    }
    private let storage = SubscriptionStorage()

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
        _ handler: @escaping @Sendable (RefreshEvent) -> Void
    ) -> AnyCancellable {
        let cancellable = refreshEvents.sink(receiveValue: handler)
        storage.insert(cancellable)
        return cancellable
    }

    public func onAction(
        _ handler: @escaping @Sendable (ActionEvent) -> Void
    ) -> AnyCancellable {
        let cancellable = actionEvents.sink(receiveValue: handler)
        storage.insert(cancellable)
        return cancellable
    }

    public func onStateChange(
        _ handler: @escaping @Sendable (StateChangeEvent) -> Void
    ) -> AnyCancellable {
        let cancellable = stateChangeEvents.sink(receiveValue: handler)
        storage.insert(cancellable)
        return cancellable
    }
    
    /// Clean up a specific subscription
    public func removeSubscription(_ cancellable: AnyCancellable) {
        storage.remove(cancellable)
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
