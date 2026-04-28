import Foundation

// MARK: - Chat Models (OpenAI Responses API Format)

/// A message in the conversation history (for local storage/display)
public struct ChatMessage: Codable, Sendable {
    public let role: MessageRole
    public let content: String

    public init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
}

public enum MessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

/// OpenAI Responses API request format
public struct ChatRequest: Codable, Sendable {
    public let model: String
    public let input: String
    public var instructions: String?
    public let stream: Bool
    public let store: Bool
    public var temperature: Double?
    public var previousResponseID: String?

    public init(
        model: String,
        input: String,
        instructions: String? = nil,
        stream: Bool = false,
        store: Bool = true,
        temperature: Double? = nil,
        previousResponseID: String? = nil
    ) {
        self.model = model
        self.input = input
        self.instructions = instructions
        self.stream = stream
        self.store = store
        self.temperature = temperature
        self.previousResponseID = previousResponseID
    }

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case instructions
        case stream
        case store
        case temperature
        case previousResponseID = "previous_response_id"
    }
}

/// OpenAI Responses API response format
public struct ChatResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let createdAt: Int64
    public let status: String
    public let model: String
    public let output: [OutputItem]
    public let usage: Usage?
    public let previousResponseID: String?

    public struct OutputItem: Codable, Sendable {
        public let type: String
        public let id: String?
        public let role: String?
        public let content: [ContentItem]?
    }

    public struct ContentItem: Codable, Sendable {
        public let type: String
        public let text: String?
    }

    public struct Usage: Codable, Sendable {
        public let inputTokens: Int
        public let outputTokens: Int
        public let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case totalTokens = "total_tokens"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case createdAt = "created_at"
        case status
        case model
        case output
        case usage
        case previousResponseID = "previous_response_id"
    }
}
