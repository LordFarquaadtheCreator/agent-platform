import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppShellModel
    @ObservedObject var workspace: WorkspaceModel
    @State private var showSidebar = true
    @State private var showInspector = true
    @State private var showAIChat = false
    @State private var inspectorWidth: CGFloat = AppTheme.Layout.detailIdealWidth

    // MARK: - Registries

    private let contentRegistry = MainContentRegistry(providers: [
        DeviantArtContentProvider(),
        PatreonContentProvider(),
        DashboardContentProvider(),
        AgentsContentProvider(),
        TasksContentProvider(),
        ContentContentProvider(),
        ApprovalsContentProvider(),
        ToolsContentProvider(),
        SettingsContentProvider()
    ])

    private let inspectorRegistry = InspectorContentRegistry(providers: [
        DeviantArtInspectorProvider(),
        AgentsInspectorProvider(),
        ContentInspectorProvider(),
        PatreonInspectorProvider()
    ])

    var body: some View {
        let router = workspace.router
        HStack(spacing: 0) {
            if showSidebar {
                AppSidebarView(router: router, approvalsViewModel: workspace.approvalsViewModel)
                    .frame(
                        minWidth: AppTheme.Layout.sidebarIdealWidth,
                        idealWidth: AppTheme.Layout.sidebarIdealWidth,
                        maxWidth: AppTheme.Layout.sidebarIdealWidth
                    )
            }

            contentRegistry.view(for: router.selectedSection, using: workspace, router: router, appState: appState)
                .frame(minWidth: AppTheme.Layout.mainAreaMinWidth)

            if showInspector {
                ResizeHandle(width: $inspectorWidth, minWidth: AppTheme.Layout.detailMinWidth)

                if showAIChat {
                    AIChatPanel(workspace: workspace, router: router, appState: appState)
                        .frame(width: inspectorWidth)
                } else {
                    inspectorRegistry.view(
                    for: router.selectedSection,
                    using: workspace,
                    router: router,
                    appState: appState
                )
                        .frame(width: inspectorWidth)
                }
            }
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
                    showAIChat.toggle()
                } label: {
                    Label(
                        showAIChat ? "Show Inspector" : "AI Chat",
                        systemImage: showAIChat ? "sidebar.right" : "sparkles"
                    )
                }
                .foregroundStyle(showAIChat ? AppTheme.ColorToken.accent : AppTheme.ColorToken.textPrimary)

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

                Button {
                    appState.privacyMode.toggle()
                } label: {
                    Label(
                        appState.privacyMode ? "Disable Privacy Mode" : "Enable Privacy Mode",
                        systemImage: appState.privacyMode ? "eye.slash.fill" : "eye"
                    )
                }
            }
        }
    }
}

// MARK: - Sidebar View

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
                        HStack(spacing: AppTheme.Spacing.small) {
                            Image(systemName: section.icon)
                                .frame(width: 24)
                            AppText(section.title, style: .body)
                            Spacer()
                            if section == .approvals && !approvalsViewModel.approvals.isEmpty {
                                AppStatusPill(
                                    title: "\(approvalsViewModel.approvals.count)",
                                    color: AppTheme.ColorToken.statusError
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, AppTheme.Spacing.small)
                    .padding(.horizontal, AppTheme.Spacing.small)
                    .background(
                        section == router.selectedSection
                            ? AppTheme.ColorToken.accent.opacity(0.15)
                            : AppTheme.ColorToken.clear
                    )
                    .cornerRadius(AppTheme.CornerRadius.small)
                    .contentShape(Rectangle())
                }
            }
            .listStyle(.plain)
            .padding(.horizontal, AppTheme.Spacing.small)

            Spacer()
        }
        .background(AppTheme.ColorToken.chromeBackground)
    }
}

// MARK: - Resize Handle

private struct ResizeHandle: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    @State private var startWidth: CGFloat = 0
    @State private var dragStartLocation: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(AppTheme.ColorToken.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if startWidth == 0 {
                            startWidth = width
                            dragStartLocation = value.location.x
                        }
                        let delta = dragStartLocation - value.location.x
                        width = max(minWidth, startWidth + delta)
                    }
                    .onEnded { _ in
                        startWidth = 0
                    }
            )
            .overlay(
                Rectangle()
                    .fill(AppTheme.ColorToken.gray.opacity(0.3))
                    .frame(width: 1)
            )
    }
}

// MARK: - AI Chat Panel

private struct AIChatPanel: View {
    @ObservedObject var workspace: WorkspaceModel
    @ObservedObject var router: AppRouter
    @EnvironmentObject var appState: AppShellModel

    @State private var viewModel: AIChatViewModel?

    var body: some View {
        if let viewModel = viewModel {
            AIChatView(viewModel: viewModel)
        } else {
            ProgressView("Loading AI Chat...")
        }
    }

    init(workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) {
        self.workspace = workspace
        self.router = router
        self._appState = EnvironmentObject(appState)

        // Initialize viewModel with dependencies
        guard let dependencies = workspace.dependencies else {
            return
        }

        self._viewModel = State(initialValue: AIChatViewModel(
            aiClient: dependencies.aiClient,
            contextExtractor: dependencies.contextExtractor,
            chatHistoryStore: dependencies.chatHistoryStore,
            workspace: workspace,
            router: router
        ))
    }
}

// MARK: - Preview

#Preview {
    Text("AppShellView preview requires full dependency injection")
}
