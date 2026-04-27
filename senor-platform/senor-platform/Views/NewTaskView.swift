import SwiftUI

struct NewTaskView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        if let model = appState.workspace?.tasksModel {
            TaskFormSheet(model: model)
        } else {
            EmptyView()
        }
    }
}
