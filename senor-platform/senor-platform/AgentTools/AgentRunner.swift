import Foundation

/// Main entry point for agent processes
/// Usage: SenorAgent --task-id <id> --system-prompt <prompt> --task-prompt <prompt> --status-file <path> --tools <tool1,tool2,...>
public final class AgentRunner {
    private let arguments: AgentArguments
    private let toolRegistry: ToolRegistry
    private let statusReporter: FileStatusReporter
    private let logger = AppLogger.general
    
    public init(commandLineArguments: [String]) throws {
        self.arguments = try AgentArguments.parse(commandLineArguments)
        self.toolRegistry = ToolRegistry()
        self.statusReporter = FileStatusReporter(statusFilePath: arguments.statusFilePath)
    }
    
    /// Main execution method
    public func run() async throws {
        do {
            // Report starting
            try await statusReporter.report(status: AgentStatus(
                state: .starting,
                message: "Agent starting",
                timestamp: Date(),
                progress: 0.0
            ))
            
            // Setup working directory
            let workingDirectory = try createWorkingDirectory()
            
            // Initialize tools
            try await registerTools()
            
            // Report ready
            try await statusReporter.report(status: AgentStatus(
                state: .ready,
                message: "Agent ready, waiting for LLM instructions",
                timestamp: Date(),
                progress: 0.05
            ))
            
            // Create LLM context
            let llmContext = LLMExecutionContext(
                systemPrompt: arguments.systemPrompt,
                taskPrompt: arguments.taskPrompt,
                availableTools: await toolRegistry.getAllToolSchemas(),
                workingDirectory: workingDirectory,
                statusReporter: statusReporter,
                toolExecutor: { [toolRegistry] toolName, input in
                    guard let toolType = await toolRegistry.getTool(named: toolName) else {
                        throw ToolError.serviceUnavailable("Tool '\(toolName)' not found")
                    }
                    let tool = toolType.init()
                    let context = try await self.createToolContext(workingDirectory: workingDirectory)
                    return try await tool.execute(input: input, context: context)
                }
            )
            
            // Execute LLM-driven workflow
            let result = try await executeLLMWorkflow(context: llmContext)
            
            // Report completion
            try await statusReporter.report(status: AgentStatus(
                state: .completed,
                message: "Agent completed successfully",
                timestamp: Date(),
                progress: 1.0,
                result: result
            ))
            
        } catch {
            // Report failure
            try? await statusReporter.report(status: AgentStatus(
                state: .failed,
                message: "Agent failed: \(error.localizedDescription)",
                timestamp: Date(),
                error: error.localizedDescription
            ))

            logger.error("Agent execution failed: \(error)")
            // Throw error instead of exiting to allow proper cleanup by caller
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func createWorkingDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let agentDir = tempDir.appendingPathComponent("senor_agent_\(arguments.taskId)", isDirectory: true)
        
        try? FileManager.default.removeItem(at: agentDir)
        try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)
        
        // Create subdirectories
        let subdirs = ["inputs", "outputs", "temp", "logs"]
        for subdir in subdirs {
            let subdirURL = agentDir.appendingPathComponent(subdir, isDirectory: true)
            try FileManager.default.createDirectory(at: subdirURL, withIntermediateDirectories: true)
        }
        
        return agentDir
    }
    
    private func registerTools() async throws {
        // Register all available tools
        let availableTools = ["comfyui", "deviantart_publish", "patreon_publish", "image_composer"]

        if !arguments.requestedTools.isEmpty {
            // Only register requested tools that are available
            for toolName in arguments.requestedTools {
                guard availableTools.contains(toolName) else {
                    logger.warning("Unknown tool requested: \(toolName)")
                    continue
                }
                switch toolName {
                case "comfyui":
                    await toolRegistry.register(ComfyUITool.self)
                case "deviantart_publish":
                    await toolRegistry.register(DeviantArtPublishTool.self)
                case "patreon_publish":
                    await toolRegistry.register(PatreonPublishTool.self)
                case "image_composer":
                    await toolRegistry.register(ImageComposerTool.self)
                default:
                    logger.warning("Unknown tool: \(toolName)")
                }
            }
            logger.info("Registered \(arguments.requestedTools.count) requested tools")
        } else {
            // Register all tools if none specifically requested
            await toolRegistry.register(ComfyUITool.self)
            await toolRegistry.register(DeviantArtPublishTool.self)
            await toolRegistry.register(PatreonPublishTool.self)
            await toolRegistry.register(ImageComposerTool.self)
        }
    }
    
    private func createToolContext(workingDirectory: URL) async throws -> ToolExecutionContext {
        let executionId = UUID().uuidString
        let serviceProvider = DefaultToolServiceProvider()
        let statusReporter = DelegatingStatusReporter(fileReporter: statusReporter)
        
        return ToolExecutionContext(
            executionId: executionId,
            workingDirectory: workingDirectory,
            environment: ProcessInfo.processInfo.environment,
            serviceProvider: serviceProvider,
            statusReporter: statusReporter
        )
    }
    
