import SwiftUI

struct NewTaskView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        if let workspace = appState.workspace {
            TaskFormSheet(
                formViewModel: TaskFormViewModel(
                    loadContextUseCase: workspace.dependencies.loadTaskCreationContextUseCase,
                    createTaskUseCase: workspace.dependencies.createTaskUseCase,
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
