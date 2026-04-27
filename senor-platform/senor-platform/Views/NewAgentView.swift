import SwiftUI

struct NewAgentView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        if let viewModel = appState.workspace?.agentsViewModel {
            AgentFormSheet(viewModel: viewModel)
        } else {
            EmptyView()
        }
    }
}
