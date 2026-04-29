import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        Group {
            if appState.isInitializing {
                loadingView
            } else if let workspace = appState.workspace {
                AppShellView(workspace: workspace)
            } else {
                AppEmptyState(
                    title: "Initialization Failed",
                    systemImage: AppTheme.Icon.exclamation,
                    message: appState.errorMessage ?? "The app could not finish bootstrapping."
                )
            }
        }
        .sheet(item: $appState.activeSheet) { sheet in
            if let workspace = appState.workspace {
                switch sheet {
                case .newAgent:
                    AgentFormSheet(viewModel: workspace.agentsViewModel)

                case .newTask:
                    TaskFormSheet(viewModel: workspace.tasksViewModel)

                case .settings:
                    SettingsSheetView(viewModel: workspace.settingsViewModel)

                case .editContent(let contentId):
                    ContentJSONEditorSheet(viewModel: workspace.contentViewModel, contentId: contentId)

                case .versionHistory(let contentId):
                    ContentVersionHistorySheet(viewModel: workspace.contentViewModel, contentId: contentId)
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            AppText(appState.errorMessage ?? "", style: .body)
        }
        .toast(message: $appState.toastMessage)
        .environment(\.privacyMode, appState.privacyMode)
        .onOpenURL { url in
            // Note: Version verification happens in handleCallback (DeviantArtModel.swift)
            // State parameter contains embedded version identifier for validation
            guard url.scheme == "senorplatform" else { return }
            guard url.host == "oauth" else { return }

            if url.path == "/deviantart" {
                guard let viewModel = appState.workspace?.deviantArtViewModel else { return }
                Task {
                    await viewModel.handleCallback(url: url)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            ProgressView()
                .scaleEffect(1.3)
            AppText("Initializing Senor Platform…", style: .headline, color: AppTheme.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.ColorToken.chromeBackground)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppShellModel())
}
