import Foundation

/// Tool for executing ComfyUI workflows programmatically
public struct ComfyUITool: AgentTool {
    public static let toolName = "comfyui"
    public static let toolDescription = "Execute ComfyUI workflows to generate images using Stable Diffusion models"
    
    public static let inputSchema: ToolInputSchema = ToolInputSchema(
        properties: [
            "workflow_api_json": PropertySchema(
                type: "string",
                description: "The ComfyUI workflow API JSON as a string (the prompt format)"
            ),
            "workflow_file_path": PropertySchema(
                type: "string",
                description: "Path to a .json file containing the ComfyUI workflow"
            ),
            "output_prefix": PropertySchema(
                type: "string",
                description: "Prefix for output filenames",
                defaultValue: "comfyui_output"
            ),
            "timeout_seconds": PropertySchema(
                type: "integer",
                description: "Maximum time to wait for workflow completion",
                defaultValue: "300"
            ),
            "poll_interval_seconds": PropertySchema(
                type: "integer",
                description: "How often to check workflow status",
                defaultValue: "2"
            )
        ],
        required: [],
        description: "Execute a ComfyUI workflow. Provide either workflow_api_json or workflow_file_path."
    )
    
    public static let outputSchema: ToolOutputSchema = ToolOutputSchema(
        properties: [
            "success": PropertySchema(type: "boolean"),
            "output_images": PropertySchema(
                type: "array",
                items: PropertySchema(type: "string", description: "Path to generated image files")
            ),
            "prompt_id": PropertySchema(type: "string", description: "ComfyUI prompt ID"),
            "execution_time_seconds": PropertySchema(type: "number"),
            "node_outputs": PropertySchema(type: "object", description: "Output from each node")
        ],
        description: "Result of ComfyUI workflow execution"
    )
    
    private let comfyUIConfig: ComfyUIConfiguration
    
    public init() {
        self.comfyUIConfig = .default
    }
    
