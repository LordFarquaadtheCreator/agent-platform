import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppShellModel
    @ObservedObject var workspace: WorkspaceModel
    @State private var showSidebar = true
    @State private var showInspector = true

    var body: some View {
        SplitView(
            sidebarVisible: $showSidebar,
            detailVisible: $showInspector
        ) {
            AppSidebarView(router: workspace.router, approvalsViewModel: workspace.approvalsViewModel)
        } content: {
            AppMainAreaView(workspace: workspace, router: workspace.router)
        } detail: {
            AppInspectorPanel(workspace: workspace, router: workspace.router)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showSidebar.toggle()
                } label: {
                    Label(
                        showSidebar ? "Hide Sidebar" : "Show Sidebar",
                        systemImage: "sidebar.left"
                    )
                }

                Button {
                    showInspector.toggle()
                } label: {
                    Label(
                        showInspector ? "Hide Inspector" : "Show Inspector",
                        systemImage: "sidebar.right"
                    )
                }

                Button {
                    appState.present(.newAgent)
                } label: {
                    Label("New Agent", systemImage: AppTheme.Icon.add)
                }

                Button {
                    appState.present(.newTask)
                } label: {
                    Label("New Task", systemImage: AppTheme.Icon.taskAdd)
                }

                Button {
                    appState.present(.settings)
                } label: {
                    Label("Settings", systemImage: AppTheme.Icon.settings)
                }

                Button {
                    Task { await appState.refreshAll() }
                } label: {
                    Label("Refresh", systemImage: AppTheme.Icon.refresh)
                }
            }
        }
    }
}

private struct AppSidebarView: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var approvalsViewModel: ApprovalsViewModel

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(AppSection.allCases) { section in
                    Button {
                        router.selectedSection = section
                    } label: {
                        Label {
                            HStack {
                                AppText(section.title, style: .body)
                                if section == .approvals && !approvalsViewModel.approvals.isEmpty {
                                    Spacer()
                                    AppStatusPill(title: "\(approvalsViewModel.approvals.count)", color: AppTheme.ColorToken.statusError)
                                }
                            }
                        } icon: {
                            Image(systemName: section.icon)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, AppTheme.Spacing.listRowPadding)
                    .contentShape(Rectangle())
                    .listRowBackground(section == router.selectedSection ? AppTheme.ColorToken.chromeBackground.opacity(0.6) : nil)
                }
            }
            .listStyle(.sidebar)
        }
        .padding(AppTheme.Spacing.medium)
        .background(AppTheme.ColorToken.chromeBackground)
    }
}

private struct AppMainAreaView: View {
    @EnvironmentObject private var appState: AppShellModel
    @ObservedObject var workspace: WorkspaceModel
    @ObservedObject var router: AppRouter

    var body: some View {
        switch router.selectedSection {
        case .dashboard:
            DashboardScreen(viewModel: workspace.dashboardViewModel)

        case .agents:
            AgentsScreen(viewModel: workspace.agentsViewModel, router: workspace.router) {
                appState.present(.newAgent)
            }

        case .tasks:
            TasksScreen(viewModel: workspace.tasksViewModel) {
                appState.present(.newTask)
            }

        case .content:
            ContentScreen(viewModel: workspace.contentViewModel, router: workspace.router)

        case .approvals:
            ApprovalsScreen(viewModel: workspace.approvalsViewModel)

        case .tools:
            ToolsHostView()

        case .settings:
            SettingsScreen(viewModel: workspace.settingsViewModel)

        case .deviantArt:
            DeviantArtScreen(viewModel: workspace.deviantArtViewModel, router: workspace.router)

        case .patreon:
            PatreonScreen(viewModel: workspace.patreonViewModel)
        }
    }
}

private struct AppInspectorPanel: View {
    @EnvironmentObject private var appState: AppShellModel
    @ObservedObject var workspace: WorkspaceModel
    @ObservedObject var router: AppRouter

