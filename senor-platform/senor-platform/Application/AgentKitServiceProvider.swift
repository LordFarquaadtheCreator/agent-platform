import Foundation

/// Service provider that bridges AgentKit to the app's dependency container
public struct AppToolServiceProvider: ToolServiceProvider {
    private let httpClientProvider: @Sendable () -> any ToolHTTPClient
    private let fileManagerProvider: @Sendable () -> any ToolFileManager
    private let commandExecutorProvider: @Sendable () -> any CommandExecutor
    private let configResolver: @Sendable (String) async throws -> String?
    private let deviantArtClientProvider: @Sendable () async throws -> AKDeviantArtClient?
    private let patreonClientProvider: @Sendable () async throws -> AKPatreonClient?

    nonisolated public init(
        httpClientProvider: (@Sendable () -> any ToolHTTPClient)? = nil,
        fileManagerProvider: (@Sendable () -> any ToolFileManager)? = nil,
        commandExecutorProvider: (@Sendable () -> any CommandExecutor)? = nil,
        configResolver: @escaping @Sendable (String) async throws -> String? = { key in
            ProcessInfo.processInfo.environment[key]
        },
        deviantArtClientProvider: @escaping @Sendable () async throws -> AKDeviantArtClient? = {
            nil
        },
        patreonClientProvider: @escaping @Sendable () async throws -> AKPatreonClient? = {
            nil
        }
    ) {
        self.httpClientProvider = httpClientProvider ?? { DefaultToolHTTPClient() }
        self.fileManagerProvider = fileManagerProvider ?? { DefaultToolFileManager() }
        self.commandExecutorProvider = commandExecutorProvider ?? { RealCommandExecutor() }
        self.configResolver = configResolver
        self.deviantArtClientProvider = deviantArtClientProvider
        self.patreonClientProvider = patreonClientProvider
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
        try await deviantArtClientProvider()
    }

    public func getPatreonClient() async throws -> AKPatreonClient? {
        try await patreonClientProvider()
    }
}
