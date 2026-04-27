import SwiftUI

struct DashboardContentProvider: MainContentProvider {
    let section: AppSection = .dashboard
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(DashboardScreen(viewModel: workspace.dashboardViewModel))
    }
}
