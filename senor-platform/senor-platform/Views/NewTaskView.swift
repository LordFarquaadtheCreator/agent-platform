import SwiftUI

struct NewTaskView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        if let viewModel = appState.workspace?.tasksViewModel {
            TaskFormSheet(viewModel: viewModel)
        } else {
            EmptyView()
        }
    }
}
