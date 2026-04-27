import SwiftUI

struct AgentsScreen: View {
    @ObservedObject var model: AgentsModel
    @ObservedObject var router: AppRouter
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                title: "Agents",
                detail: "\(model.agents.count) configured",
                action: AnyView(
                    Button(action: onCreate) {
                        Label("New Agent", systemImage: AppTheme.Icon.add)
                    }
                    .appButtonStyle(.borderedProminent)
                )
            )
            .padding(AppTheme.Spacing.screenPadding)

            AppDivider()

            if model.agents.isEmpty {
                Spacer()
                AppEmptyState(
                    title: "No Agents Yet",
                    systemImage: AppTheme.Icon.agent,
                    message: "Create your first agent to start generating and publishing content."
                )
                Spacer()
            } else {
                List(model.agents, selection: $router.selectedAgentID) { agent in
                    AppListRow {
                        AppHStack(spacing: .medium) {
                            AppIcon(AppTheme.Icon.agent, size: .medium, color: AppTheme.ColorToken.accent)
                            AppVStack(spacing: .tight, alignment: .leading) {
                                AppText(agent.displayName, style: .headline)
                                AppText(agent.status.displayName, style: .caption, color: AppTheme.ColorToken.textSecondary)
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
    @ObservedObject var model: AgentsModel

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
                    TextField("Display Name", text: $displayName)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    Toggle("Active", isOn: $isActive)
                }

                Section("Runtime") {
                    TextField("Worker Script Path", text: $workerScriptPath)
                    TextEditor(text: $configJSON)
                        .frame(minHeight: 120)
                        .font(AppTheme.Typography.monospace)
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
            try await model.create(
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