    private func executeLLMWorkflow(context: LLMExecutionContext) async throws -> AgentResult {
        // This is where the LLM interaction happens
        // The LLM decides which tools to call based on the system prompt and task
        
        logger.info("Starting LLM workflow execution")
        
        // For now, implement a simple tool selection mechanism
        // In a real implementation, this would call an LLM API
        
        var toolCalls: [ToolCallRecord] = []
        var finalOutput: [String: Any] = [:]
        
        // Parse the task to determine what tools to use
        let taskIntent = try determineTaskIntent(task: context.taskPrompt, availableTools: context.availableTools)
        
        // Execute tools in sequence
        for (index, toolSelection) in taskIntent.tools.enumerated() {
            let progress = 0.1 + (0.8 * Double(index) / Double(taskIntent.tools.count))
            
            try await context.statusReporter.report(status: AgentStatus(
                state: .running,
                message: "Executing tool: \(toolSelection.name)",
                timestamp: Date(),
                progress: progress,
                currentTool: toolSelection.name
            ))
            
            let startTime = Date()
            let result = try await context.toolExecutor(toolSelection.name, toolSelection.input)
            let executionTime = Date().timeIntervalSince(startTime)
            
            toolCalls.append(ToolCallRecord(
                toolName: toolSelection.name,
                input: toolSelection.input,
                output: result,
                executionTimeSeconds: executionTime,
                timestamp: Date()
            ))
            
            // Store result for potential use by subsequent tools
            finalOutput[toolSelection.outputKey] = result
        }
        
        // Convert finalOutput dictionary to JSON string
        let finalOutputJson: String
        if let jsonData = try? JSONSerialization.data(withJSONObject: finalOutput, options: .sortedKeys),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            finalOutputJson = jsonString
        } else {
            finalOutputJson = "{}"
        }
        
        return AgentResult(
            success: true,
            toolCalls: toolCalls,
            finalOutputJson: finalOutputJson,
            executionLog: [] // Would contain full LLM conversation
        )
    }
    
    private func determineTaskIntent(task: String, availableTools: [ToolDefinition]) throws -> TaskIntent {
        // This is a placeholder implementation
        // In a real implementation, this would call an LLM to analyze the task
        // and determine which tools to use
        
        // Simple keyword matching for now
        var selectedTools: [ToolSelection] = []
        
        if task.lowercased().contains("comfy") || task.lowercased().contains("generate image") {
            selectedTools.append(ToolSelection(
                name: "comfyui",
                input: "{\"workflow_file_path\": \"workflow.json\"}",
                outputKey: "generated_images"
            ))
        }
        
        if task.lowercased().contains("deviantart") || task.lowercased().contains("post") {
            selectedTools.append(ToolSelection(
                name: "deviantart_publish",
                input: "{\"image_path\": \"output.png\", \"title\": \"Generated Art\"}",
                outputKey: "deviantart_result"
            ))
        }
        
        if selectedTools.isEmpty {
            // Default to image composer for composition tasks
            selectedTools.append(ToolSelection(
                name: "image_composer",
                input: "{\"canvas\": {\"width\": 1024, \"height\": 1024}, \"layers\": []}",
                outputKey: "composed_image"
            ))
        }
        
        return TaskIntent(tools: selectedTools)
    }
}

// MARK: - Supporting Types

struct AgentArguments {
    let taskId: String
    let systemPrompt: String
    let taskPrompt: String
    let statusFilePath: String
    let requestedTools: [String]
    
    static func parse(_ args: [String]) throws -> AgentArguments {
        var taskId: String?
        var systemPrompt: String?
        var taskPrompt: String?
        var statusFilePath: String?
        var tools: [String] = []
        
        var index = 0
        while index < args.count {
            switch args[index] {
            case "--task-id":
                index += 1
                taskId = index < args.count ? args[index] : nil
            case "--system-prompt":
                index += 1
                systemPrompt = index < args.count ? args[index] : nil
            case "--task-prompt":
                index += 1
                taskPrompt = index < args.count ? args[index] : nil
            case "--status-file":
                index += 1
                statusFilePath = index < args.count ? args[index] : nil
            case "--tools":
                index += 1
                if index < args.count {
                    tools = args[index].split(separator: ",").map(String.init)
                }
            default:
                break
            }
            index += 1
        }
        
        guard let id = taskId else {
            throw AgentError.missingArgument("--task-id")
        }
        guard let sysPrompt = systemPrompt else {
            throw AgentError.missingArgument("--system-prompt")
        }
        guard let tPrompt = taskPrompt else {
            throw AgentError.missingArgument("--task-prompt")
        }
        guard let statusPath = statusFilePath else {
            throw AgentError.missingArgument("--status-file")
        }
        
        return AgentArguments(
            taskId: id,
            systemPrompt: sysPrompt,
            taskPrompt: tPrompt,
            statusFilePath: statusPath,
            requestedTools: tools
        )
    }
}

enum AgentError: Error {
    case missingArgument(String)
}

struct AgentStatus: Codable {
    let state: State
    let message: String
    let timestamp: Date
    let progress: Double
    let currentTool: String?
    let result: AgentResult?
    let error: String?
    
