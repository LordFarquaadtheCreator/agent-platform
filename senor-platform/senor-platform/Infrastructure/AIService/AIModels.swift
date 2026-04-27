import Foundation

// MARK: - Chat Models

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

public struct ChatRequest: Codable, Sendable {
    public let messages: [ChatMessage]
    public let model: String
    public let temperature: Double?
    public let maxTokens: Int?

    public init(
        messages: [ChatMessage],
        model: String,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.messages = messages
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
    }

    enum CodingKeys: String, CodingKey {
        case messages
        case model
        case temperature
        case maxTokens = "max_tokens"
    }
}

public struct ChatResponse: Codable, Sendable {
    public let id: String
    public let choices: [Choice]
    public let usage: Usage?

    public struct Choice: Codable, Sendable {
        public let index: Int
        public let message: ChatMessage
        public let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    public struct Usage: Codable, Sendable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
