import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppShellModel
    @ObservedObject var workspace: WorkspaceModel
    @State private var showSidebar = true
    @State private var showInspector = true
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
                    .frame(minWidth: AppTheme.Layout.sidebarIdealWidth, idealWidth: AppTheme.Layout.sidebarIdealWidth, maxWidth: AppTheme.Layout.sidebarIdealWidth)
            }

            contentRegistry.view(for: router.selectedSection, using: workspace, router: router, appState: appState)
                .frame(minWidth: AppTheme.Layout.mainAreaMinWidth)

            if showInspector {
                ResizeHandle(width: $inspectorWidth, minWidth: AppTheme.Layout.detailMinWidth)

                inspectorRegistry.view(for: router.selectedSection, using: workspace, router: router, appState: appState)
                    .frame(width: inspectorWidth)
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
                                AppStatusPill(title: "\(approvalsViewModel.approvals.count)", color: AppTheme.ColorToken.statusError)
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
                            : Color.clear
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
            .fill(Color.clear)
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
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    Text("AppShellView preview requires full dependency injection")
}
