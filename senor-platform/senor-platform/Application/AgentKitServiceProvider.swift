import Foundation

/// Service provider that bridges AgentKit to the app's dependency container
public struct AppToolServiceProvider: ToolServiceProvider {
    private let httpClientProvider: @Sendable () -> any ToolHTTPClient
    private let fileManagerProvider: @Sendable () -> any ToolFileManager
    private let commandExecutorProvider: @Sendable () -> any CommandExecutor
    private let configResolver: @Sendable (String) async throws -> String?

    nonisolated public init(
        httpClientProvider: (@Sendable () -> any ToolHTTPClient)? = nil,
        fileManagerProvider: (@Sendable () -> any ToolFileManager)? = nil,
        commandExecutorProvider: (@Sendable () -> any CommandExecutor)? = nil,
        configResolver: @escaping @Sendable (String) async throws -> String? = { key in
            ProcessInfo.processInfo.environment[key]
        }
    ) {
        self.httpClientProvider = httpClientProvider ?? { DefaultToolHTTPClient() }
        self.fileManagerProvider = fileManagerProvider ?? { DefaultToolFileManager() }
        self.commandExecutorProvider = commandExecutorProvider ?? { RealCommandExecutor() }
        self.configResolver = configResolver
    }

    public func getHTTPClient() async throws -> any ToolHTTPClient {
        httpClientProvider()
    }

    public func getFileManager() async -> any ToolFileManager {
        fileManagerProvider()
    }

    public func getCommandExecutor() async -> any CommandExecutor {
        commandExecutorProvider()
    }

    public func getConfig(key: String) async throws -> String? {
        try await configResolver(key)
    }

    public func getDeviantArtClient() async throws -> AKDeviantArtClient? {
        await sharedContainer.resolveOptional(DeviantArtServiceProtocol.self) as? AKDeviantArtClient
    }

    public func getPatreonClient() async throws -> AKPatreonClient? {
        await sharedContainer.resolveOptional(PatreonServiceProtocol.self) as? AKPatreonClient
    }
}
