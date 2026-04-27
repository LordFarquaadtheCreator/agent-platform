import SwiftUI

struct NewAgentView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        if let model = appState.workspace?.agentsModel {
            AgentFormSheet(model: model)
        } else {
            EmptyView()
        }
    }
}
