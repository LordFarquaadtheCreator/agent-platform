import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppShellModel

    var body: some View {
        if let model = appState.workspace?.settingsModel {
            SettingsSheetView(model: model)
        } else {
            EmptyView()
        }
    }
}
