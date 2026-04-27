import SwiftUI

struct TasksContentProvider: MainContentProvider {
    let section: AppSection = .tasks
    func content(using workspace: WorkspaceModel, router: AppRouter, appState: AppShellModel) -> AnyView {
        AnyView(TasksScreen(viewModel: workspace.tasksViewModel) {
            appState.present(.newTask)
        })
    }
}
