import SwiftUI

struct AIChatView: View {
    @ObservedObject private var viewModel: AIChatViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    init(viewModel: AIChatViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Messages
            messageList

            Divider()

            // Input
            inputArea
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task {
            await viewModel.loadHistory()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                AppText("AI Chat", style: .headline)
                AppText(viewModel.contextSummary, style: .caption, color: AppTheme.ColorToken.textSecondary)
            }

            Spacer()

            Button("Clear", systemImage: "trash") {
                Task { await viewModel.clearHistory() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.ColorToken.textSecondary)
        }
        .padding(AppTheme.Spacing.small)
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
                AppText(message.role == .user ? "You" : "AI", style: .caption, color: AppTheme.ColorToken.textSecondary)

                AppSurface(style: .flat) {
                    AppText(message.content, style: .body)
                        .foregroundStyle(message.role == .user ? AppTheme.ColorToken.textPrimary : AppTheme.ColorToken.textPrimary)
                        .textSelection(.enabled)
                }
                .background(
                    message.role == .user
                        ? AppTheme.ColorToken.accent.opacity(0.1)
                        : AppTheme.ColorToken.sectionBackground
                )
            }
            .frame(maxWidth: message.role == .user ? .infinity * 0.8 : .infinity * 0.8, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private var inputArea: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            AppInputField(
                placeholder: "Ask about this page...",
                text: $inputText
            )
            .focused($isInputFocused)
            .onSubmit {
                Task { await sendMessage() }
            }

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
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
        }
        .padding(AppTheme.Spacing.small)
    }

    private func sendMessage() async {
        let text = inputText
        inputText = ""
        await viewModel.sendMessage(text: text)
    }
}

#Preview {
    // Preview would require dependency injection
    Text("AIChatView preview requires full dependency setup")
}
