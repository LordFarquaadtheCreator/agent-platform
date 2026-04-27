import SwiftUI

struct SettingsScreen: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                AppSectionHeader(
                    title: "Settings",
                    detail: "Manage runtime, integrations, and platform behavior."
                )
                SettingsContent(model: model)
            }
            .appScreenPadding()
        }
    }
}

struct SettingsSheetView: View {
    @EnvironmentObject private var appState: AppShellModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: SettingsModel

    var body: some View {
        NavigationStack {
            ScrollView {
                SettingsContent(model: model)
                    .appScreenPadding()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: AppTheme.Layout.mediumSheetWidth, minHeight: AppTheme.Layout.mediumSheetHeight)
    }
}

private struct SettingsContent: View {
    @EnvironmentObject private var appState: AppShellModel
    @ObservedObject var model: SettingsModel

    var body: some View {
        AppVStack(spacing: .large, alignment: .leading) {
            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("General", style: .headline)
                    Toggle("Launch at Login", isOn: $model.generalSettings.launchAtLogin)
                    Toggle("Show Notifications", isOn: $model.generalSettings.showNotifications)
                    TextField("Log Level", text: $model.generalSettings.logLevel)
                    Button("Save General Settings") {
                        model.saveGeneral()
                    }
                    .appButtonStyle(.borderedProminent)
                }
            }

            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("Task Runtime", style: .headline)
                    TextField("Task Script Path", text: $model.taskScriptPath)
                    Button("Save Script Path") {
                        model.saveTaskScriptPath()
                    }
                    .appButtonStyle(.bordered)
                }
            }

            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("DeviantArt", style: .headline)

                    TextField("Client ID", text: $model.deviantArtSettings.clientId)
                    SecureField("Client Secret", text: Binding(
                        get: { model.deviantArtSettings.clientSecret },
                        set: { model.deviantArtSettings.clientSecret = $0 }
                    ))
                    TextField("Redirect URI", text: $model.deviantArtSettings.redirectURI)
                        .textContentType(.URL)
                        .font(.system(.body, design: .monospaced))

                    if let workspace = appState.workspace {
                        HStack {
                            AppStatusPill(
                                title: workspace.deviantArtModel.isAuthenticated ? "Connected" : "Not Connected",
                                color: workspace.deviantArtModel.isAuthenticated ? AppTheme.ColorToken.statusSuccess : AppTheme.ColorToken.statusWarning
                            )
                            Spacer()
                        }

                        HStack(spacing: AppTheme.Spacing.medium) {
                            Button("Save Credentials") {
                                do {
                                    try model.saveDeviantArt()
                                } catch {
                                    appState.errorMessage = error.localizedDescription
                                }
                            }
                            .appButtonStyle(.bordered)

                            DeviantArtConnectButton(model: workspace.deviantArtModel)
                        }
                    }
                }
            }

            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("Patreon", style: .headline)
                    SecureField("Access Token", text: Binding(
                        get: { model.patreonSettings.accessToken },
                        set: { model.patreonSettings.accessToken = $0 }
                    ))
                    TextField("Campaign ID", text: Binding(
                        get: { model.patreonSettings.campaignId ?? "" },
                        set: { model.patreonSettings.campaignId = $0.isEmpty ? nil : $0 }
                    ))
                    Button("Save Patreon Credentials") {
                        do {
                            try model.savePatreon()
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                    .appButtonStyle(.bordered)
                }
            }

            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("ComfyUI", style: .headline)
                    TextField("Server URL", text: $model.comfyUISettings.serverURL)
                    Stepper("Timeout: \(model.comfyUISettings.timeout)s", value: $model.comfyUISettings.timeout, in: 30...900, step: 30)
                    Button("Save ComfyUI Settings") {
                        model.saveComfyUI()
                    }
                    .appButtonStyle(.bordered)
                }
            }

            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("Danger Zone", style: .headline)
                    Button("Clear All Settings") {
                        Task {
                            do {
                                try await model.clearAll()
                            } catch {
                                appState.errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .appButtonStyle(.borderedDestructive)
                }
            }
        }
    }
}

// MARK: - DeviantArt Connect Button

private struct DeviantArtConnectButton: View {
    @ObservedObject var model: DeviantArtModel

    var body: some View {
        Group {
            if model.isAuthenticated {
                Button("Disconnect") {
                    do {
                        try model.disconnect()
                    } catch {
                        // Error handled by model.errorMessage
                    }
                }
                .appButtonStyle(.borderedDestructive)
            } else {
                Button("Connect") {
                    Task {
                        if let url = await model.startConnection() {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .appButtonStyle(.borderedProminent)
                .disabled(model.isConnecting)
            }
        }
        .alert("DeviantArt Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.clearError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }
}
