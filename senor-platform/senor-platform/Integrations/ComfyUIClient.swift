import Foundation

// MARK: - Errors

public enum ComfyUIClientError: Error, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case encodingFailed
    case decodingFailed(String)
    case websocketDisconnected
    case serverNotReachable
}

// MARK: - Response Types

public struct ComfyUIPromptResponse: Decodable, Sendable {
    public let promptID: String
    public let number: Int
    public let nodeErrors: [String: ComfyUINodeError]?

    enum CodingKeys: String, CodingKey {
        case promptID = "prompt_id"
        case number
        case nodeErrors = "node_errors"
    }
}

public struct ComfyUINodeError: Decodable, Sendable {
    public let errors: [ComfyUIErrorDetail]
    public let dependentOutputs: [String]?
    public let classType: String

    enum CodingKeys: String, CodingKey {
        case errors
        case dependentOutputs = "dependent_outputs"
        case classType = "class_type"
    }
}

public struct ComfyUIErrorDetail: Decodable, Sendable {
    public let type: String
    public let message: String
    public let details: String?
}

public struct ComfyUIQueueResponse: Decodable, Sendable {
    public let queueRunning: [[String: SendableValue]]
    public let queuePending: [[String: SendableValue]]

    enum CodingKeys: String, CodingKey {
        case queueRunning = "queue_running"
        case queuePending = "queue_pending"
    }
}

public struct ComfyUIHistoryResponse: Decodable, Sendable {
    public let outputs: [String: ComfyUIHistoryEntry]

    enum CodingKeys: String, CodingKey {
        case outputs
    }
}

public struct ComfyUIHistoryEntry: Decodable, Sendable {
    public let prompt: [SendableValue]
    public let outputs: [String: ComfyUINodeOutput]
    public let status: ComfyUIHistoryStatus?

    enum CodingKeys: String, CodingKey {
        case prompt
        case outputs
        case status
    }
}

public struct ComfyUIHistoryStatus: Decodable, Sendable {
    public let statusStr: String
    public let completed: Bool
    public let messages: [[String: SendableValue]]

    enum CodingKeys: String, CodingKey {
        case statusStr = "status_str"
        case completed
        case messages
    }
}

public struct ComfyUINodeOutput: Decodable, Sendable {
    public let images: [ComfyUIImageRef]?
    public let text: [String]?
    public let audio: [ComfyUIFileRef]?
    public let video: [ComfyUIFileRef]?

    enum CodingKeys: String, CodingKey {
        case images
        case text
        case audio
        case video
    }
}

public struct ComfyUIImageRef: Decodable, Sendable {
    public let filename: String
    public let subfolder: String
    public let type: String

    enum CodingKeys: String, CodingKey {
        case filename
        case subfolder
        case type
    }
}

public struct ComfyUIFileRef: Decodable, Sendable {
    public let filename: String
    public let subfolder: String
    public let type: String
    public let format: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case subfolder
        case type
        case format
    }
}

public struct ComfyUIObjectInfoResponse: Decodable, Sendable {
    public let nodes: [String: ComfyUIObjectInfoNode]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.nodes = try container.decode([String: ComfyUIObjectInfoNode].self)
    }
}

public struct ComfyUIObjectInfoNode: Decodable, Sendable {
    public let input: ComfyUIObjectInfoInput
    public let output: [String]
    public let outputIsList: [Bool]
    public let outputName: [String]
    public let name: String
    public let displayName: String
    public let description: String
    public let category: String
    public let outputNode: Bool

    enum CodingKeys: String, CodingKey {
        case input
        case output
        case outputIsList = "output_is_list"
        case outputName = "output_name"
        case name
        case displayName = "display_name"
        case description
        case category
        case outputNode = "output_node"
    }
}

public struct ComfyUIObjectInfoInput: Decodable, Sendable {
    public let required: [String: ComfyUIInputSpec]?
    public let optional: [String: ComfyUIInputSpec]?
    public let hidden: [String: ComfyUIInputSpec]?

    enum CodingKeys: String, CodingKey {
        case required
        case optional
        case hidden
    }
}

public struct ComfyUIInputSpec: Decodable, Sendable {
    public let type: String
    public let options: [String]?
    public let defaultValue: SendableValue?
    public let min: Double?
    public let max: Double?
    public let step: Double?

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        // First element is the type or type+options array
        let first = try container.decode(SendableValue.self)

