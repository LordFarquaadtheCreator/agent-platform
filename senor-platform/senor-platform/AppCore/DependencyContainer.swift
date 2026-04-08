import Foundation

/// Protocol for services that need lifecycle management
public protocol LifecycleAware: Sendable {
    func startup() async throws
    func shutdown() async throws
}

/// Error thrown by DependencyContainer
public enum DependencyContainerError: Error, Sendable {
    case serviceNotRegistered(String)
    case serviceTypeMismatch(String)
}

/// Dependency container implementing service locator pattern with constructor injection support
@MainActor
public final class DependencyContainer: Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var services: [String: AnySendableBox] = [:]
    private nonisolated(unsafe) var lifecycleServices: [String: LifecycleAware] = [:]

    public init() {}

    /// Register a service instance
    public func register<T: Sendable>(_ type: T.Type, instance: T) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(reflecting: type)
        services[key] = AnySendableBox(instance)
    }

    /// Register a factory that creates the service on first resolve
    public func register<T: Sendable>(_ type: T.Type, factory: @Sendable @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(reflecting: type)
        services[key] = AnySendableBox(LazyService(factory: factory))
    }

    /// Register a lifecycle-aware service
    public func register<T: LifecycleAware & Sendable>(_ type: T.Type, instance: T) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(reflecting: type)
        services[key] = AnySendableBox(instance)
        lifecycleServices[key] = instance
    }

    /// Resolve a registered service
    public func resolve<T: Sendable>(_ type: T.Type) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        let key = String(reflecting: type)

        guard let box = services[key] else {
            throw DependencyContainerError.serviceNotRegistered(key)
        }

        // Check if it's a lazy service
        if let lazy = box.value as? LazyService<T> {
            let instance = lazy.factory()
            services[key] = AnySendableBox(instance)
            return instance
        }

        guard let service = box.value as? T else {
            throw DependencyContainerError.serviceTypeMismatch(key)
        }

        return service
    }

    /// Resolve an optional service (returns nil if not registered)
    public func resolveOptional<T: Sendable>(_ type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        let key = String(reflecting: type)

        guard let box = services[key] else {
            return nil
        }

        if let lazy = box.value as? LazyService<T> {
            let instance = lazy.factory()
            services[key] = AnySendableBox(instance)
            return instance
        }

        return box.value as? T
    }

    /// Resolve a service or crash if not registered (for use in initializers)
    public func resolveOrCrash<T: Sendable>(_ type: T.Type) -> T {
        do {
            return try resolve(type)
        } catch {
            fatalError("Failed to resolve dependency \(type): \(error)")
        }
    }

    /// Start all lifecycle-aware services
    public func startupAll() async throws {
        for (_, service) in lifecycleServices {
            try await service.startup()
        }
    }

    /// Shutdown all lifecycle-aware services
    public func shutdownAll() async throws {
        for (_, service) in lifecycleServices {
            try await service.shutdown()
        }
    }
}

/// Box to store any Sendable type
private struct AnySendableBox: @unchecked Sendable {
    let value: Any

    init<T: Sendable>(_ value: T) {
        self.value = value
    }
}

/// Wrapper for lazy service initialization
private struct LazyService<T: Sendable>: Sendable {
    let factory: @Sendable () -> T
}

/// Global shared container (for convenience, but prefer injection)
@MainActor
private final class SharedContainer {
    static let instance = DependencyContainer()
}

@MainActor
public var sharedContainer: DependencyContainer {
    SharedContainer.instance
}
