import SwiftUI

// MARK: - Main Content Provider

struct ComfyUIContentProvider: MainContentProvider {
    let section: AppSection = .comfyUI
    @MainActor func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(ComfyUIScreen(
            viewModel: workspace.comfyUIViewModel,
            router: router
        ))
    }
}

// MARK: - Inspector Provider

struct ComfyUIInspectorProvider: InspectorContentProvider {
    let section: AppSection = .comfyUI
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        if let execution = workspace.comfyUIViewModel.selectedExecution {
            return AnyView(ComfyUIExecutionDetailPanel(execution: execution))
        }
        if let workflow = workspace.comfyUIViewModel.selectedWorkflow {
            return AnyView(ComfyUIWorkflowDetailPanel(workflow: workflow))
        }
        return AnyView(AppEmptyState(
            title: "Nothing Selected",
            systemImage: AppTheme.Icon.sidebar,
            message: "Choose a workflow or execution to inspect details."
        ))
    }
}

// MARK: - Workflow Detail Panel

struct ComfyUIWorkflowDetailPanel: View {
    let workflow: ComfyUIWorkflow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                AppSectionHeader(title: workflow.name, detail: nil)

                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        AppText("Metadata", style: .headline)
                        DetailRow(label: "Nodes", value: "\(workflow.nodes.count)")
                        DetailRow(label: "File", value: workflow.id)
                        DetailRow(label: "Path", value: workflow.path)
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        AppText("Node Types", style: .headline)
                        let classTypes = Set(workflow.nodes.map { $0.classType }).sorted()
                        FlowLayout(spacing: AppTheme.Spacing.small) {
                            ForEach(classTypes, id: \.self) { classType in
                                ComfyUITagPill(text: classType)
                            }
                        }
                    }
                }
            }
            .appScreenPadding()
        }
    }
}

// MARK: - Execution Detail Panel

struct ComfyUIExecutionDetailPanel: View {
    let execution: ComfyUIExecution

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                AppSectionHeader(
                    title: execution.workflowName,
                    detail: String(execution.id.prefix(8))
                )

                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        AppText("Status", style: .headline)
                        HStack {
                            statusIcon
                            AppText(execution.status.rawValue.capitalized, style: .body)
                                .foregroundStyle(statusColor)
                            Spacer()
                        }
                        if let error = execution.errorMessage {
                            AppText(error, style: .caption, color: AppTheme.ColorToken.statusError)
                        }
                    }
                }

                if let startedAt = execution.startedAt {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            AppText("Timing", style: .headline)
                            DetailRow(label: "Started", value: formatDate(startedAt))
                            if let completedAt = execution.completedAt {
                                DetailRow(label: "Completed", value: formatDate(completedAt))
                                let duration = completedAt.timeIntervalSince(startedAt)
                                DetailRow(label: "Duration", value: String(format: "%.1fs", duration))
                            }
                        }
                    }
                }

                if !execution.outputs.isEmpty {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            AppText("Outputs", style: .headline)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: AppTheme.Spacing.medium) {
                                ForEach(execution.outputs, id: \.self) { path in
                                    OutputImageView(path: path)
                                }
                            }
                        }
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        AppText("Output Directory", style: .headline)
                        AppText(execution.outputDirectory, style: .caption, color: AppTheme.ColorToken.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .appScreenPadding()
        }
    }

    private var statusIcon: some View {
        switch execution.status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(AppTheme.ColorToken.statusNeutral)
        case .running:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(AppTheme.ColorToken.statusInfo)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.ColorToken.statusSuccess)
        case .error, .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AppTheme.ColorToken.statusError)
        }
    }

    private var statusColor: Color {
        switch execution.status {
        case .queued:
            return AppTheme.ColorToken.statusNeutral
        case .running:
            return AppTheme.ColorToken.statusInfo
        case .completed:
            return AppTheme.ColorToken.statusSuccess
        case .error, .cancelled:
            return AppTheme.ColorToken.statusError
        }
    }

    private func formatDate(_ date: Date) -> String {
        RelativeDateFormatter.format(date)
    }
}

// MARK: - Output Image View

struct OutputImageView: View {
    let path: String

    var body: some View {
        let url = URL(fileURLWithPath: path)
        Group {
            if FileManager.default.fileExists(atPath: path) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .empty, .failure:
                        AppTheme.ColorToken.textSecondary.opacity(0.2)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                AppTheme.ColorToken.textSecondary.opacity(0.2)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    )
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
    }
}

// MARK: - Supporting Components

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            AppText(label, style: .caption, color: AppTheme.ColorToken.textSecondary)
                .frame(width: 80, alignment: .leading)
            AppText(value, style: .body)
                .lineLimit(2)
            Spacer()
        }
    }
}

private struct ComfyUITagPill: View {
    let text: String

    var body: some View {
        AppText(text, style: .caption2)
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, AppTheme.Spacing.xSmall)
            .background(AppTheme.ColorToken.accent.opacity(0.1))
            .foregroundStyle(AppTheme.ColorToken.accent)
            .cornerRadius(AppTheme.CornerRadius.small)
    }
}

// MARK: - Preview Helpers

#if DEBUG
public func previewComfyUIViewModel() -> ComfyUIViewModel {
    let viewModel = ComfyUIViewModel(
        client: ComfyUIClient(),
        executionRepository: PreviewComfyUIExecutionRepository(),
        settingsService: SettingsService()
    )
    viewModel.setConnected(true)
    return viewModel
}

private actor PreviewComfyUIExecutionRepository: ComfyUIExecutionRepository {
    func create(execution: ComfyUIExecutionRecord) async throws -> ComfyUIExecutionRecord { execution }
    func update(execution: ComfyUIExecutionRecord) async throws -> ComfyUIExecutionRecord { execution }
    func getById(id: String) async throws -> ComfyUIExecutionRecord? { nil }
    func listByWorkflow(workflowID: String, limit: Int) async throws -> [ComfyUIExecutionRecord] { [] }
    func listRecent(limit: Int) async throws -> [ComfyUIExecutionRecord] { [] }
    func listByStatus(status: String, limit: Int) async throws -> [ComfyUIExecutionRecord] { [] }
    func delete(id: String) async throws {}
}
#endif
