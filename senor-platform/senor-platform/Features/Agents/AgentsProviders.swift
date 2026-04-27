import SwiftUI

// MARK: - Main Content Provider

struct AgentsContentProvider: MainContentProvider {
    let section: AppSection = .agents
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(AgentsScreen(viewModel: workspace.agentsViewModel, router: router) {
            appState.present(.newAgent)
        })
    }
}

// MARK: - Inspector Provider

struct AgentsInspectorProvider: InspectorContentProvider {
    let section: AppSection = .agents
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        guard let agent = workspace.agentsViewModel.agents.first(where: { $0.id == router.selectedAgentID }) else {
            return AnyView(AppEmptyState(
                title: "Nothing Selected",
                systemImage: AppTheme.Icon.sidebar,
                message: "Choose an agent to inspect details."
            ))
        }
        return AnyView(AgentInspectorCard(agent: agent))
    }
}
