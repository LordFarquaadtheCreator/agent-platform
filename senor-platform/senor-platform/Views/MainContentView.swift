import SwiftUI

struct MainContentView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        if let workspace = appState.workspace {
            AppShellView(workspace: workspace)
        } else {
            EmptyView()
        }
    }
}
