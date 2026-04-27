import SwiftUI

struct SettingsScreen: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                AppSectionHeader(
                    title: "Settings",
                    detail: "Manage runtime, integrations, and platform behavior."
                )
                SettingsContent(viewModel: viewModel)
            }
            .appScreenPadding()
        }
    }
}

struct SettingsSheetView: View {
    @EnvironmentObject private var appState: AppShellModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                SettingsContent(viewModel: viewModel)
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
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        AppVStack(spacing: .large, alignment: .leading) {
            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("General", style: .headline)
                    Toggle("Launch at Login", isOn: $viewModel.generalSettings.launchAtLogin)
                    Toggle("Show Notifications", isOn: $viewModel.generalSettings.showNotifications)
                    AppText("Log Level", style: .caption)
                    TextField("info, debug, warning, error", text: $viewModel.generalSettings.logLevel)
                    Button("Save General Settings") {
                        viewModel.saveGeneral()
                    }
                    .appButtonStyle(.borderedProminent)
                }
            }

            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("Task Runtime", style: .headline)
                    AppText("Task Script Path", style: .caption)
                    TextField("/usr/local/bin/senor-task", text: $viewModel.taskScriptPath)
                    Button("Save Script Path") {
                        viewModel.saveTaskScriptPath()
                    }
                    .appButtonStyle(.bordered)
                }
            }

            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("DeviantArt", style: .headline)

                    AppText("Client ID", style: .caption)
                    TextField("Enter DeviantArt Client ID", text: $viewModel.deviantArtSettings.clientId)
                    AppText("Client Secret", style: .caption)
                    SecureField("Enter DeviantArt Client Secret", text: Binding(
                        get: { viewModel.deviantArtSettings.clientSecret },
                        set: { viewModel.deviantArtSettings.clientSecret = $0 }
                    ))
                    AppText("Redirect URI", style: .caption)
                    TextField("senorplatform://oauth/deviantart", text: $viewModel.deviantArtSettings.redirectURI)
                        .textContentType(.URL)
                        .font(.system(.body, design: .monospaced))

                    if let workspace = appState.workspace {
                        HStack {
                            AppStatusPill(
                                title: workspace.deviantArtViewModel.isAuthenticated ? "Connected" : "Not Connected",
                                color: workspace.deviantArtViewModel.isAuthenticated ? AppTheme.ColorToken.statusSuccess : AppTheme.ColorToken.statusWarning
                            )
                            Spacer()
                        }

                        HStack(spacing: AppTheme.Spacing.medium) {
                            Button("Save Credentials") {
                                do {
                                    try viewModel.saveDeviantArt()
                                } catch {
                                    appState.errorMessage = error.localizedDescription
                                }
                            }
                            .appButtonStyle(.bordered)

                            DeviantArtConnectButton(viewModel: workspace.deviantArtViewModel)
                        }
                    }
                }
            }

            AppCard {
                AppVStack(spacing: .medium, alignment: .leading) {
                    AppText("Patreon", style: .headline)

                    if let workspace = appState.workspace {
                        HStack {
                            AppStatusPill(
                                title: workspace.patreonViewModel.isAuthenticated ? "Connected" : "Not Connected",
                                color: workspace.patreonViewModel.isAuthenticated ? AppTheme.ColorToken.statusSuccess : AppTheme.ColorToken.statusWarning
                            )
                            Spacer()
                        }
                    }

                    AppText("Access Token", style: .caption)
                    SecureField("Enter Patreon Access Token", text: Binding(
                        get: { viewModel.patreonSettings.accessToken },
                        set: { viewModel.patreonSettings.accessToken = $0 }
                    ))
                    AppText("Refresh Token (optional)", style: .caption)
                    SecureField("Enter Refresh Token", text: Binding(
                        get: { viewModel.patreonSettings.refreshToken ?? "" },
                        set: { viewModel.patreonSettings.refreshToken = $0.isEmpty ? nil : $0 }
                    ))
                    AppText("Campaign ID (optional)", style: .caption)
                    TextField("Enter Campaign ID", text: Binding(
                        get: { viewModel.patreonSettings.campaignId ?? "" },
                        set: { viewModel.patreonSettings.campaignId = $0.isEmpty ? nil : $0 }
                    ))
                    Button("Save Patreon Credentials") {
                        do {
                            try viewModel.savePatreon()
                            appState.workspace?.patreonViewModel.reloadWithNewSettings()
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
                    AppText("Server URL", style: .caption)
                    TextField("http://127.0.0.1:8188", text: $viewModel.comfyUISettings.serverURL)
                    Stepper("Timeout: \(viewModel.comfyUISettings.timeout)s", value: $viewModel.comfyUISettings.timeout, in: 30...900, step: 30)
                    Button("Save ComfyUI Settings") {
                        viewModel.saveComfyUI()
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
                                try await viewModel.clearAll()
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
    @EnvironmentObject private var appState: AppShellModel
    @ObservedObject var viewModel: DeviantArtViewModel

    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                Button("Disconnect") {
                    do {
                        try viewModel.disconnect()
                    } catch {
                        // Error handled by viewModel.errorMessage
                    }
                }
                .appButtonStyle(.borderedDestructive)
            } else {
                Button("Connect") {
                    Task {
                        if let url = await viewModel.startConnection() {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.absoluteString, forType: .string)
                            appState.showToast("OAuth URL copied to clipboard")
                        }
                    }
                }
                .appButtonStyle(.borderedProminent)
                .disabled(viewModel.isConnecting)
            }
        }
        .alert("DeviantArt Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

// MARK: - Previews

#Preview {
    SettingsScreen(viewModel: SettingsViewModel(settingsService: SettingsService()))
}
