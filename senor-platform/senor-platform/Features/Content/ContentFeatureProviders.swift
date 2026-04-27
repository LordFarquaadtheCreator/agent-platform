import SwiftUI

// MARK: - Main Content Provider

struct ContentContentProvider: MainContentProvider {
    let section: AppSection = .content
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(ContentScreen(viewModel: workspace.contentViewModel, router: router))
    }
}

// MARK: - Inspector Provider

struct ContentInspectorProvider: InspectorContentProvider {
    let section: AppSection = .content
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        let content = workspace.contentViewModel.contentItems.first { $0.id == router.selectedContentID }
        guard let content else {
            return AnyView(AppEmptyState(
                title: "Nothing Selected",
                systemImage: AppTheme.Icon.sidebar,
                message: "Choose content to inspect details."
            ))
        }
        return AnyView(ContentInspectorCard(
            content: content,
            approvalsViewModel: workspace.approvalsViewModel
        ))
    }
}
