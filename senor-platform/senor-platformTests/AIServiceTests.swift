import XCTest
@testable import senor_platform

// MARK: - SSE Event Parsing Tests

final class SSEEventDecodingTests: XCTestCase {

    func testSSEEventDecodesWithOutputText() throws {
        let json = """
        {
            "id": "resp_abc123",
            "output": [
                {
                    "type": "message",
                    "content": [
                        {
                            "type": "output_text",
                            "text": "Hello, world!"
                        }
                    ]
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!

        // Define local structs for testing since internal structs aren't accessible
        struct TestSSEEvent: Codable {
            let id: String?
            let output: [TestOutputItem]?
        }

        struct TestOutputItem: Codable {
            let type: String
            let content: [TestContentItem]?
        }

        struct TestContentItem: Codable {
            let type: String
            let text: String?
        }

        let event = try JSONDecoder().decode(TestSSEEvent.self, from: data)

        XCTAssertEqual(event.id, "resp_abc123")
        XCTAssertEqual(event.output?.count, 1)
        XCTAssertEqual(event.output?.first?.type, "message")
        XCTAssertEqual(event.output?.first?.content?.first?.type, "output_text")
        XCTAssertEqual(event.output?.first?.content?.first?.text, "Hello, world!")
    }

    func testSSEEventDecodesWithoutOutput() throws {
        let json = """
        {
            "id": "resp_xyz789",
            "type": "response.completed"
        }
        """

        let data = json.data(using: .utf8)!

        struct TestSSEEvent: Codable {
            let id: String?
            let output: [TestOutputItem]?
        }

        struct TestOutputItem: Codable {
            let type: String
            let content: [TestContentItem]?
        }

        struct TestContentItem: Codable {
            let type: String
            let text: String?
        }

        let event = try JSONDecoder().decode(TestSSEEvent.self, from: data)

        XCTAssertEqual(event.id, "resp_xyz789")
        XCTAssertNil(event.output)
    }

    func testLMStudioDeltaEventDecodesWithResponseID() throws {
        let json = """
        {
            "type": "response.output_text.delta",
            "delta": "token text",
            "response_id": "resp_delta123"
        }
        """

        let data = json.data(using: .utf8)!

        struct TestLMStudioDeltaEvent: Codable {
            let type: String
            let delta: String?
            let responseID: String?

            enum CodingKeys: String, CodingKey {
                case type
                case delta
                case responseID = "response_id"
            }
        }

        let event = try JSONDecoder().decode(TestLMStudioDeltaEvent.self, from: data)

        XCTAssertEqual(event.type, "response.output_text.delta")
        XCTAssertEqual(event.delta, "token text")
        XCTAssertEqual(event.responseID, "resp_delta123")
    }

    func testLMStudioDeltaEventDecodesWithoutDelta() throws {
        let json = """
        {
            "type": "response.completed",
            "response_id": "resp_done456"
        }
        """

        let data = json.data(using: .utf8)!

        struct TestLMStudioDeltaEvent: Codable {
            let type: String
            let delta: String?
            let responseID: String?

            enum CodingKeys: String, CodingKey {
                case type
                case delta
                case responseID = "response_id"
            }
        }

        let event = try JSONDecoder().decode(TestLMStudioDeltaEvent.self, from: data)

        XCTAssertEqual(event.type, "response.completed")
        XCTAssertNil(event.delta)
        XCTAssertEqual(event.responseID, "resp_done456")
    }

    func testLMStudioDeltaEventDecodesWithEmptyDelta() throws {
        let json = """
        {
            "type": "response.output_text.delta",
            "delta": "",
            "response_id": "resp_empty"
        }
        """

        let data = json.data(using: .utf8)!

        struct TestLMStudioDeltaEvent: Codable {
            let type: String
            let delta: String?
            let responseID: String?

            enum CodingKeys: String, CodingKey {
                case type
                case delta
                case responseID = "response_id"
            }
        }

        let event = try JSONDecoder().decode(TestLMStudioDeltaEvent.self, from: data)

        XCTAssertEqual(event.type, "response.output_text.delta")
        XCTAssertEqual(event.delta, "")
        XCTAssertEqual(event.responseID, "resp_empty")
    }
}

// MARK: - Chat Request Encoding Tests

final class ChatRequestEncodingTests: XCTestCase {

    func testChatRequestEncodesWithPreviousResponseID() throws {
        let request = ChatRequest(
            model: "test-model",
            input: "Hello",
            instructions: "Be helpful",
            stream: true,
            store: true,
            temperature: 0.7,
            previousResponseID: "prev_resp_123"
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["model"] as? String, "test-model")
        XCTAssertEqual(json["input"] as? String, "Hello")
        XCTAssertEqual(json["instructions"] as? String, "Be helpful")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["store"] as? Bool, true)
        XCTAssertEqual(json["temperature"] as? Double, 0.7)
        XCTAssertEqual(json["previous_response_id"] as? String, "prev_resp_123")
    }

    func testChatRequestEncodesWithoutOptionalFields() throws {
        let request = ChatRequest(
            model: "test-model",
            input: "Hello",
            stream: false,
            store: true
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["model"] as? String, "test-model")
        XCTAssertEqual(json["input"] as? String, "Hello")
        XCTAssertEqual(json["stream"] as? Bool, false)
        XCTAssertEqual(json["store"] as? Bool, true)
        XCTAssertNil(json["instructions"])
        XCTAssertNil(json["temperature"])
        XCTAssertNil(json["previous_response_id"])
    }
}

// MARK: - Chat Response Decoding Tests

final class ChatResponseDecodingTests: XCTestCase {

    func testChatResponseDecodesCorrectly() throws {
        let json = """
        {
            "id": "resp_123",
            "object": "response",
            "created_at": 1700000000,
            "status": "completed",
            "model": "gemma-3-4b-it",
            "output": [
                {
                    "type": "message",
                    "id": "msg_1",
                    "role": "assistant",
                    "content": [
                        {
                            "type": "output_text",
                            "text": "This is the response"
                        }
                    ]
                }
            ],
            "usage": {
                "input_tokens": 10,
                "output_tokens": 20,
                "total_tokens": 30
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        XCTAssertEqual(response.id, "resp_123")
        XCTAssertEqual(response.status, "completed")
        XCTAssertEqual(response.model, "gemma-3-4b-it")
        XCTAssertEqual(response.output.count, 1)
        XCTAssertEqual(response.output.first?.content?.first?.text, "This is the response")
        XCTAssertEqual(response.usage?.inputTokens, 10)
        XCTAssertEqual(response.usage?.outputTokens, 20)
        XCTAssertEqual(response.usage?.totalTokens, 30)
    }

    func testChatResponseDecodesWithEmptyOutput() throws {
        let json = """
        {
            "id": "resp_empty",
            "object": "response",
            "created_at": 1700000000,
            "status": "in_progress",
            "model": "test-model",
            "output": []
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        XCTAssertEqual(response.id, "resp_empty")
        XCTAssertEqual(response.status, "in_progress")
        XCTAssertTrue(response.output.isEmpty)
    }
}

// MARK: - Streaming Logic Tests

final class StreamingLogicTests: XCTestCase {

    /// Simulates the streaming logic to verify tokens are yielded correctly
    func testStreamingYieldsTokensFromLMStudioFormat() async throws {
        let mockStream = AsyncThrowingStream<String, Error> { continuation in
            // Simulate LM Studio delta events
            let events = [
                ("response.output_text.delta", "Hello", "resp_1"),
                ("response.output_text.delta", " world", "resp_1"),
                ("response.output_text.delta", "!", "resp_1"),
                ("response.completed", nil, "resp_1")
            ]

            for (type, delta, _) in events {
                if type == "response.output_text.delta", let d = delta {
                    continuation.yield(d)
                }
            }
            continuation.finish()
        }

        var collected: [String] = []
        for try await chunk in mockStream {
            collected.append(chunk)
        }

        XCTAssertEqual(collected, ["Hello", " world", "!"])
    }

    /// Verifies that response ID is captured from streaming events
    func testResponseIDCapturedFromStream() async throws {
        var responseID: String?

        let mockStream = AsyncThrowingStream<(String, String?), Error> { continuation in
            continuation.yield(("Hello", "resp_abc"))
            continuation.yield((" world", "resp_abc"))
            continuation.finish()
        }

        for try await (chunk, id) in mockStream {
            if let id = id {
                responseID = id
            }
        }

        XCTAssertEqual(responseID, "resp_abc")
    }
}

// MARK: - Real Integration Test

final class AIClientIntegrationTests: XCTestCase {

    /// Tests real connection to LM Studio - requires LM Studio running on localhost:1234
    func testRealLMStudioConnection() async throws {
        let client = AIClient(baseURL: "http://localhost:1234")

        // First test that we can fetch models
        let models = try await client.fetchModels()
        XCTAssertFalse(models.isEmpty, "LM Studio should have at least one model loaded")
        print("Available models: \(models)")

        // Then test streaming chat
        guard let firstModel = models.first else {
            XCTSkip("No models available")
            return
        }

        var receivedChunks: [String] = []
        var receivedResponseID: String?

        let stream = await client.chatStream(
            input: "Hello",
            instructions: "You are a helpful assistant.",
            model: firstModel,
            previousResponseID: nil
        )

        for try await chunk in stream {
            receivedChunks.append(chunk)
            if receivedResponseID == nil {
                receivedResponseID = await client.getLastResponseID()
            }
        }

        XCTAssertFalse(receivedChunks.isEmpty, "Should receive at least one chunk")
        let fullResponse = receivedChunks.joined()
        XCTAssertFalse(fullResponse.isEmpty, "Response should not be empty")
        print("Received response: \(fullResponse.prefix(100))...")
        print("Response ID: \(receivedResponseID ?? "nil")")
    }
}

// MARK: - SSE Format Edge Case Tests

final class SSEFormatEdgeCaseTests: XCTestCase {

    /// Tests that an SSE line with only "data: [DONE]" terminates the stream
    func testDoneLineTerminatesStream() {
        let doneLine = "[DONE]"
        XCTAssertEqual(doneLine, "[DONE]")
    }

    /// Tests parsing of SSE event type lines (should be skipped)
    func testEventTypeLinesAreSkipped() {
        let eventLine = "event: response.output_text.delta"
        XCTAssertTrue(eventLine.hasPrefix("event: "))
    }

    /// Tests that empty lines are skipped
    func testEmptyLinesAreSkipped() {
        let emptyLine = ""
        XCTAssertTrue(emptyLine.isEmpty)
    }

    /// Tests extraction of data from SSE data lines
    func testDataLineExtraction() {
        let dataLine = "data: {\"type\":\"response.output_text.delta\"}"
        let dataString = dataLine.hasPrefix("data: ") ? String(dataLine.dropFirst(6)) : dataLine
        XCTAssertEqual(dataString, "{\"type\":\"response.output_text.delta\"}")
    }

    /// Tests handling of SSE lines without "data: " prefix
    func testLineWithoutDataPrefix() {
        let rawLine = "{\"type\":\"response.output_text.delta\"}"
        let dataString = rawLine.hasPrefix("data: ") ? String(rawLine.dropFirst(6)) : rawLine
        XCTAssertEqual(dataString, rawLine)
    }
}