    var body: some View {
        Group {
            if router.selectedSection == .deviantArt, let deviation = selectedDeviation {
                DeviationDetailPanel(deviation: deviation, viewModel: workspace.deviantArtViewModel)
            } else if router.selectedSection == .content, let content = selectedContent {
                ContentInspectorCard(
                    content: content,
                    approvalsViewModel: workspace.approvalsViewModel
                )
            } else if router.selectedSection == .agents, let agent = selectedAgent {
                AgentInspectorCard(agent: agent)
            } else {
                AppEmptyState(
                    title: "Nothing Selected",
                    systemImage: AppTheme.Icon.sidebar,
                    message: "Choose an agent or content item to inspect details."
                )
            }
        }
        .padding(AppTheme.Spacing.medium)
    }

    private var selectedAgent: Agent? {
        workspace.agentsViewModel.agents.first { $0.id == router.selectedAgentID }
    }

    private var selectedContent: ContentSummary? {
        workspace.contentViewModel.contentItems.first { $0.id == router.selectedContentID }
    }

    private var selectedDeviation: DeviantArtClient.Deviation? {
        workspace.deviantArtViewModel.deviations.first { $0.id == router.selectedDeviationID }
    }
}

private struct AgentInspectorCard: View {
    let agent: Agent

    var body: some View {
        AppCard {
            AppVStack(spacing: .medium, alignment: .leading) {
                AppText(agent.displayName, style: .title3)
                AppStatusPill(
                    title: agent.status.displayName,
                    color: StatusColor.from(agent.status.rawValue).swiftUIColor
                )
                AppDivider()
                LabeledContent("Tasks", value: "\(agent.taskCount)")
                LabeledContent("Created", value: agent.createdAt.formatted())
                LabeledContent("Updated", value: agent.updatedAt.formatted())
            }
        }
    }
}

private struct ContentInspectorCard: View {
    @EnvironmentObject private var appState: AppShellModel
    let content: ContentSummary
    @ObservedObject var approvalsViewModel: ApprovalsViewModel
    @State private var rejectReason = ""
    @State private var showRejectDialog = false
    @State private var isProcessing = false

    var body: some View {
        AppCard {
            AppVStack(spacing: .medium, alignment: .leading) {
                AppText(content.title, style: .title3)
                AppStatusPill(
                    title: content.status.title,
                    color: StatusColor.from(content.status.rawValue).swiftUIColor
                )
                AppDivider()
                LabeledContent("Version", value: "\(content.version)")
                LabeledContent("Created", value: content.createdAt.formatted())

                Button("Edit JSON") {
                    appState.present(.editContent(content.id))
                }
                .appButtonStyle(.bordered)

                Button("Version History") {
                    appState.present(.versionHistory(content.id))
                }
                .appButtonStyle(.bordered)

                if content.status == .pending {
                    Button("Approve") {
                        Task { await approve() }
                    }
                    .appButtonStyle(.borderedProminent)
                    .tint(AppTheme.ColorToken.statusSuccess)

                    Button("Reject") {
                        showRejectDialog = true
                    }
                    .appButtonStyle(.borderedDestructive)
                }

                if content.status == .approved {
                    Button("Publish to DeviantArt") {
                        Task { await publish(.deviantArt) }
                    }
                    .appButtonStyle(.borderedProminent)

                    Button("Publish to Patreon") {
                        Task { await publish(.patreon) }
                    }
                    .appButtonStyle(.bordered)
                }
            }
        }
        .disabled(isProcessing)
        .alert("Reject Content", isPresented: $showRejectDialog) {
            TextField("Reason", text: $rejectReason)
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) {
                Task { await reject() }
            }
        } message: {
            AppText("Add an optional reason for rejecting this content.", style: .body)
        }
    }

    private func approve() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await approvalsViewModel.approve(contentId: content.id)
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func reject() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await approvalsViewModel.reject(contentId: content.id, reason: rejectReason.isEmpty ? nil : rejectReason)
            rejectReason = ""
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func publish(_ platform: PublicationPlatform) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await approvalsViewModel.publish(
                PublicationRequest(
                    contentId: content.id,
                    platform: platform,
                    title: content.title,
                    category: nil,
                    isMature: false,
                    tags: nil,
                    campaignId: nil,
                    isPaid: nil,
                    isPublic: nil,
                    tiers: nil
                )
            )
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    Text("AppShellView preview requires full dependency injection")
}
