import SwiftUI

struct JSONEditorView: View {
    @EnvironmentObject private var appState: AppShellModel
    let contentId: String

    var body: some View {
        if let model = appState.workspace?.contentModel {
            ContentJSONEditorSheet(model: model, contentId: contentId)
        } else {
            EmptyView()
        }
    }
}

struct VersionHistoryView: View {
    @EnvironmentObject private var appState: AppShellModel
    let contentId: String

    var body: some View {
        if let model = appState.workspace?.contentModel {
            ContentVersionHistorySheet(model: model, contentId: contentId)
        } else {
            EmptyView()
        }
    }
}
