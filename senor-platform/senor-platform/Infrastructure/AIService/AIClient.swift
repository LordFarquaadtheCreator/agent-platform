import Foundation

// MARK: - AI Client

public actor AIClient {
    private let baseURL: String
    private let session: URLSession

    public init(baseURL: String = "http://localhost:1234/v1") {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    public func chat(
        messages: [ChatMessage],
        model: String = "model",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse {
        let request = ChatRequest(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIClientError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw AIClientError.encodingFailed(error)
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIClientError.httpError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw AIClientError.decodingFailed(error)
        }
    }

    public func chatStream(
        messages: [ChatMessage],
        model: String = "model",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = ChatRequest(
                        messages: messages,
                        model: model,
                        temperature: temperature,
                        maxTokens: maxTokens
                    )

                    guard let url = URL(string: "\(baseURL)/chat/completions") else {
                        continuation.finish(throwing: AIClientError.invalidURL)
                        return
                    }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await session.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIClientError.invalidResponse)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: AIClientError.httpError(httpResponse.statusCode))
                        return
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let dataString = String(line.dropFirst(6))
                            if dataString == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let data = dataString.data(using: .utf8),
                               let streamResponse = try? JSONDecoder().decode(StreamChunk.self, from: data),
                               let content = streamResponse.choices.first?.delta.content {
                                continuation.yield(content)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Streaming Support

private struct StreamChunk: Codable {
    let choices: [StreamChoice]

    struct StreamChoice: Codable {
        let delta: Delta
    }

    struct Delta: Codable {
        let content: String?
    }
}

// MARK: - Errors

public enum AIClientError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case encodingFailed(Error)
    case decodingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid LM Studio URL"
        case .invalidResponse:
            return "Invalid response from LM Studio"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .encodingFailed(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
