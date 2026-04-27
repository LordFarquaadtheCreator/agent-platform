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
        let stashItem: AKStashItem = try await deviantArtClient.stashSubmit(
            filename: filename,
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
            stashId: stashItem.itemid,
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

/// Tool for posting content to Patreon
public struct PatreonPublishTool: AgentTool {
    public static let toolName = "patreon_publish"
    public static let toolDescription = "Create posts on Patreon"

    public static let inputSchema: ToolInputSchema = ToolInputSchema(
        properties: [
            "title": PropertySchema(
                type: "string",
                description: "Title of the post"
            ),
            "content": PropertySchema(
                type: "string",
                description: "Post content (supports HTML)"
            ),
            "image_paths": PropertySchema(
                type: "array",
                description: "Paths to images to attach to the post",
                items: PropertySchema(type: "string")
            ),
            "tier_ids": PropertySchema(
                type: "array",
                description: "Patreon tier IDs to restrict access to (empty = public)",
                items: PropertySchema(type: "string")
            ),
            "is_paid": PropertySchema(
                type: "boolean",
                description: "Whether this is a paid post",
                defaultValue: "true"
            ),
            "is_public": PropertySchema(
                type: "boolean",
                description: "Whether the post is publicly visible",
                defaultValue: "false"
            ),
            "campaign_id": PropertySchema(
                type: "string",
                description: "Patreon campaign ID (required)"
            )
        ],
        required: ["title", "content", "campaign_id"],
        description: "Create a post on Patreon"
    )

    public static let outputSchema: ToolOutputSchema = ToolOutputSchema(
        properties: [
            "success": PropertySchema(type: "boolean"),
            "post_id": PropertySchema(type: "string"),
            "url": PropertySchema(type: "string"),
            "title": PropertySchema(type: "string")
        ],
        description: "Result of Patreon post creation"
    )

    public init() {}

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        // Parse input
        guard let inputData = input.data(using: .utf8),
              let params = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
            throw ToolError.invalidInput("Could not parse input JSON")
        }

        // Validate required parameters
        guard let title = params["title"] as? String else {
            throw ToolError.missingRequiredParameter("title")
        }
        guard let content = params["content"] as? String else {
            throw ToolError.missingRequiredParameter("content")
        }
        guard let campaignId = params["campaign_id"] as? String else {
            throw ToolError.missingRequiredParameter("campaign_id")
        }

        // Get optional parameters
        _ = params["image_paths"] as? [String] ?? []
        let tierIds = params["tier_ids"] as? [String]
        let isPaid = params["is_paid"] as? Bool ?? true
        let isPublic = params["is_public"] as? Bool ?? false

        // Report starting
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .starting,
            message: "Starting Patreon post creation"
        ))

        // Get Patreon client
        guard let patreonClient = try await getPatreonClient(context: context) else {
            throw ToolError.serviceUnavailable("Patreon client not configured")
        }

        // Create post
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .running,
            message: "Creating Patreon post"
        ))

        let post: AKPost = try await patreonClient.createPost(
            campaignId: campaignId,
            title: title,
            content: content,
            isPaid: isPaid,
            isPublic: isPublic,
            tiers: tierIds
        )

        // Get public URL
        let url = try await patreonClient.getPublicURL(for: post.id)

        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .completed,
            message: "Created Patreon post: \(url)"
        ))

        // Return result
        let result = PatreonPublishResult(
            success: true,
            postId: post.id,
            url: url,
            title: title
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let resultData = try encoder.encode(result)
        return String(data: resultData, encoding: .utf8) ?? "{}"
    }

    private func getPatreonClient(context: ToolExecutionContext) async throws -> AKPatreonClient? {
        try await context.serviceProvider.getPatreonClient()
    }
}

struct PatreonPublishResult: Codable {
    let success: Bool
    let postId: String
    let url: String
    let title: String

    enum CodingKeys: String, CodingKey {
        case success
        case postId = "post_id"
        case url
        case title
    }
}
