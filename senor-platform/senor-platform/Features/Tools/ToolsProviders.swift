import SwiftUI

struct ToolsContentProvider: MainContentProvider {
    let section: AppSection = .tools
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(ToolsHostView())
    }
}
