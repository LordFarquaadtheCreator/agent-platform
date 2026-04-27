import SwiftUI

struct ApprovalsContentProvider: MainContentProvider {
    let section: AppSection = .approvals
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(ApprovalsScreen(viewModel: workspace.approvalsViewModel))
    }
}