        if let arr = first.arrayValue {
            self.type = "COMBO"
            self.options = arr.compactMap { $0.stringValue }
            self.defaultValue = nil
            self.min = nil
            self.max = nil
            self.step = nil
        } else if let typeStr = first.stringValue {
            self.type = typeStr
            self.options = nil
            // Try to decode config object as second element
            if !container.isAtEnd {
                let config = try container.decode(ComfyUIInputConfig.self)
                self.defaultValue = config.defaultValue
                self.min = config.min
                self.max = config.max
                self.step = config.step
            } else {
                self.defaultValue = nil
                self.min = nil
                self.max = nil
                self.step = nil
            }
        } else {
            self.type = "UNKNOWN"
            self.options = nil
            self.defaultValue = nil
            self.min = nil
            self.max = nil
            self.step = nil
        }
    }
}

public struct ComfyUIInputConfig: Decodable, Sendable {
    public let defaultValue: SendableValue?
    public let min: Double?
    public let max: Double?
    public let step: Double?

    enum CodingKeys: String, CodingKey {
        case defaultValue = "default"
        case min
        case max
        case step
    }
}

// MARK: - SendableValue

public struct SendableValue: Decodable, Sendable {
    public let rawValue: Any

    public var stringValue: String? { rawValue as? String }
    public var intValue: Int? { rawValue as? Int }
    public var doubleValue: Double? { rawValue as? Double }
    public var boolValue: Bool? { rawValue as? Bool }
    public var arrayValue: [SendableValue]? { rawValue as? [SendableValue] }
    public var dictValue: [String: SendableValue]? { rawValue as? [String: SendableValue] }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            rawValue = string
        } else if let int = try? container.decode(Int.self) {
            rawValue = int
        } else if let double = try? container.decode(Double.self) {
            rawValue = double
        } else if let bool = try? container.decode(Bool.self) {
            rawValue = bool
        } else if let array = try? container.decode([SendableValue].self) {
            rawValue = array
        } else if let dict = try? container.decode([String: SendableValue].self) {
            rawValue = dict
        } else {
            rawValue = ""
        }
    }
}

// MARK: - WebSocket Message

public struct ComfyUIWebSocketMessage: Decodable, Sendable {
    public let type: String
    public let data: ComfyUIWebSocketData

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.data = try container.decode(ComfyUIWebSocketData.self, forKey: .data)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
}

public struct ComfyUIWebSocketData: Decodable, Sendable {
    public let promptID: String?
    public let node: String?
    public let value: Int?
    public let max: Int?
    public let text: String?
    public let sid: String?
    public let execInfo: ComfyUIExecInfo?
    public let output: ComfyUIExecutedOutput?

    enum CodingKeys: String, CodingKey {
        case promptID = "prompt_id"
        case node
        case value
        case max
        case text
        case sid
        case execInfo = "exec_info"
        case output
    }
}

public struct ComfyUIExecutedOutput: Decodable, Sendable {
    public let images: [ComfyUIImageRef]?
    public let text: [String]?
    public let audio: [ComfyUIFileRef]?
    public let video: [ComfyUIFileRef]?

    enum CodingKeys: String, CodingKey {
        case images
        case text
        case audio
        case video
    }
}

public struct ComfyUIExecInfo: Decodable, Sendable {
    public let queueRemaining: Int

    enum CodingKeys: String, CodingKey {
        case queueRemaining = "queue_remaining"
    }
}

// MARK: - Client

