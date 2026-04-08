import Foundation

/// Protocol that all agent tools must conform to
public protocol AgentTool: Sendable {
    init()
    /// Unique identifier for the tool
    static var toolName: String { get }
    
    /// Human-readable description of what the tool does
    static var toolDescription: String { get }
    
    /// JSON schema for the tool's input parameters
    static var inputSchema: ToolInputSchema { get }
    
    /// JSON schema for the tool's output
    static var outputSchema: ToolOutputSchema { get }
    
    /// Execute the tool with the given input
    /// - Parameters:
    ///   - input: The input parameters as a JSON string
    ///   - context: The execution context providing access to environment and state
    /// - Returns: The result as a JSON string
    /// - Throws: ToolError if execution fails
    func execute(input: String, context: ToolExecutionContext) async throws -> String
}

/// Context provided to tools during execution
public struct ToolExecutionContext: Sendable {
    /// Unique identifier for this tool execution
    public let executionId: String
    
    /// The agent's working directory for temporary files
    public let workingDirectory: URL
    
    /// Environment variables passed from the parent process
    public let environment: [String: String]
    
    /// Access to shared services (configured by the main app)
    public let serviceProvider: ToolServiceProvider
    
    /// Status reporter for incremental updates
    public let statusReporter: ToolStatusReporter
    
    public init(
        executionId: String,
        workingDirectory: URL,
        environment: [String: String],
        serviceProvider: ToolServiceProvider,
        statusReporter: ToolStatusReporter
    ) {
        self.executionId = executionId
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.serviceProvider = serviceProvider
        self.statusReporter = statusReporter
    }
}

/// Provider interface for tools to access shared services
public protocol ToolServiceProvider: Sendable {
    /// Get the HTTP client for making API requests
    func getHTTPClient() async throws -> any ToolHTTPClient
    
    /// Get the file manager for working directory operations
    func getFileManager() -> any ToolFileManager
    
    /// Get configuration value
    func getConfig(key: String) async throws -> String?
}

/// HTTP client interface for tools
public protocol ToolHTTPClient: Sendable {
    func get(url: String, headers: [String: String]) async throws -> (data: Data, statusCode: Int)
    func post(url: String, body: Data, headers: [String: String]) async throws -> (data: Data, statusCode: Int)
    func download(url: String, to destination: URL) async throws
    func upload(url: String, file: URL, headers: [String: String]) async throws -> (data: Data, statusCode: Int)
}

/// File manager interface for tools
public protocol ToolFileManager: Sendable {
    func createDirectory(at url: URL) async throws
    func write(data: Data, to url: URL) async throws
    func read(from url: URL) async throws -> Data
    func exists(at url: URL) async -> Bool
    func delete(at url: URL) async throws
    func listDirectory(at url: URL) async throws -> [URL]
    func createTempFile(prefix: String, suffix: String) async throws -> URL
}

/// Status reporter for incremental tool updates
public protocol ToolStatusReporter: Sendable {
    /// Report a status update during tool execution
    func report(status: ToolExecutionStatus) async throws
    
    /// Report a progress update (0.0 to 1.0)
    func reportProgress(fractionCompleted: Double, message: String?) async throws
    
    /// Report intermediate results (e.g., generated image preview)
    func reportIntermediateResult(_ result: IntermediateResult) async throws
}

/// Execution status for tool reporting
public struct ToolExecutionStatus: Codable, Sendable {
    public let executionId: String
    public let state: State
    public let message: String?
    public let timestamp: Date
    public let metadata: [String: String]?
    
    public enum State: String, Codable, Sendable {
        case starting = "starting"
        case running = "running"
        case waiting = "waiting"  // Waiting for external input/API
        case completed = "completed"
        case failed = "failed"
        case cancelled = "cancelled"
    }
    
    public init(
        executionId: String,
        state: State,
        message: String? = nil,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.executionId = executionId
        self.state = state
        self.message = message
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Intermediate result from tool execution
public struct IntermediateResult: Codable, Sendable {
    public let type: String  // "image", "text", "json", "file"
    public let data: String?  // Base64 encoded data or text
    public let filePath: String?  // Path to temporary file
    public let metadata: [String: String]?
    
    public init(
        type: String,
        data: String? = nil,
        filePath: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.type = type
        self.data = data
        self.filePath = filePath
        self.metadata = metadata
    }
}

/// Input schema definition for tool parameters
public struct ToolInputSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: PropertySchema]
    public let required: [String]
    public let description: String?
    
    public init(
        type: String = "object",
        properties: [String: PropertySchema],
        required: [String] = [],
        description: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.description = description
    }
}

/// Property schema for input parameters
public final class PropertySchema: Codable, Sendable {
    public let type: String
    public let description: String?
    public let enumValues: [String]?
    public let defaultValue: String?
    public let items: PropertySchema?  // For array types
    
    public init(
        type: String,
        description: String? = nil,
        enumValues: [String]? = nil,
        defaultValue: String? = nil,
        items: PropertySchema? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.defaultValue = defaultValue
        self.items = items
    }
    
    enum CodingKeys: String, CodingKey {
        case type, description, items
        case enumValues = "enum"
        case defaultValue = "default"
    }
}

/// Output schema definition for tool results
public struct ToolOutputSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: PropertySchema]?
    public let description: String?
    
    public init(
        type: String = "object",
        properties: [String: PropertySchema]? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.description = description
    }
}

/// Errors that can occur during tool execution
public enum ToolError: Error, LocalizedError {
    case invalidInput(String)
    case executionFailed(String)
    case missingRequiredParameter(String)
    case invalidParameterType(String, expected: String, got: String)
    case networkError(Error)
    case fileError(Error)
    case serviceUnavailable(String)
    case timeout
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let msg):
            return "Invalid input: \(msg)"
        case .executionFailed(let msg):
            return "Execution failed: \(msg)"
        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidParameterType(let param, let expected, let got):
            return "Invalid type for parameter '\(param)': expected \(expected), got \(got)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .fileError(let error):
            return "File error: \(error.localizedDescription)"
        case .serviceUnavailable(let service):
            return "Service unavailable: \(service)"
        case .timeout:
            return "Tool execution timed out"
        case .cancelled:
            return "Tool execution was cancelled"
        }
    }
}

/// Tool registry for discovering and instantiating tools
public actor ToolRegistry {
    private var tools: [String: any AgentTool.Type] = [:]
    
    public init() {}
    
    /// Register a tool type
    public func register(_ toolType: any AgentTool.Type) {
        tools[toolType.toolName] = toolType
    }
    
    /// Get a tool type by name
    public func getTool(named name: String) -> (any AgentTool.Type)? {
        return tools[name]
    }
    
    /// List all registered tool names
    public func listTools() -> [String] {
        return Array(tools.keys)
    }
    
    /// Get all tool schemas for LLM context
    public func getAllToolSchemas() -> [ToolDefinition] {
        return tools.map { name, type in
            ToolDefinition(
                name: name,
                description: type.toolDescription,
                inputSchema: type.inputSchema,
                outputSchema: type.outputSchema
            )
        }
    }
}

/// Tool definition for LLM context
public struct ToolDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: ToolInputSchema
    public let outputSchema: ToolOutputSchema
}
