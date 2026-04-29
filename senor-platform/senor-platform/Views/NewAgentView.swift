import SwiftUI

struct NewAgentView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        if let workspace = appState.workspace {
            AgentFormSheet(
                formViewModel: AgentFormViewModel(
                    createAgentUseCase: workspace.dependencies.createAgentUseCase,
                    onComplete: {
                        await workspace.refreshAll()
                    }
                )
            )
        } else {
            EmptyView()
        }
    }
}
