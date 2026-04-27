import SwiftUI

struct SettingsContentProvider: MainContentProvider {
    let section: AppSection = .settings
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(SettingsScreen(viewModel: workspace.settingsViewModel))
    }
}
