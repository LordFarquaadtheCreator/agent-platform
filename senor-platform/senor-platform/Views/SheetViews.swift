import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        if let viewModel = appState.workspace?.settingsViewModel {
            SettingsSheetView(viewModel: viewModel)
        } else {
            EmptyView()
        }
    }
}
