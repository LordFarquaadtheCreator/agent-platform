import SwiftUI

struct JSONEditorView: View {
    @EnvironmentObject private var appState: AppShellModel
    let contentId: String

    var body: some View {
        if let viewModel = appState.workspace?.contentViewModel {
            ContentJSONEditorSheet(viewModel: viewModel, contentId: contentId)
        } else {
            EmptyView()
        }
    }
}

struct VersionHistoryView: View {
    @EnvironmentObject private var appState: AppShellModel
    let contentId: String

    var body: some View {
        if let viewModel = appState.workspace?.contentViewModel {
            ContentVersionHistorySheet(viewModel: viewModel, contentId: contentId)
        } else {
            EmptyView()
        }
    }
}
