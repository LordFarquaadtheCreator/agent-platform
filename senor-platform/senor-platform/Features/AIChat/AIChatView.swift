import SwiftUI
import Combine

struct AIChatView: View {
    @ObservedObject private var viewModel: AIChatViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var editingQueueId: UUID?
    @State private var editingQueueText: String = ""
    @State private var hoveredQueueId: UUID? = nil

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
            .padding(AppTheme.Spacing.medium)
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
            Picker("Model:", selection: $viewModel.selectedModel) {
				Text("Select a Model").tag("Select a Model").id(-1)
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
		.padding(.horizontal, AppTheme.Spacing.small)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { index, message in
                        messageBubble(message)
                            .id(index)
                    }
                    if showLoadingBubble {
                        loadingBubble
                            .id("loading")
                    }
                }
                .padding(AppTheme.Spacing.small)
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToLast(proxy)
            }
            .onChange(of: viewModel.isGenerating) { _ in
                scrollToLast(proxy)
            }
        }
    }

    private var showLoadingBubble: Bool {
        viewModel.isGenerating && viewModel.messages.last?.role != .assistant
    }

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        if viewModel.isGenerating {
            proxy.scrollTo("loading", anchor: .bottom)
        } else if let last = viewModel.messages.indices.last {
            proxy.scrollTo(last, anchor: .bottom)
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: AppTheme.Spacing.xSmall) {
				AppText(message.role == .user ? "You" : "AI", style: .caption)
					.foregroundStyle(AppTheme.ColorToken.textSecondary)
					.padding(.horizontal, AppTheme.Spacing.xSmall)

                AppSurface(
                    style: .flat,
                    backgroundColor: message.role == .user ? AppTheme.ColorToken.accent : nil
                ) {
                    markdownText(message.content)
                        .foregroundStyle(AppTheme.ColorToken.textPrimary)
                        .textSelection(.enabled)
                }
            }
			.padding(.horizontal, AppTheme.Spacing.xSmall)
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

    private var loadingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                AppText("AI", style: .caption)
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)

                AppSurface(style: .flat) {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(AppTheme.ColorToken.textSecondary)
                                .frame(width: 6, height: 6)
                                .offset(y: sin(Double(index) * 2 + Date().timeIntervalSince1970 * 5) * 2)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.small)
                    .padding(.vertical, AppTheme.Spacing.xSmall)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xSmall)
            .frame(maxWidth: .infinity * 0.8, alignment: .leading)

            Spacer()
        }
    }

    private var inputArea: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.small) {
            AppInputField(
                title: nil,
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
            .disabled(
                inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                viewModel.selectedModel == "Select a Model"
            )
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
    }

    private func queueItemRow(_ item: WorkspaceModel.QueuedMessage) -> some View {
        HStack(spacing: AppTheme.Spacing.small) {
            if editingQueueId == item.id {
                AppInputField(
                    title: nil,
                    placeholder: "Edit message",
                    text: $editingQueueText
                )
                .onSubmit {
                    viewModel.updateQueuedMessage(id: item.id, text: editingQueueText)
                    editingQueueId = nil
                }
            } else {
                Text(item.text)
                    .font(AppTheme.Typography.body)
                    .lineLimit(2)
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)
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
            } else if hoveredQueueId == item.id {
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
                .foregroundStyle(AppTheme.ColorToken.textSecondary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xSmall)
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .background(AppTheme.ColorToken.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.small)
        .onHover { isHovered in
            hoveredQueueId = isHovered ? item.id : nil
        }
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

// MARK: - Preview Helpers

@MainActor
private func makePreviewDependencies() -> (workspace: WorkspaceModel, router: AppRouter) {
    let router = AppRouter()
    let db = try! DatabaseManager()
    let agentRepo = AgentRepositoryImpl(dbManager: db)
    let taskRepo = TaskRepositoryImpl(dbManager: db)
    let scheduleRepo = TaskScheduleRepositoryImpl(dbManager: db)
    let runRepo = TaskRunRepositoryImpl(dbManager: db)
    let contentRepo = GeneratedContentRepositoryImpl(dbManager: db)
    let approvalRepo = ApprovalQueueRepositoryImpl(dbManager: db)
    let pubRepo = PublicationTargetRepositoryImpl(dbManager: db)
    let taskTypeRepo = TaskTypeRepositoryImpl(dbManager: db)
    let settingsSvc = SettingsService()
    let approvalSvc = ApprovalService(
        approvalRepository: approvalRepo,
        contentRepository: contentRepo,
        publicationTargetRepository: pubRepo
    )
    let pubSvc = PublicationService(
        approvalQueueRepository: approvalRepo,
        publicationRepository: pubRepo,
        contentRepository: contentRepo,
        cacheService: CacheService(cacheRepository: RemotePostCacheRepositoryImpl(dbManager: db)),
        settingsService: settingsSvc,
        deviantArtClient: nil,
        patreonClient: nil
    )
    let versionSvc = ContentVersioningService(contentRepository: contentRepo)
    let deps = AppDependencies(
        agentRepository: agentRepo,
        taskRepository: taskRepo,
        taskScheduleRepository: scheduleRepo,
        taskRunRepository: runRepo,
        contentRepository: contentRepo,
        approvalRepository: approvalRepo,
        publicationRepository: pubRepo,
        taskTypeRepository: taskTypeRepo,
        deviantArtClient: nil,
        patreonClient: nil,
        settingsService: settingsSvc,
        approvalService: approvalSvc,
        versioningService: versionSvc,
        publicationService: pubSvc,
        loadWorkspaceUseCase: LoadWorkspaceUseCase(
            agentRepository: agentRepo,
            taskRepository: taskRepo,
            taskScheduleRepository: scheduleRepo,
            taskRunRepository: runRepo,
            contentRepository: contentRepo,
            approvalQueueRepository: approvalRepo,
            publicationRepository: pubRepo
        ),
        loadTaskCreationContextUseCase: LoadTaskCreationContextUseCase(
            agentRepository: agentRepo,
            taskTypeRepository: taskTypeRepo
        ),
        createAgentUseCase: CreateAgentUseCase(agentRepository: agentRepo),
        createTaskUseCase: CreateTaskUseCase(
            taskRepository: taskRepo,
            scheduleRepository: scheduleRepo,
            settingsService: settingsSvc
        ),
        approveContentUseCase: ApproveContentUseCase(approvalService: approvalSvc),
        rejectContentUseCase: RejectContentUseCase(approvalService: approvalSvc),
        publishContentUseCase: PublishContentUseCase(
            publicationService: pubSvc,
            settingsService: settingsSvc
        ),
        editContentUseCase: EditContentUseCase(versioningService: versionSvc),
        loadContentEditorUseCase: LoadContentEditorUseCase(
            contentRepository: contentRepo,
            versioningService: versionSvc
        ),
        aiClient: AIClient(),
        contextExtractor: ContextExtractor(),
        chatHistoryStore: ChatHistoryStore(databaseManager: db)
    )
    return (WorkspaceModel(dependencies: deps), router)
}

@MainActor
private final class PreviewAIChatViewModel: AIChatViewModel {
    init() {
        let (workspace, router) = makePreviewDependencies()
        super.init(
            aiClient: AIClient(),
            contextExtractor: ContextExtractor(),
            chatHistoryStore: ChatHistoryStore(databaseManager: try! DatabaseManager()),
            workspace: workspace,
            router: router
        )
        messages = [
            ChatMessage(role: .user, content: "What the dog doin?"),
            ChatMessage(role: .assistant, content: "Ur mom lol")
        ]
        availableModels = ["model", "claude"]
        selectedModel = "Select a Model"
    }

    override func fetchAvailableModels() async {}
    override func loadHistory() async {}
    override func sendMessage(text: String) async {
        isGenerating = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        messages.append(ChatMessage(role: .assistant, content: "This is a preview response."))
        isGenerating = false
    }
    override func clearHistory() async { messages.removeAll() }
    override func loadHistorySessions() async {}
    override func loadSession(_ session: ChatSession) async {}
    override func removeQueuedMessage(id: UUID) {}
    override func updateQueuedMessage(id: UUID, text: String) {}
    override func clearQueue() {}
}

@MainActor
private final class PreviewAIChatLoadingViewModel: AIChatViewModel {
    init() {
        let (workspace, router) = makePreviewDependencies()
        super.init(
            aiClient: AIClient(),
            contextExtractor: ContextExtractor(),
            chatHistoryStore: ChatHistoryStore(databaseManager: try! DatabaseManager()),
            workspace: workspace,
            router: router
        )
        messages = [
            ChatMessage(role: .user, content: "Summarize the DeviantArt integration docs")
        ]
        availableModels = ["llama-3-8b"]
        selectedModel = "Select a Model"
        isGenerating = true
    }

    override func fetchAvailableModels() async {}
    override func loadHistory() async {}
    override func sendMessage(text: String) async {}
    override func clearHistory() async { messages.removeAll() }
    override func loadHistorySessions() async {}
    override func loadSession(_ session: ChatSession) async {}
    override func removeQueuedMessage(id: UUID) {}
    override func updateQueuedMessage(id: UUID, text: String) {}
    override func clearQueue() {}
}

@MainActor
private final class PreviewAIChatStreamingViewModel: AIChatViewModel {
    private var streamTask: Task<Void, Never>?

    init() {
        let (workspace, router) = makePreviewDependencies()
        super.init(
            aiClient: AIClient(),
            contextExtractor: ContextExtractor(),
            chatHistoryStore: ChatHistoryStore(databaseManager: try! DatabaseManager()),
            workspace: workspace,
            router: router
        )
        messages = [
            ChatMessage(role: .user, content: "Write a haiku about coding")
        ]
        availableModels = ["llama-3-8b"]
        selectedModel = "Select a Model"
        isGenerating = true

        let words = ["Debug", "all", "night,", "ship", "by", "dawn.", "Code", "is", "poetry", "in", "motion."]
        streamTask = Task { @MainActor in
            var text = ""
            for (index, word) in words.enumerated() {
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { break }
                text += (index > 0 ? " " : "") + word
                messages = messages.dropLast() + [ChatMessage(role: .assistant, content: text)]
            }
            isGenerating = false
        }
    }

    override func fetchAvailableModels() async {}
    override func loadHistory() async {}
    override func sendMessage(text: String) async {}
    override func clearHistory() async { messages.removeAll() }
    override func loadHistorySessions() async {}
    override func loadSession(_ session: ChatSession) async {}
    override func removeQueuedMessage(id: UUID) {}
    override func updateQueuedMessage(id: UUID, text: String) {}
    override func clearQueue() {}
}

#Preview("AI Chat") {
    AIChatView(viewModel: PreviewAIChatViewModel())
        .frame(width: 400, height: 600)
}

#Preview("Loading") {
    AIChatView(viewModel: PreviewAIChatLoadingViewModel())
        .frame(width: 400, height: 600)
}

#Preview("Streaming") {
    AIChatView(viewModel: PreviewAIChatStreamingViewModel())
        .frame(width: 400, height: 600)
}

