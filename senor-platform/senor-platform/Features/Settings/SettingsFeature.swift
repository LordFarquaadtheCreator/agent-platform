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
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            AppCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    AppText("General", style: .headline)
                    Toggle("Launch at Login", isOn: $viewModel.generalSettings.launchAtLogin)
                    Toggle("Show Notifications", isOn: $viewModel.generalSettings.showNotifications)
                    AppInputField(
                        title: "Log Level",
                        placeholder: "info, debug, warning, error",
                        text: $viewModel.generalSettings.logLevel
                    )
                    Button("Save General Settings") {
                        viewModel.saveGeneral()
                    }
                    .appButtonStyle(.borderedProminent)
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    AppText("Task Runtime", style: .headline)
                    AppInputField(
                        title: "Task Script Path",
                        placeholder: "/usr/local/bin/senor-task",
                        text: $viewModel.taskScriptPath
                    )
                    Button("Save Script Path") {
                        viewModel.saveTaskScriptPath()
                    }
                    .appButtonStyle(.bordered)
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    AppText("DeviantArt", style: .headline)

                    AppInputField(
                        title: "Client ID",
                        placeholder: "Enter DeviantArt Client ID",
                        text: $viewModel.deviantArtSettings.clientId
                    )
                    AppInputField(
                        title: "Client Secret",
                        placeholder: "Enter DeviantArt Client Secret",
                        text: Binding(
                            get: { viewModel.deviantArtSettings.clientSecret },
                            set: { viewModel.deviantArtSettings.clientSecret = $0 }
                        ),
                        isSecure: true
                    )
                    AppInputField(
                        title: "Redirect URI",
                        placeholder: "senorplatform://oauth/deviantart",
                        text: $viewModel.deviantArtSettings.redirectURI
                    )

                    if let workspace = appState.workspace {
                        HStack(spacing: AppTheme.Spacing.medium) {
                            AppStatusPill(
                                title: workspace.deviantArtViewModel.isAuthenticated
                                    ? "Connected"
                                    : "Not Connected",
                                color: workspace.deviantArtViewModel.isAuthenticated
                                    ? AppTheme.ColorToken.statusSuccess
                                    : AppTheme.ColorToken.statusWarning
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
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    AppText("Patreon", style: .headline)

                    if let workspace = appState.workspace {
                        HStack(spacing: AppTheme.Spacing.medium) {
                            AppStatusPill(
                                title: workspace.patreonViewModel.isAuthenticated
                                    ? "Connected"
                                    : "Not Connected",
                                color: workspace.patreonViewModel.isAuthenticated
                                    ? AppTheme.ColorToken.statusSuccess
                                    : AppTheme.ColorToken.statusWarning
                            )
                            Spacer()
                        }
                    }

                    AppInputField(
                        title: "Access Token",
                        placeholder: "Enter Patreon Access Token",
                        text: Binding(
                            get: { viewModel.patreonSettings.accessToken },
                            set: { viewModel.patreonSettings.accessToken = $0 }
                        ),
                        isSecure: true
                    )
                    AppInputField(
                        title: "Refresh Token (optional)",
                        placeholder: "Enter Refresh Token",
                        text: Binding(
                            get: { viewModel.patreonSettings.refreshToken ?? "" },
                            set: { viewModel.patreonSettings.refreshToken = $0.isEmpty ? nil : $0 }
                        ),
                        isSecure: true
                    )
                    AppInputField(
                        title: "Campaign ID (optional)",
                        placeholder: "Enter Campaign ID",
                        text: Binding(
                            get: { viewModel.patreonSettings.campaignId ?? "" },
                            set: { viewModel.patreonSettings.campaignId = $0.isEmpty ? nil : $0 }
                        )
                    )
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
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    AppText("ComfyUI", style: .headline)
                    AppInputField(
                        title: "Server URL",
                        placeholder: "http://127.0.0.1:8188",
                        text: $viewModel.comfyUISettings.serverURL
                    )
                    Stepper(
                        "Timeout: \(viewModel.comfyUISettings.timeout)s",
                        value: $viewModel.comfyUISettings.timeout,
                        in: 30...900,
                        step: 30
                    )
                    Button("Save ComfyUI Settings") {
                        viewModel.saveComfyUI()
                    }
                    .appButtonStyle(.bordered)
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    AppText("AI Chat", style: .headline)
                    AppInputField(
                        title: "LM Studio URL",
                        placeholder: "http://localhost:1234/v1",
                        text: $viewModel.aiSettings.baseURL
                    )
                    AppInputField(
                        title: "Model",
                        placeholder: "model",
                        text: $viewModel.aiSettings.model
                    )
                    AppInputField(
                        title: "Temperature",
                        placeholder: "0.7",
                        text: Binding(
                            get: { String(format: "%.1f", viewModel.aiSettings.temperature) },
                            set: { viewModel.aiSettings.temperature = Double($0) ?? 0.7 }
                        )
                    )
                    Stepper(
                        "Max Tokens: \(viewModel.aiSettings.maxTokens)",
                        value: $viewModel.aiSettings.maxTokens,
                        in: 1024...16384,
                        step: 1024
                    )
                    Toggle("Warm up on launch", isOn: $viewModel.aiSettings.warmupOnLaunch)
                    Button("Save AI Settings") {
                        viewModel.saveAI()
                    }
                    .appButtonStyle(.bordered)
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
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
