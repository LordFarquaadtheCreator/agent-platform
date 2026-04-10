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
public final actor DependencyContainer {
    private var services: [String: AnySendableBox] = [:]
    private var lifecycleServices: [String: LifecycleAware] = [:]

    public init() {}

    /// Register a service instance
    public func register<T: Sendable>(_ type: T.Type, instance: T) {
        let key = String(reflecting: type)
        services[key] = AnySendableBox(instance)
    }

    /// Register a factory that creates the service on first resolve
    public func register<T: Sendable>(_ type: T.Type, factory: @Sendable @escaping () async -> T) {
        let key = String(reflecting: type)
        services[key] = AnySendableBox(LazyService(factory: factory))
    }

    /// Register a lifecycle-aware service
    public func register<T: LifecycleAware & Sendable>(_ type: T.Type, instance: T) {
        let key = String(reflecting: type)
        services[key] = AnySendableBox(instance)
        lifecycleServices[key] = instance
    }

    /// Resolve a registered service (async)
    public func resolve<T: Sendable>(_ type: T.Type) async throws -> T {
        let key = String(reflecting: type)

        guard let box = services[key] else {
            throw DependencyContainerError.serviceNotRegistered(key)
        }

        // Check if it's a lazy service
        if let lazy = box.value as? LazyService<T> {
            let instance = await lazy.factory()
            services[key] = AnySendableBox(instance)
            return instance
        }

        guard let service = box.value as? T else {
            throw DependencyContainerError.serviceTypeMismatch(key)
        }

        return service
    }

    /// Resolve an optional service (returns nil if not registered)
    public func resolveOptional<T: Sendable>(_ type: T.Type) async -> T? {
        let key = String(reflecting: type)

        guard let box = services[key] else {
            return nil
        }

        if let lazy = box.value as? LazyService<T> {
            let instance = await lazy.factory()
            services[key] = AnySendableBox(instance)
            return instance
        }

        return box.value as? T
    }

    /// Resolve a service with fallback value if not registered
    public func resolve<T: Sendable>(_ type: T.Type, default defaultValue: T) async -> T {
        do {
            return try await resolve(type)
        } catch {
            return defaultValue
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
    let factory: @Sendable () async -> T
}

/// Global shared container (for convenience, but prefer injection)
public let sharedContainer = DependencyContainer()

// MARK: - MainActor Resolution Helpers

public extension DependencyContainer {
    /// Async resolve that crashes if service not found (safe for MainActor)
    func resolveOrCrash<T: Sendable>(_ type: T.Type) async -> T {
        do {
            return try await resolve(type)
        } catch {
            fatalError("Failed to resolve service: \(String(reflecting: type)) - \(error)")
        }
    }
    
    /// Async optional resolve (safe for MainActor)
    func resolveSyncOptional<T: Sendable>(_ type: T.Type) async -> T? {
        return await resolveOptional(type)
    }
}