    public init(config: ComfyUIConfiguration) {
        self.comfyUIConfig = config
    }
    
    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        // Parse input
        guard let inputData = input.data(using: .utf8),
              let parameters = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
            throw ToolError.invalidInput("Could not parse input JSON")
        }
        
        // Get workflow JSON
        let workflowJSON: String
        if let workflowJsonString = parameters["workflow_api_json"] as? String {
            workflowJSON = workflowJsonString
        } else if let workflowFilePath = parameters["workflow_file_path"] as? String {
            let fileURL = URL(fileURLWithPath: workflowFilePath)
            guard let fileData = try? Data(contentsOf: fileURL),
                  let fileContent = String(data: fileData, encoding: .utf8) else {
                throw ToolError.fileError(NSError(domain: "ComfyUITool", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not read workflow file at \(workflowFilePath)"
                ]))
            }
            workflowJSON = fileContent
        } else {
            throw ToolError.missingRequiredParameter("Either 'workflow_api_json' or 'workflow_file_path' must be provided")
        }
        
        // Get optional parameters
        let outputPrefix = parameters["output_prefix"] as? String ?? "comfyui_output"
        let timeoutSeconds = parameters["timeout_seconds"] as? Int ?? 300
        let pollInterval = parameters["poll_interval_seconds"] as? Int ?? 2
        
        // Report starting
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .starting,
            message: "Starting ComfyUI workflow execution"
        ))
        
        // Execute workflow
        let result = try await executeWorkflow(
            workflowJSON: workflowJSON,
            outputPrefix: outputPrefix,
            timeoutSeconds: timeoutSeconds,
            pollIntervalSeconds: pollInterval,
            context: context
        )
        
        // Return result as JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let resultData = try encoder.encode(result)
        return String(data: resultData, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - Private Methods
    
    private func executeWorkflow(
        workflowJSON: String,
        outputPrefix: String,
        timeoutSeconds: Int,
        pollIntervalSeconds: Int,
        context: ToolExecutionContext
    ) async throws -> ComfyUIResult {
        let startTime = Date()
        let httpClient = try await context.serviceProvider.getHTTPClient()
        
        // 1. Queue the prompt
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .running,
            message: "Queueing workflow in ComfyUI"
        ))
        
        let promptUrl = "\(comfyUIConfig.baseURL)/prompt"
        guard let workflowData = workflowJSON.data(using: .utf8),
              let workflow = try JSONSerialization.jsonObject(with: workflowData) as? [String: Any] else {
            throw ToolError.invalidInput("Invalid workflow JSON")
        }
        let promptBody: [String: Any] = ["prompt": workflow]
        let bodyData = try JSONSerialization.data(withJSONObject: promptBody)
        
        let (responseData, statusCode) = try await httpClient.post(
            url: promptUrl,
            body: bodyData,
            headers: ["Content-Type": "application/json"]
        )
        
        guard statusCode == 200 else {
            let errorStr = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw ToolError.executionFailed("Failed to queue prompt: HTTP \(statusCode) - \(errorStr)")
        }
        
        guard let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let promptId = response["prompt_id"] as? String else {
            throw ToolError.executionFailed("Invalid response from ComfyUI: could not extract prompt_id")
        }
        
        // 2. Poll for completion
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .running,
            message: "Waiting for workflow completion (prompt_id: \(promptId))"
        ))
        
        let historyUrl = "\(comfyUIConfig.baseURL)/history/\(promptId)"
        var completed = false
        var history: [String: Any]?
        
        let timeoutDate = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        
        while !completed && Date() < timeoutDate {
            try await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
            
            let (historyData, historyStatus) = try await httpClient.get(
                url: historyUrl,
                headers: [:]
            )
            
            if historyStatus == 200,
               let historyResponse = try? JSONSerialization.jsonObject(with: historyData) as? [String: Any] {
                history = historyResponse[promptId] as? [String: Any]
                
                // Check if outputs exist
                if history != nil {
                    completed = true
                }
            }
            
            // Report progress
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(0.9, elapsed / Double(timeoutSeconds) * 0.9)
            try? await context.statusReporter.reportProgress(
                fractionCompleted: progress,
                message: "Generating... (\(Int(elapsed))s elapsed)"
            )
        }
        
        guard completed, let finalHistory = history else {
            throw ToolError.timeout
        }
        
        // 3. Download outputs
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .running,
            message: "Downloading generated images"
        ))
        
        var outputImages: [String] = []
        let outputs = finalHistory["outputs"] as? [String: [String: Any]] ?? [:]
        
        for (nodeId, nodeOutput) in outputs {
            if let images = nodeOutput["images"] as? [[String: Any]] {
                for (index, imageInfo) in images.enumerated() {
                    let filename = imageInfo["filename"] as? String ?? "unknown.png"
                    let subfolder = imageInfo["subfolder"] as? String ?? ""
                    let folderType = imageInfo["type"] as? String ?? "output"
                    
                    // Download image
                    let viewUrl = "\(comfyUIConfig.baseURL)/view?filename=\(filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filename)&subfolder=\(subfolder)&type=\(folderType)"
                    
                    let outputFilename = "\(outputPrefix)_\(nodeId)_\(index).png"
                    let outputPath = context.workingDirectory.appendingPathComponent(outputFilename)
                    
                    try await httpClient.download(url: viewUrl, to: outputPath)
                    outputImages.append(outputPath.path)
                    
                    // Report intermediate result
                    try? await context.statusReporter.reportIntermediateResult(IntermediateResult(
                        type: "image",
                        filePath: outputPath.path,
                        metadata: ["node_id": nodeId, "filename": filename]
                    ))
                }
            }
        }
        
        // 4. Build result
        let executionTime = Date().timeIntervalSince(startTime)
        
        return ComfyUIResult(
            success: true,
            outputImages: outputImages,
            promptId: promptId,
            executionTimeSeconds: executionTime,
            nodeOutputs: outputs
        )
    }
}

// MARK: - Supporting Types

public struct ComfyUIConfiguration: Sendable {
    public let baseURL: String
    
    public static let `default` = ComfyUIConfiguration(baseURL: "http://127.0.0.1:8188")
    
    public init(baseURL: String) {
        self.baseURL = baseURL
    }
}

struct ComfyUIResult: Codable {
    let success: Bool
    let outputImages: [String]
    let promptId: String
    let executionTimeSeconds: TimeInterval
    let nodeOutputs: [String: [String: Any]]?
    
    enum CodingKeys: String, CodingKey {
        case success
        case outputImages = "output_images"
        case promptId = "prompt_id"
        case executionTimeSeconds = "execution_time_seconds"
        case nodeOutputs = "node_outputs"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(outputImages, forKey: .outputImages)
        try container.encode(promptId, forKey: .promptId)
        try container.encode(executionTimeSeconds, forKey: .executionTimeSeconds)
        // nodeOutputs is Any, encode as empty for now
        try container.encode([String: String](), forKey: .nodeOutputs)
    }
    
    init(
        success: Bool,
        outputImages: [String],
        promptId: String,
        executionTimeSeconds: TimeInterval,
        nodeOutputs: [String: [String: Any]]?
    ) {
        self.success = success
        self.outputImages = outputImages
        self.promptId = promptId
        self.executionTimeSeconds = executionTimeSeconds
        self.nodeOutputs = nodeOutputs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        outputImages = try container.decode([String].self, forKey: .outputImages)
        promptId = try container.decode(String.self, forKey: .promptId)
        executionTimeSeconds = try container.decode(TimeInterval.self, forKey: .executionTimeSeconds)
        nodeOutputs = nil
    }
}

