import Foundation

// MARK: - AI Client

public actor AIClient {
    private let baseURL: String
    private let session: URLSession
    private var lastResponseID: String?

    public init(baseURL: String = "http://localhost:1234", session: URLSession? = nil) {
        self.baseURL = baseURL
        self.session = session ?? URLSession.shared
    }

    public func getLastResponseID() -> String? {
        lastResponseID
    }

    /// Send a single chat message using OpenAI Responses API format.
    /// For stateful chats, pass previousResponseID to continue the conversation.
    public func chat(
        input: String,
        instructions: String? = nil,
        model: String,
        temperature: Double? = nil,
        previousResponseID: String? = nil,
        stream: Bool = false
    ) async throws -> ChatResponse {
        var request = ChatRequest(
            model: model,
            input: input,
            stream: stream,
            store: true
        )
        request.instructions = instructions
        request.temperature = temperature
        request.previousResponseID = previousResponseID

        guard let url = URL(string: "\(baseURL)/v1/responses") else {
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

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorUnsupportedURL {
            throw AIClientError.invalidURL
        }

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

    /// Fetch available models from the LLM server.
    public func fetchModels() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/v1/models") else {
            throw AIClientError.invalidURL
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorUnsupportedURL {
            throw AIClientError.invalidURL
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIClientError.invalidResponse
        }

        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return modelsResponse.data.map { $0.id }
    }

    /// Stream a chat response using OpenAI Responses API format.
    /// Tracks responseID internally for stateful chat continuation.
    public func chatStream(
        input: String,
        instructions: String? = nil,
        model: String,
        temperature: Double? = nil,
        previousResponseID: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        var request = ChatRequest(
            model: model,
            input: input,
            stream: true,
            store: true
        )
        request.instructions = instructions
        request.temperature = temperature
        request.previousResponseID = previousResponseID

        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    guard let url = URL(string: "\(self.baseURL)/v1/responses") else {
                        continuation.finish(throwing: AIClientError.invalidURL)
                        return
                    }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, resp) = try await self.session.bytes(for: urlRequest)

                    guard let httpResponse = resp as? HTTPURLResponse else {
                        continuation.finish(throwing: AIClientError.invalidResponse)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: AIClientError.httpError(httpResponse.statusCode))
                        return
                    }

                    print("[AIClient] Stream started, status 200")

                    for try await line in bytes.lines {
                        print("[AIClient] SSE line: \(line.prefix(100))")
                        if line.isEmpty { continue }
                        if line.hasPrefix("event: ") { continue }

                        let dataString = line.hasPrefix("data: ") ? String(line.dropFirst(6)) : line
                        if dataString == "[DONE]" {
                            continuation.finish()
                            return
                        }

                        // Try OpenAI Responses API format first
                        if let data = dataString.data(using: .utf8),
                           let event = try? JSONDecoder().decode(SSEEvent.self, from: data),
                           event.output != nil {
                            let outputCount = event.output?.count ?? 0
                            print("[AIClient] Parsed SSEEvent: id=\(event.id ?? "nil"), output.count=\(outputCount)")
                            if let id = event.id, !id.isEmpty {
                                await self.updateResponseID(id)
                            }
                            for item in event.output ?? [] where item.type == "message" {
                                for content in item.content ?? [] {
                                    if content.type == "output_text",
                                       let text = content.text {
                                        print("[AIClient] Yielding text: \(text.prefix(50))...")
                                        continuation.yield(text)
                                    }
                                }
                            }
                            continue
                        }

                        // Try response.created/completed first (has nested response.id)
                        if let data = dataString.data(using: .utf8),
                           let createdEvent = try? JSONDecoder().decode(ResponseCreatedEvent.self, from: data),
                           createdEvent.response != nil {
                            if let rid = createdEvent.response?.id, !rid.isEmpty {
                                print("[AIClient] Captured response_id from \(createdEvent.type): \(rid)")
                                await self.updateResponseID(rid)
                            }
                            continue
                        }

                        // Fall back to LM Studio native delta format
                        if let data = dataString.data(using: .utf8),
                           let deltaEvent = try? JSONDecoder().decode(LMStudioDeltaEvent.self, from: data) {
                            let deltaPreview = deltaEvent.delta?.prefix(30) ?? "nil"
                            print(
                                "[AIClient] Parsed LMStudioDeltaEvent: type=\(deltaEvent.type), " +
                                "delta=\(deltaPreview)"
                            )
                            if deltaEvent.type == "response.output_text.delta",
                               let delta = deltaEvent.delta, !delta.isEmpty {
                                print("[AIClient] Yielding delta: \(delta.prefix(50))...")
                                continuation.yield(delta)
                            }
                            continue
                        }

                        print("[AIClient] Failed to parse as any format: \(dataString.prefix(100))")
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func updateResponseID(_ id: String) {
        lastResponseID = id
    }
}

// MARK: - Streaming Support

private struct SSEEvent: Codable {
    let id: String?
    let output: [OutputItem]?
}

private struct OutputItem: Codable {
    let type: String
    let content: [ContentItem]?
}

private struct ContentItem: Codable {
    let type: String
    let text: String?
}

private struct LMStudioDeltaEvent: Codable {
    let type: String
    let delta: String?
    let responseID: String?

    enum CodingKeys: String, CodingKey {
        case type
        case delta
        case responseID = "response_id"
    }
}

private struct ResponseCreatedEvent: Codable {
    let type: String
    let response: ResponseInfo?

    struct ResponseInfo: Codable {
        let id: String
    }
}

private struct ModelsResponse: Codable {
    let object: String
    let data: [ModelInfo]
}

private struct ModelInfo: Codable {
    let id: String
    let object: String
}

// MARK: - Errors

public enum AIClientError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case encodingFailed(Error)
    case decodingFailed(Error)

    public static func == (lhs: AIClientError, rhs: AIClientError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL), (.invalidResponse, .invalidResponse):
            return true
        case (.httpError(let a), .httpError(let b)):
            return a == b
        case (.encodingFailed, .encodingFailed), (.decodingFailed, .decodingFailed):
            return true
        default:
            return false
        }
    }

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