public actor ComfyUIClient {
    private var baseURL: String
    private let urlSession: URLSession
    private let logger = AppLogger.api
    private var webSocketTask: URLSessionWebSocketTask?
    private var messageHandler: ((ComfyUIWebSocketMessage) -> Void)?

    public init(baseURL: String = "http://127.0.0.1:8188") {
        self.baseURL = baseURL
        self.urlSession = URLSession(configuration: .default)
    }

    public func updateBaseURL(_ url: String) {
        self.baseURL = url
    }

    // MARK: - Nonisolated Decode Helpers

    nonisolated func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Health Check

    public func isReachable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/system_stats") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (_, response) = try await urlSession.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Queue Prompt

    public func queuePrompt(workflowJSON: [String: Any], clientId: String? = nil) async throws -> ComfyUIPromptResponse {
        guard let url = URL(string: "\(baseURL)/prompt") else {
            throw ComfyUIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["prompt": workflowJSON]
        if let clientId = clientId {
            body["client_id"] = clientId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ComfyUIClientError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ComfyUIClientError.httpError(httpResponse.statusCode, body)
        }
        return try decode(ComfyUIPromptResponse.self, from: data)
    }

    // MARK: - Get Queue

    public func getQueue() async throws -> ComfyUIQueueResponse {
        guard let url = URL(string: "\(baseURL)/queue") else {
            throw ComfyUIClientError.invalidURL
        }
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        return try decode(ComfyUIQueueResponse.self, from: data)
    }

    // MARK: - Interrupt

    public func interrupt() async throws {
        guard let url = URL(string: "\(baseURL)/interrupt") else {
            throw ComfyUIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
    }

    // MARK: - Queue Management

    public func clearQueue() async throws {
        guard let url = URL(string: "\(baseURL)/queue") else {
            throw ComfyUIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["clear": true])
        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
    }

    public func deleteQueueItems(promptIDs: [String]) async throws {
        guard let url = URL(string: "\(baseURL)/queue") else {
            throw ComfyUIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["delete": promptIDs])
        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
    }

    // MARK: - Memory Management

    public func freeMemory(unloadModels: Bool = true, freeMemory: Bool = true) async throws {
        guard let url = URL(string: "\(baseURL)/free") else {
            throw ComfyUIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "unload_models": unloadModels,
            "free_memory": freeMemory
        ])
        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
    }

    // MARK: - Model & Embedding Enumeration

    public func listModelFolders() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/models") else {
            throw ComfyUIClientError.invalidURL
        }
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        return try decode([String].self, from: data)
    }

    public func listModels(in folder: String) async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/models/\(folder)") else {
            throw ComfyUIClientError.invalidURL
        }
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        return try decode([String].self, from: data)
    }

    public func listEmbeddings() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/embeddings") else {
            throw ComfyUIClientError.invalidURL
        }
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        return try decode([String].self, from: data)
    }

    // MARK: - History

    public func getHistory(promptID: String) async throws -> ComfyUIHistoryResponse {
        guard let url = URL(string: "\(baseURL)/history/\(promptID)") else {
            throw ComfyUIClientError.invalidURL
        }
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        return try decode(ComfyUIHistoryResponse.self, from: data)
    }

    public func getAllHistory() async throws -> ComfyUIHistoryResponse {
        guard let url = URL(string: "\(baseURL)/history") else {
            throw ComfyUIClientError.invalidURL
        }
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        return try decode(ComfyUIHistoryResponse.self, from: data)
    }

    public func clearHistory() async throws {
        guard let url = URL(string: "\(baseURL)/history") else {
            throw ComfyUIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["clear": true])
        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
    }

    public func deleteHistory(promptIDs: [String]) async throws {
        guard let url = URL(string: "\(baseURL)/history") else {
            throw ComfyUIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["delete": promptIDs])
        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
    }

    // MARK: - Object Info

    public func getObjectInfo() async throws -> ComfyUIObjectInfoResponse {
        guard let url = URL(string: "\(baseURL)/object_info") else {
            throw ComfyUIClientError.invalidURL
        }
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        return try decode(ComfyUIObjectInfoResponse.self, from: data)
    }

    // MARK: - Download Image

    public func downloadImage(filename: String, subfolder: String, type: String) async throws -> Data {
        guard var components = URLComponents(string: "\(baseURL)/view") else {
            throw ComfyUIClientError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "filename", value: filename),
            URLQueryItem(name: "subfolder", value: subfolder),
            URLQueryItem(name: "type", value: type)
        ]
        guard let url = components.url else {
            throw ComfyUIClientError.invalidURL
        }
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        return data
    }

    // MARK: - Upload Image

    public func uploadImage(data: Data, filename: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/upload/image") else {
            throw ComfyUIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw ComfyUIClientError.decodingFailed("Invalid upload response")
        }
        return json
    }

    // MARK: - Upload Mask

    public func uploadMask(data: Data, filename: String, originalImage: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/upload/mask") else {
            throw ComfyUIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"original_image\"\r\n\r\n".data(using: .utf8)!)
        body.append(originalImage.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ComfyUIClientError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw ComfyUIClientError.decodingFailed("Invalid mask upload response")
        }
        return json
    }

    // MARK: - WebSocket

    public func connectWebSocket(clientId: String? = nil, onMessage: @escaping (ComfyUIWebSocketMessage) -> Void) async throws {
        disconnectWebSocket()

        var wsURL = baseURL.replacingOccurrences(of: "http://", with: "ws://").replacingOccurrences(of: "https://", with: "wss://") + "/ws"
        if let clientId = clientId {
            wsURL += "?clientId=\(clientId)"
        }
        guard let url = URL(string: wsURL) else {
            throw ComfyUIClientError.invalidURL
        }

        let task = urlSession.webSocketTask(with: url)
        self.webSocketTask = task
        self.messageHandler = onMessage
        task.resume()

        // Start receive loop
        Task { await receiveLoop() }
    }

    public func disconnectWebSocket() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        messageHandler = nil
    }

    private func receiveLoop() async {
        while let task = webSocketTask {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let wsMessage = try? self.decode(ComfyUIWebSocketMessage.self, from: data) {
                        messageHandler?(wsMessage)
                    }
                case .data(let data):
                    if let wsMessage = try? self.decode(ComfyUIWebSocketMessage.self, from: data) {
                        messageHandler?(wsMessage)
                    }
                @unknown default:
                    break
                }
            } catch {
                if webSocketTask != nil {
                    // Reconnect after short delay
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
    }
}
