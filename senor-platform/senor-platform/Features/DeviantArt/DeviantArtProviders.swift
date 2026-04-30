import SwiftUI

// MARK: - Main Content Provider

struct DeviantArtContentProvider: MainContentProvider {
    let section: AppSection = .deviantArt
    @MainActor func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(DeviantArtScreen(viewModel: workspace.deviantArtViewModel, router: router, connectivityService: workspace.dependencies.connectivityService))
    }
}

// MARK: - Inspector Provider

struct DeviantArtInspectorProvider: InspectorContentProvider {
    let section: AppSection = .deviantArt
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        let deviation = workspace.deviantArtViewModel.deviations.first { $0.id == router.selectedDeviationID }
        guard let deviation else {
            return AnyView(AppEmptyState(
                title: "Nothing Selected",
                systemImage: AppTheme.Icon.sidebar,
                message: "Choose a deviation to inspect details."
            ))
        }
        return AnyView(DeviationDetailPanel(deviation: deviation, viewModel: workspace.deviantArtViewModel))
    }
}
