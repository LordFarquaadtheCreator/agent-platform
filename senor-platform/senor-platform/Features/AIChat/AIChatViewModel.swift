import Foundation
import Combine

@MainActor
public final class AIChatViewModel: ObservableObject {
    @Published public private(set) var messages: [ChatMessage] = []
    @Published public private(set) var isGenerating = false
    @Published public private(set) var contextSummary = ""
    @Published public private(set) var errorMessage: String?

    private let aiClient: AIClient
    private let contextExtractor: ContextExtractor
    private let chatHistoryStore: ChatHistoryStore
    private let workspace: WorkspaceModel
    private let router: AppRouter

    private var systemPrompt: String {
        """
        You are an AI assistant helping the user understand and work with the Senor Platform. 
        You have access to the current page's state and can answer questions about it.
        Be concise and helpful. If you don't know something, say so.
        """
    }

    public init(
        aiClient: AIClient,
        contextExtractor: ContextExtractor,
        chatHistoryStore: ChatHistoryStore,
        workspace: WorkspaceModel,
        router: AppRouter
    ) {
        self.aiClient = aiClient
        self.contextExtractor = contextExtractor
        self.chatHistoryStore = chatHistoryStore
        self.workspace = workspace
        self.router = router
    }

    public func loadHistory() async {
        do {
            messages = try await chatHistoryStore.load(for: router.selectedSection)
            updateContextSummary()
        } catch {
            errorMessage = "Failed to load chat history: \(error.localizedDescription)"
        }
    }

    public func sendMessage(text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isGenerating = true
        errorMessage = nil

        do {
            // Build context
            let context = contextExtractor.extractContext(
                for: router.selectedSection,
                workspace: workspace,
                router: router
            )

            // Apply sliding window to history
            let historyMessages = contextExtractor.applySlidingWindow(to: messages)

            // Build full message list
            var fullMessages: [ChatMessage] = [
                ChatMessage(role: .system, content: systemPrompt),
                ChatMessage(role: .system, content: "Current page context:\n\(context)")
            ]
            fullMessages.append(contentsOf: historyMessages)

            // Stream response
            var assistantResponse = ""
            for try await chunk in aiClient.chatStream(messages: fullMessages) {
                assistantResponse += chunk
                // Update last message with streaming content
                if messages.last?.role == .assistant {
                    messages[messages.count - 1] = ChatMessage(role: .assistant, content: assistantResponse)
                } else {
                    messages.append(ChatMessage(role: .assistant, content: assistantResponse))
                }
            }

            // Save history
            try await chatHistoryStore.save(for: router.selectedSection, messages: messages)
            updateContextSummary()

        } catch {
            errorMessage = "Failed to get AI response: \(error.localizedDescription)"
            // Remove user message if failed
            if messages.last?.role == .user {
                messages.removeLast()
            }
        }

        isGenerating = false
    }

    public func clearHistory() async {
        messages.removeAll()
        do {
            try await chatHistoryStore.clear(for: router.selectedSection)
        } catch {
            errorMessage = "Failed to clear history: \(error.localizedDescription)"
        }
    }

    private func updateContextSummary() {
        let context = contextExtractor.extractContext(
            for: router.selectedSection,
            workspace: workspace,
            router: router
        )
        let estimatedTokens = context.count / 4
        contextSummary = "\(router.selectedSection.title) • ~\(estimatedTokens) tokens"
    }
}
