import Foundation

/// Tool for posting content to DeviantArt
public struct DeviantArtPublishTool: AgentTool {
    public static let toolName = "deviantart_publish"
    public static let toolDescription = "Publish images and content to DeviantArt"

    public static let inputSchema: ToolInputSchema = ToolInputSchema(
        properties: [
            "image_path": PropertySchema(
                type: "string",
                description: "Path to the image file to upload"
            ),
            "title": PropertySchema(
                type: "string",
                description: "Title of the deviation"
            ),
            "description": PropertySchema(
                type: "string",
                description: "Description text (supports HTML)",
                defaultValue: ""
            ),
            "tags": PropertySchema(
                type: "array",
                description: "Tags for the deviation (max 30)",
                items: PropertySchema(type: "string")
            ),
            "category": PropertySchema(
                type: "string",
                description: "Category path (e.g., 'digitalart/paintings/other')"
            ),
            "is_mature": PropertySchema(
                type: "boolean",
                description: "Whether the content is mature",
                defaultValue: "false"
            ),
            "allow_comments": PropertySchema(
                type: "boolean",
                description: "Allow comments on the deviation",
                defaultValue: "true"
            ),
            "allow_download": PropertySchema(
                type: "boolean",
                description: "Allow original file download",
                defaultValue: "false"
            )
        ],
        required: ["image_path", "title"],
        description: "Publish an image to DeviantArt"
    )

    public static let outputSchema: ToolOutputSchema = ToolOutputSchema(
        properties: [
            "success": PropertySchema(type: "boolean"),
            "deviation_id": PropertySchema(type: "string"),
            "url": PropertySchema(type: "string"),
            "title": PropertySchema(type: "string")
        ],
        description: "Result of DeviantArt publication"
    )

    public init() {}

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        // Parse input
        guard let inputData = input.data(using: .utf8),
              let params = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
            throw ToolError.invalidInput("Could not parse input JSON")
        }

        // Validate required parameters
        guard let imagePath = params["image_path"] as? String else {
            throw ToolError.missingRequiredParameter("image_path")
        }
        guard let title = params["title"] as? String else {
            throw ToolError.missingRequiredParameter("title")
        }

        // Get optional parameters
        let tags = params["tags"] as? [String] ?? []
        let category = params["category"] as? String
        let isMature = params["is_mature"] as? Bool ?? false
        _ = params["description"] as? String ?? ""
        _ = params["allow_comments"] as? Bool ?? true
        _ = params["allow_download"] as? Bool ?? false

        // Verify image exists
        let imageURL = URL(fileURLWithPath: imagePath)
        let fileManager = await context.serviceProvider.getFileManager()
        guard await fileManager.exists(at: imageURL) else {
            throw ToolError.fileError(NSError(domain: "DeviantArtPublishTool", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Image file not found at \(imagePath)"
            ]))
        }

        // Report starting
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .starting,
            message: "Starting DeviantArt publication"
        ))

        // Get DeviantArt client from service provider
        guard let deviantArtClient = try await getDeviantArtClient(context: context) else {
            throw ToolError.serviceUnavailable("DeviantArt client not configured")
        }

        // Submit to stash
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .running,
            message: "Uploading to DeviantArt stash"
        ))

        let filename = imageURL.lastPathComponent
        let fileData = try Data(contentsOf: imageURL)
        let stashItem: AKStashItem = try await deviantArtClient.stashSubmit(
            filename: filename,
            fileData: fileData,
            title: title,
            tags: tags.isEmpty ? nil : tags
        )

        // Publish from stash
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .running,
            message: "Publishing deviation"
        ))

        let publishResult: AKPublishResult = try await deviantArtClient.stashPublish(
            itemId: stashItem.itemid,
            title: title,
            category: category,
            isMature: isMature
        )

        guard let deviationId = publishResult.deviationid,
              let url = publishResult.url else {
            throw ToolError.executionFailed("Publication succeeded but no deviation ID returned")
        }

        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .completed,
            message: "Published to DeviantArt: \(url)"
        ))

        // Return result
        let result = DeviantArtPublishResult(
            success: true,
            deviationId: deviationId,
            url: url,
            title: title
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let resultData = try encoder.encode(result)
        return String(data: resultData, encoding: .utf8) ?? "{}"
    }

    private func getDeviantArtClient(context: ToolExecutionContext) async throws -> AKDeviantArtClient? {
        try await context.serviceProvider.getDeviantArtClient()
    }
}

struct DeviantArtPublishResult: Codable {
    let success: Bool
    let deviationId: String
    let url: String
    let title: String

    enum CodingKeys: String, CodingKey {
        case success
        case deviationId = "deviation_id"
        case url
        case title
    }
}