    enum State: String, Codable {
        case starting = "starting"
        case ready = "ready"
        case running = "running"
        case waiting = "waiting"
        case completed = "completed"
        case failed = "failed"
        case cancelled = "cancelled"
    }
    
    init(
        state: State,
        message: String,
        timestamp: Date,
        progress: Double = 0.0,
        currentTool: String? = nil,
        result: AgentResult? = nil,
        error: String? = nil
    ) {
        self.state = state
        self.message = message
        self.timestamp = timestamp
        self.progress = progress
        self.currentTool = currentTool
        self.result = result
        self.error = error
    }
}

struct AgentResult: Codable {
    let success: Bool
    let toolCalls: [ToolCallRecord]
    let finalOutputJson: String
    let executionLog: [String]
}

struct ToolCallRecord: Codable {
    let toolName: String
    let input: String
    let output: String
    let executionTimeSeconds: TimeInterval
    let timestamp: Date
}

struct TaskIntent {
    let tools: [ToolSelection]
}

struct ToolSelection {
    let name: String
    let input: String
    let outputKey: String
}

struct LLMExecutionContext {
    let systemPrompt: String
    let taskPrompt: String
    let availableTools: [ToolDefinition]
    let workingDirectory: URL
    let statusReporter: FileStatusReporter
    let toolExecutor: (String, String) async throws -> String
}

// MARK: - Status Reporting

actor FileStatusReporter {
    private let statusFilePath: String
    private let encoder: JSONEncoder
    
    init(statusFilePath: String) {
        self.statusFilePath = statusFilePath
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = .prettyPrinted
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    func report(status: AgentStatus) throws {
        let data = try encoder.encode(status)
        try data.write(to: URL(fileURLWithPath: statusFilePath))
    }
}

// MARK: - Service Provider

struct DefaultToolServiceProvider: ToolServiceProvider {
    func getHTTPClient() async throws -> any ToolHTTPClient {
        return DefaultToolHTTPClient()
    }
    
    func getFileManager() -> any ToolFileManager {
        return DefaultToolFileManager()
    }
    
    func getConfig(key: String) async throws -> String? {
        return ProcessInfo.processInfo.environment[key]
    }
}

struct DefaultToolHTTPClient: ToolHTTPClient {
    func get(url: String, headers: [String: String]) async throws -> (data: Data, statusCode: Int) {
        guard let url = URL(string: url) else {
            throw ToolError.invalidInput("Invalid URL: \(url)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, statusCode)
    }
    
    func post(url: String, body: Data, headers: [String: String]) async throws -> (data: Data, statusCode: Int) {
        guard let url = URL(string: url) else {
            throw ToolError.invalidInput("Invalid URL: \(url)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, statusCode)
    }
    
    func download(url: String, to destination: URL) async throws {
        guard let url = URL(string: url) else {
            throw ToolError.invalidInput("Invalid URL: \(url)")
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        try data.write(to: destination)
    }
    
    func upload(url: String, file: URL, headers: [String: String]) async throws -> (data: Data, statusCode: Int) {
        // Simplified implementation - in production, use multipart form data
        let data = try Data(contentsOf: file)
        return try await post(url: url, body: data, headers: headers)
    }
}

struct DefaultToolFileManager: ToolFileManager {
    private let fileManager = FileManager.default
    
    func createDirectory(at url: URL) async throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    func write(data: Data, to url: URL) async throws {
        try data.write(to: url)
    }
    
    func read(from url: URL) async throws -> Data {
        return try Data(contentsOf: url)
    }
    
    func exists(at url: URL) async -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    func delete(at url: URL) async throws {
        try fileManager.removeItem(at: url)
    }
    
    func listDirectory(at url: URL) async throws -> [URL] {
        return try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }
    
    func createTempFile(prefix: String, suffix: String) async throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let filename = "\(prefix)\(UUID().uuidString)\(suffix)"
        return tempDir.appendingPathComponent(filename)
    }
}

struct DelegatingStatusReporter: ToolStatusReporter {
    let fileReporter: FileStatusReporter
    
    func report(status: ToolExecutionStatus) async throws {
        // Also update the agent's status file
        let agentStatus = AgentStatus(
            state: mapState(status.state),
            message: status.message ?? "Tool executing: \(status.executionId)",
            timestamp: status.timestamp,
            progress: 0.5 // Tools don't have progress in this simple implementation
        )
        try fileReporter.report(status: agentStatus)
    }
    
    func reportProgress(fractionCompleted: Double, message: String?) async throws {
        // Progress updates handled by parent
    }
    
    func reportIntermediateResult(_ result: IntermediateResult) async throws {
        // Intermediate results could be written to a separate file
    }
    
    private func mapState(_ toolState: ToolExecutionStatus.State) -> AgentStatus.State {
        switch toolState {
        case .starting: return .starting
        case .running: return .running
        case .waiting: return .waiting
        case .completed: return .completed
        case .failed: return .failed
        case .cancelled: return .cancelled
        @unknown default: return .failed
        }
    }
}

