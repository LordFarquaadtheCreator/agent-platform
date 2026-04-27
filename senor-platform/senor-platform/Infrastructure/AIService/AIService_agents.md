# AIService

Local AI integration via LM Studio OpenAI-compatible API.

## Setup

1. Install LM Studio: https://lmstudio.ai/
2. Start LM Studio server
3. Load a model (e.g., Llama 3, Mistral)
4. Start server with default port 1234
5. Configure endpoint in app settings if different from `http://localhost:1234/v1`

## Usage

```swift
let client = AIClient(baseURL: "http://localhost:1234/v1")
let response = try await client.chat(
    messages: [
        ChatMessage(role: .system, content: "You are a helpful assistant."),
        ChatMessage(role: .user, content: "Hello!")
    ],
    model: "model",
    temperature: 0.7
)
```

## Streaming

```swift
for try await chunk in client.chatStream(messages: [...]) {
    print(chunk) // Stream each token
}
```

## Error Handling

- `invalidURL`: Base URL malformed
- `invalidResponse`: Non-HTTP response
- `httpError(code)`: HTTP error code
- `encodingFailed`: Request serialization failed
- `decodingFailed`: Response parsing failed

## Context Window

AI chat feature uses sliding window strategy:
- Keep last 15 messages
- Drop oldest when exceeding token budget
- Budget: 500 system, 4000 context, remaining for history