@MainActor
private final class PreviewAIChatQueuedViewModel: AIChatViewModel {
    private var previewQueue: [WorkspaceModel.QueuedMessage] = [
        WorkspaceModel.QueuedMessage(text: "How do I set up DeviantArt OAuth?"),
        WorkspaceModel.QueuedMessage(text: "What agents are currently running?"),
        WorkspaceModel.QueuedMessage(text: "Export last week's content report")
    ]

    override var queuedMessages: [WorkspaceModel.QueuedMessage] { previewQueue }

    init() {
        let (workspace, router) = makePreviewDependencies()
        super.init(
            aiClient: AIClient(),
            contextExtractor: ContextExtractor(),
            chatHistoryStore: ChatHistoryStore(databaseManager: try! DatabaseManager()),
            workspace: workspace,
            router: router
        )
        messages = [
            ChatMessage(role: .user, content: "What's the system status?"),
            ChatMessage(role: .assistant, content: "All systems operational. 3 agents active, 2 tasks scheduled.")
        ]
        availableModels = ["llama-3-8b"]
        selectedModel = "Select a Model"
        isGenerating = true
    }

    override func fetchAvailableModels() async {}
    override func loadHistory() async {}
    override func sendMessage(text: String) async {}
    override func clearHistory() async { messages.removeAll() }
    override func loadHistorySessions() async {}
    override func loadSession(_ session: ChatSession) async {}
    override func removeQueuedMessage(id: UUID) { previewQueue.removeAll { $0.id == id } }
    override func updateQueuedMessage(id: UUID, text: String) {
        if let index = previewQueue.firstIndex(where: { $0.id == id }) {
            previewQueue[index] = WorkspaceModel.QueuedMessage(id: id, text: text)
        }
    }
    override func clearQueue() { previewQueue.removeAll() }
}

