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
                    AgentFormSheet(model: workspace.agentsModel)

                case .newTask:
                    TaskFormSheet(model: workspace.tasksModel)

                case .settings:
                    SettingsSheetView(model: workspace.settingsModel)

                case .editContent(let contentId):
                    ContentJSONEditorSheet(model: workspace.contentModel, contentId: contentId)

                case .versionHistory(let contentId):
                    ContentVersionHistorySheet(model: workspace.contentModel, contentId: contentId)
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
        .onOpenURL { url in
            guard url.scheme == "senorplatform",
                  url.host == "oauth",
                  url.path == "/deviantart" else { return }
            Task {
                await appState.workspace?.deviantArtModel.handleCallback(url: url)
            }
        }
    }

    private var loadingView: some View {
        AppVStack(spacing: .medium) {
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
