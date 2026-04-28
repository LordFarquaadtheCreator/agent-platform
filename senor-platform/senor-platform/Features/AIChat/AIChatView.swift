import SwiftUI
import Combine

struct AIChatView: View {
    @ObservedObject private var viewModel: AIChatViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var editingQueueId: UUID?
    @State private var editingQueueText: String = ""

    init(viewModel: AIChatViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList

            // Error message display
            if let error = viewModel.errorMessage {
                HStack {
                    AppText(error, style: .caption)
                        .foregroundStyle(AppTheme.ColorToken.statusError)
                    Spacer()
                }
                .padding(AppTheme.Spacing.small)
                .background(AppTheme.ColorToken.statusError.opacity(0.1))
                .accessibilityIdentifier("errorMessage")
            }

            Divider()

            // Queue area appears between messages and input
            if !viewModel.queuedMessages.isEmpty {
                queueArea
                    .padding(.horizontal, AppTheme.Spacing.small)
                    .padding(.top, AppTheme.Spacing.small)
            }

            VStack(spacing: AppTheme.Spacing.small) {
                inputArea
                modelSelector
            }
            .padding(AppTheme.Spacing.small)
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task {
            await viewModel.fetchAvailableModels()
            await viewModel.loadHistory()
        }
        .sheet(isPresented: $viewModel.showHistory) {
            historyViewer
        }
    }

    private var modelSelector: some View {
        HStack {
            AppText("Model:", style: .caption, color: AppTheme.ColorToken.textSecondary)

            Picker("", selection: $viewModel.selectedModel) {
                ForEach(viewModel.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(.menu)
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.ColorToken.textSecondary)

            Spacer()

            Menu {
                Button("View History", systemImage: "clock") {
                    Task {
                        await viewModel.loadHistorySessions()
                        viewModel.showHistory = true
                    }
                }
                .accessibilityIdentifier("viewHistoryButton")

                Button("Clear History", systemImage: "trash") {
                    Task { await viewModel.clearHistory() }
                }
                .accessibilityIdentifier("clearHistoryButton")
            } label: {
                Label("Options", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("optionsButton")
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.ColorToken.textSecondary)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { index, message in
                        messageBubble(message)
                            .id(index)
                    }
                }
                .padding(AppTheme.Spacing.small)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: AppTheme.Spacing.xSmall) {
                HStack {
                    AppText(message.role == .user ? "You" : "AI", style: .caption)
                        .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    Spacer()
                }

                AppSurface(style: .flat) {
                    markdownText(message.content)
                        .foregroundStyle(AppTheme.ColorToken.textPrimary)
                        .textSelection(.enabled)
                }
            }
            .frame(
                maxWidth: .infinity * 0.8,
                alignment: message.role == .user ? .trailing : .leading
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(message.role == .user ? "User" : "AI"): \(message.content)")
            .accessibilityIdentifier(message.role == .user ? "userMessage" : "assistantMessage")

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private var inputArea: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.small) {
            AppInputField(
                title: "Input",
                placeholder: "Ask about ...",
                text: $inputText
            )
            .focused($isInputFocused)
            .onSubmit {
                Task { await sendMessage() }
            }
            .accessibilityIdentifier("chatInputField")

            Button {
                Task { await sendMessage() }
            } label: {
                if viewModel.isGenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(AppTheme.Typography.title3)
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sendMessageButton")
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func sendMessage() async {
        let text = inputText
        inputText = ""
        await viewModel.sendMessage(text: text)
    }

    private var queueArea: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack {
                AppText(
                    "\(viewModel.queuedMessages.count) queued",
                    style: .caption,
                    color: AppTheme.ColorToken.textSecondary
                )
                Spacer()
                Button("Clear All") {
                    viewModel.clearQueue()
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.ColorToken.statusError)
                .buttonStyle(.plain)
                .disabled(viewModel.queuedMessages.isEmpty)
            }

            VStack(spacing: AppTheme.Spacing.xSmall) {
                ForEach(viewModel.queuedMessages) { item in
                    queueItemRow(item)
                }
            }
        }
        .padding(AppTheme.Spacing.small)
        .background(AppTheme.ColorToken.accent.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .stroke(AppTheme.ColorToken.accent.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(AppTheme.CornerRadius.small)
    }

    private func queueItemRow(_ item: WorkspaceModel.QueuedMessage) -> some View {
        HStack(spacing: AppTheme.Spacing.small) {
            if editingQueueId == item.id {
                // swiftlint:disable:next unlabeled_input_field
                TextField("Edit message", text: $editingQueueText)
                    .font(AppTheme.Typography.body)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        viewModel.updateQueuedMessage(id: item.id, text: editingQueueText)
                        editingQueueId = nil
                    }
            } else {
                Text(item.text)
                    .font(AppTheme.Typography.body)
                    .lineLimit(2)
                    .foregroundStyle(AppTheme.ColorToken.textPrimary)
            }

            Spacer()

            if editingQueueId == item.id {
                Button {
                    viewModel.updateQueuedMessage(id: item.id, text: editingQueueText)
                    editingQueueId = nil
                } label: {
                    Image(systemName: "checkmark")
                        .font(AppTheme.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.ColorToken.statusSuccess)

                Button {
                    editingQueueId = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTheme.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.ColorToken.textSecondary)
            } else {
                Button {
                    editingQueueId = item.id
                    editingQueueText = item.text
                } label: {
                    Image(systemName: "pencil")
                        .font(AppTheme.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.ColorToken.textSecondary)

                Button {
                    viewModel.removeQueuedMessage(id: item.id)
                } label: {
                    Image(systemName: "trash")
                        .font(AppTheme.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.ColorToken.statusError)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xSmall)
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .background(AppTheme.ColorToken.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.small)
    }

    private var historyViewer: some View {
        NavigationView {
            List {
                ForEach(viewModel.historySessions) { session in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        AppText(session.section, style: .headline)
                        AppText(
                            "\(session.messages.count) messages",
                            style: .caption,
                            color: AppTheme.ColorToken.textSecondary
                        )
                        AppText(
                            session.updatedAt.formatted(.relative(presentation: .named)),
                            style: .caption,
                            color: AppTheme.ColorToken.textSecondary
                        )
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await viewModel.loadSession(session) }
                    }
                }
            }
            .navigationTitle("Chat History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.showHistory = false
                    }
                }
            }
        }
    }

    private func markdownText(_ text: String) -> Text {
        if let attributedString = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return Text(attributedString)
        }
        return Text(text)
    }
}

// MARK: - Preview

@MainActor
private class PreviewAIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .user, content: "How do I publish to Patreon?"),
        ChatMessage(
            role: .assistant,
            content: """
                To publish to Patreon, navigate to the Patreon section, click 'New Post',
                fill in the title and content, select your tiers, and click Publish.
                """
        )
    ]
    @Published var isGenerating = false
    @Published var contextSummary = "Patreon • ~150 tokens"
    @Published var errorMessage: String?
    @Published var selectedModel = "model"
    @Published var showHistory = false
    var historySessions: [ChatSession] = []
    var queuedMessages: [WorkspaceModel.QueuedMessage] = []

    func loadHistory() async {}
    func sendMessage(text: String) async {
        isGenerating = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        messages.append(ChatMessage(role: .assistant, content: "This is a preview response."))
        isGenerating = false
    }
    func clearHistory() async { messages.removeAll() }
    func loadHistorySessions() async {}
    func loadSession(_ session: ChatSession) async {}
    func removeQueuedMessage(id: UUID) {}
    func updateQueuedMessage(id: UUID, text: String) {}
    func clearQueue() {}
}
