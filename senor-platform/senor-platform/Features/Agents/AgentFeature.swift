import SwiftUI

struct AgentsScreen: View {
    @ObservedObject var viewModel: AgentsViewModel
    @ObservedObject var router: AppRouter
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                title: "Agents",
                detail: "\(viewModel.agents.count) configured",
                action: AnyView(
                    Button(action: onCreate) {
                        Label("New Agent", systemImage: AppTheme.Icon.add)
                    }
                    .appButtonStyle(.borderedProminent)
                )
            )
            .padding(AppTheme.Spacing.screenPadding)

            AppDivider()

            if viewModel.agents.isEmpty {
                Spacer()
                AppEmptyState(
                    title: "No Agents Yet",
                    systemImage: AppTheme.Icon.agent,
                    message: "Create your first agent to start generating and publishing content."
                )
                Spacer()
            } else {
                List(viewModel.agents, selection: $router.selectedAgentID) { agent in
                    AppListRow {
                        AppHStack(spacing: .medium) {
                            AppIcon(AppTheme.Icon.agent, size: .medium, color: AppTheme.ColorToken.accent)
                            AppVStack(spacing: .tight, alignment: .leading) {
                                AppText(agent.displayName, style: .headline)
                                AppText(
                                    agent.status.displayName,
                                    style: .caption,
                                    color: AppTheme.ColorToken.textSecondary
                                )
                            }
                            Spacer()
                            AppStatusPill(
                                title: "\(agent.taskCount) tasks",
                                color: AppTheme.ColorToken.statusNeutral
                            )
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct AgentFormSheet: View {
    @EnvironmentObject private var appState: AppShellModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AgentsViewModel

    @State private var displayName = ""
    @State private var description = ""
    @State private var workerScriptPath = ""
    @State private var configJSON = "{}"
    @State private var isActive = true
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    AppInputField(
                        title: "Display Name",
                        placeholder: "Enter display name",
                        text: $displayName
                    )
                    AppInputField(
                        title: "Description",
                        placeholder: "Enter description",
                        text: $description,
                        isMultiline: true,
                        height: 80
                    )
                    Toggle("Active", isOn: $isActive)
                }

                Section("Runtime") {
                    AppInputField(
                        title: "Worker Script Path",
                        placeholder: "Enter script path",
                        text: $workerScriptPath
                    )
                    AppInputField(
                        title: "Config JSON",
                        placeholder: "Enter configuration JSON",
                        text: $configJSON,
                        isMultiline: true,
                        height: 120
                    )
                }
            }
            .navigationTitle("New Agent")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await submit() }
                    }
                    .disabled(displayName.isEmpty || workerScriptPath.isEmpty || isSaving)
                }
            }
        }
        .frame(minWidth: AppTheme.Layout.minSheetWidth, minHeight: AppTheme.Layout.minSheetHeight)
    }

    private func submit() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await viewModel.create(
                draft: AgentDraft(
                    displayName: displayName,
                    isActive: isActive,
                    description: description,
                    workerScriptPath: workerScriptPath,
                    configJSON: configJSON
                )
            )
            dismiss()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Previews

// Note: Preview requires complex dependencies - use WorkspaceView for testing
