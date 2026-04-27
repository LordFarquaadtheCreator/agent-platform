import SwiftUI
import MarkdownUI

// MARK: - Main Content Provider

struct PatreonContentProvider: MainContentProvider {
    let section: AppSection = .patreon
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(PatreonScreen(viewModel: workspace.patreonViewModel, router: router))
    }
}

// MARK: - Inspector Provider

struct PatreonInspectorProvider: InspectorContentProvider {
    let section: AppSection = .patreon
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        if let post = workspace.patreonViewModel.posts.first(where: { $0.id == router.selectedPostID }) {
            return AnyView(PatreonPostDetailPanel(post: post))
        }
        if let member = workspace.patreonViewModel.members.first(where: { $0.id == router.selectedMemberID }) {
            return AnyView(PatreonMemberDetailPanel(member: member))
        }
        return AnyView(AppEmptyState(
            title: "Nothing Selected",
            systemImage: AppTheme.Icon.sidebar,
            message: "Choose a post or patron to inspect details."
        ))
    }
}
