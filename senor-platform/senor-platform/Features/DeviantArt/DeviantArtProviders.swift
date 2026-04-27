import SwiftUI

// MARK: - Main Content Provider

struct DeviantArtContentProvider: MainContentProvider {
    let section: AppSection = .deviantArt
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(DeviantArtScreen(viewModel: workspace.deviantArtViewModel, router: router))
    }
}

// MARK: - Inspector Provider

struct DeviantArtInspectorProvider: InspectorContentProvider {
    let section: AppSection = .deviantArt
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        guard let deviation = workspace.deviantArtViewModel.deviations.first(where: { $0.id == router.selectedDeviationID }) else {
            return AnyView(AppEmptyState(
                title: "Nothing Selected",
                systemImage: AppTheme.Icon.sidebar,
                message: "Choose a deviation to inspect details."
            ))
        }
        return AnyView(DeviationDetailPanel(deviation: deviation, viewModel: workspace.deviantArtViewModel))
    }
}