#Preview("Queued") {
    AIChatView(viewModel: PreviewAIChatQueuedViewModel())
        .frame(width: 400, height: 600)
}

@MainActor
private final class PreviewAIChatHistoryViewModel: AIChatViewModel {
    private var previewSessions: [ChatSession] = [
        ChatSession(section: "Dashboard", messages: [
            ChatMessage(role: .user, content: "What agents are running?"),
            ChatMessage(role: .assistant, content: "3 agents active.")
        ], createdAt: Date().addingTimeInterval(-3600), updatedAt: Date().addingTimeInterval(-3600)),
        ChatSession(section: "Agents", messages: [
            ChatMessage(role: .user, content: "Create a new agent"),
            ChatMessage(role: .assistant, content: "Agent created successfully.")
        ], createdAt: Date().addingTimeInterval(-86400), updatedAt: Date().addingTimeInterval(-86400)),
        ChatSession(section: "Settings", messages: [
            ChatMessage(role: .user, content: "How do I configure OAuth?")
        ], createdAt: Date().addingTimeInterval(-172800), updatedAt: Date().addingTimeInterval(-172800))
    ]

    override var historySessions: [ChatSession] { previewSessions }

    init() {
        let (workspace, router) = makePreviewDependencies()
        super.init(
            aiClient: AIClient(),
            contextExtractor: ContextExtractor(),
            chatHistoryStore: ChatHistoryStore(databaseManager: try! DatabaseManager()),
            workspace: workspace,
            router: router
        )
        messages = []
        availableModels = ["llama-3-8b"]
        selectedModel = "Select a Model"
        showHistory = true
    }

    override func fetchAvailableModels() async {}
    override func loadHistory() async {}
    override func sendMessage(text: String) async {}
    override func clearHistory() async {}
    override func loadHistorySessions() async {}
    override func loadSession(_ session: ChatSession) async { showHistory = false }
    override func removeQueuedMessage(id: UUID) {}
    override func updateQueuedMessage(id: UUID, text: String) {}
    override func clearQueue() {}
}

#Preview("History") {
    AIChatView(viewModel: PreviewAIChatHistoryViewModel())
        .frame(width: 400, height: 600)
}

