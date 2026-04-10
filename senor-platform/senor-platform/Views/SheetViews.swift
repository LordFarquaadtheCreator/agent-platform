//
//  SheetViews.swift
//  senor-platform
//

import SwiftUI
import AppKit

// Note: NewAgentView and NewTaskView are now in their own dedicated files:
// - Views/NewAgentView.swift
// - Views/NewTaskView.swift

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(.title)
                .bold()
                .padding()

            TabView {
                GeneralSettingsTab()
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }

                DatabaseSettingsTab()
                    .tabItem {
                        Label("Database", systemImage: "externaldrive")
                    }

                IntegrationSettingsTab()
                    .tabItem {
                        Label("Integrations", systemImage: "link")
                    }

                AdvancedSettingsTab()
                    .tabItem {
                        Label("Advanced", systemImage: "gearshape.2")
                    }
            }
            .padding()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 700, height: 500)
    }
}

struct GeneralSettingsTab: View {
    @State private var launchAtLogin = false
    @State private var showNotifications = true
    @State private var theme = "system"
    @State private var logLevel = "info"

    @State private var settingsService: SettingsService?

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, _ in saveSettings() }

            Toggle("Show Notifications", isOn: $showNotifications)
                .onChange(of: showNotifications) { _, _ in saveSettings() }

            Picker("Appearance", selection: $theme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }

            Picker("Log Level", selection: $logLevel) {
                Text("Debug").tag("debug")
                Text("Info").tag("info")
                Text("Warning").tag("warning")
                Text("Error").tag("error")
            }
            .onChange(of: logLevel) { _, _ in saveSettings() }
        }
        .formStyle(.grouped)
        .onAppear {
            Task {
                settingsService = await sharedContainer.resolve(SettingsService.self)
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        guard let service = settingsService else { return }
        let settings = service.loadGeneralSettings()
        launchAtLogin = settings.launchAtLogin
        showNotifications = settings.showNotifications
        logLevel = settings.logLevel
    }

    private func saveSettings() {
        guard let service = settingsService else { return }
        let settings = SettingsService.GeneralSettings(
            launchAtLogin: launchAtLogin,
            showNotifications: showNotifications,
            logLevel: logLevel
        )
        service.saveGeneralSettings(settings)
    }
}

struct DatabaseSettingsTab: View {
    @State private var autoCleanup = true
    @State private var retentionDays = 30

    var body: some View {
        Form {
            Section("Storage Management") {
                Toggle("Auto-cleanup old records", isOn: $autoCleanup)

                if autoCleanup {
                    Stepper("Keep records for \(retentionDays) days", value: $retentionDays, in: 7...365)
                }

                LabeledContent("Database Size", value: "-- MB")
                LabeledContent("Cache Size", value: "-- MB")

                HStack {
                    Button("Clear Cache") {}
                    Button("Optimize Database") {}
                    Button("Export Data...") {}
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct IntegrationSettingsTab: View {
    var body: some View {
        Form {
            Section("Connected Services") {
                NavigationLink {
                    DeviantArtSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("DeviantArt")
                        Spacer()
                        Text("Not Connected")
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    PatreonSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                        Text("Patreon")
                        Spacer()
                        Text("Not Connected")
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    ComfyUISettingsView()
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("ComfyUI")
                        Spacer()
                        Text("Not Configured")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AdvancedSettingsTab: View {
    @State private var logLevel = "info"
    @State private var enableDebugMode = false
    @State private var showResetConfirmation = false
    @State private var showClearDataConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    @State private var settingsService: SettingsService?
    private let logger = AppLogger.ui

    var body: some View {
        Form {
            Section("Logging") {
                Picker("Log Level", selection: $logLevel) {
                    Text("Debug").tag("debug")
                    Text("Info").tag("info")
                    Text("Warning").tag("warning")
                    Text("Error").tag("error")
                }
                .onChange(of: logLevel) { _, _ in updateLogLevel() }

                Toggle("Debug Mode", isOn: $enableDebugMode)

                Button("Open Logs Folder") {
                    openLogsFolder()
                }

                Button("Clear All Logs") {
                    clearLogs()
                }
                .foregroundStyle(.orange)
            }

            Section("Danger Zone") {
                Button("Reset All Settings") {
                    showResetConfirmation = true
                }
                .foregroundStyle(.red)

                Button("Clear All Data") {
                    showClearDataConfirmation = true
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadSettings()
        }
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to defaults. This action cannot be undone.")
        }
        .alert("Clear All Data?", isPresented: $showClearDataConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will delete all agents, tasks, content, and history. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            Task {
                settingsService = await sharedContainer.resolve(SettingsService.self)
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        guard let service = settingsService else { return }
        let settings = service.loadGeneralSettings()
        logLevel = settings.logLevel
    }

    private func updateLogLevel() {
        guard let service = settingsService else { return }
        var settings = service.loadGeneralSettings()
        settings = SettingsService.GeneralSettings(
            launchAtLogin: settings.launchAtLogin,
            showNotifications: settings.showNotifications,
            logLevel: logLevel
        )
        service.saveGeneralSettings(settings)
    }

    private func openLogsFolder() {
        let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let logsURL = appSupport?.appendingPathComponent("SenorPlatform/logs", isDirectory: true)

        if let url = logsURL {
            NSWorkspace.shared.open(url)
        }
    }

    private func clearLogs() {
        // Implementation would clear log files
        logger.info("Clear logs requested")
    }

    private func resetAllSettings() {
        Task {
            guard let service = settingsService else { return }
            await service.clearAllSettings()
            // Reset to defaults
            await MainActor.run {
                logLevel = "info"
                enableDebugMode = false
            }
            logger.info("All settings reset to defaults")
        }
    }

    private func clearAllData() {
        // This would require access to DatabaseManager to clear tables
        // For now, just log it
        logger.warning("Clear all data requested - requires DatabaseManager implementation")
        errorMessage = "Database clearing not yet implemented"
        showError = true
    }
}

// MARK: - Integration Settings Views

struct DeviantArtSettingsView: View {
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var isAuthenticated = false
    @State private var showError = false
    @State private var errorMessage = ""

    @State private var settingsService: SettingsService?

    var body: some View {
        Form {
            Section("Authentication") {
                if isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Disconnect") {
                            disconnect()
                        }
                    }
                } else {
                    TextField("Client ID", text: $clientId)
                    SecureField("Client Secret", text: $clientSecret)

                    Button("Save Credentials") {
                        saveCredentials()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(clientId.isEmpty || clientSecret.isEmpty)
                }
            }

            Section("Default Settings") {
                Toggle("Allow Comments", isOn: .constant(true))
                Toggle("Allow Download", isOn: .constant(false))
                Toggle("Auto-submit to Groups", isOn: .constant(false))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("DeviantArt Settings")
        .onAppear {
            Task {
                settingsService = await sharedContainer.resolve(SettingsService.self)
                loadSettings()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func loadSettings() {
        guard let service = settingsService else { return }
        let settings = service.loadDeviantArtSettings()
        clientId = settings.clientId
        clientSecret = settings.clientSecret
        isAuthenticated = settings.isAuthenticated
    }

    private func saveCredentials() {
        guard let service = settingsService else { return }
        let settings = SettingsService.DeviantArtSettings(
            clientId: clientId,
            clientSecret: clientSecret,
            accessToken: nil,
            refreshToken: nil,
            tokenExpiry: nil
        )
        service.saveDeviantArtSettings(settings)
        // Note: Actual OAuth flow would be implemented here
        errorMessage = "Credentials saved. OAuth flow not yet implemented."
        showError = true
    }

    private func disconnect() {
        guard let service = settingsService else { return }
        let settings = SettingsService.DeviantArtSettings(
            clientId: clientId,
            clientSecret: clientSecret,
            accessToken: nil,
            refreshToken: nil,
            tokenExpiry: nil
        )
        service.saveDeviantArtSettings(settings)
        isAuthenticated = false
    }
}

struct PatreonSettingsView: View {
    @State private var creatorAccessToken = ""
    @State private var campaignId = ""
    @State private var isAuthenticated = false
    @State private var showError = false
    @State private var errorMessage = ""

    @State private var settingsService: SettingsService?

    var body: some View {
        Form {
            Section("Authentication") {
                if isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Disconnect") {
                            disconnect()
                        }
                    }
                } else {
                    SecureField("Creator Access Token", text: $creatorAccessToken)
                    TextField("Campaign ID (Optional)", text: $campaignId)

                    Button("Save Credentials") {
                        saveCredentials()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(creatorAccessToken.isEmpty)
                }
            }

            Section("Default Settings") {
                Toggle("Default to Paid Posts", isOn: .constant(true))
                Toggle("Public Preview", isOn: .constant(false))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Patreon Settings")
        .onAppear {
            Task {
                settingsService = await sharedContainer.resolve(SettingsService.self)
                loadSettings()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func loadSettings() {
        guard let service = settingsService else { return }
        let settings = service.loadPatreonSettings()
        creatorAccessToken = settings.accessToken
        campaignId = settings.campaignId ?? ""
        isAuthenticated = settings.isAuthenticated
    }

    private func saveCredentials() {
        guard let service = settingsService else { return }
        let settings = SettingsService.PatreonSettings(
            accessToken: creatorAccessToken,
            campaignId: campaignId.isEmpty ? nil : campaignId,
            tokenExpiry: nil
        )
        service.savePatreonSettings(settings)
        isAuthenticated = true
    }

    private func disconnect() {
        guard let service = settingsService else { return }
        let settings = SettingsService.PatreonSettings(
            accessToken: "",
            campaignId: nil,
            tokenExpiry: nil
        )
        service.savePatreonSettings(settings)
        creatorAccessToken = ""
        campaignId = ""
        isAuthenticated = false
    }
}

struct ComfyUISettingsView: View {
    @State private var serverURL = "http://127.0.0.1:8188"
    @State private var timeout = 300

    @State private var settingsService: SettingsService?

    var body: some View {
        Form {
            Section("Server Configuration") {
                TextField("Server URL", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                Stepper("Timeout: \(timeout) seconds", value: $timeout, in: 60...600)

                Button("Test Connection") {}
                    .buttonStyle(.bordered)

                Button("Save Settings") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Workflows") {
                Button("Manage Workflows...") {}
                Button("Open Workflow Folder") {}
            }
        }
        .formStyle(.grouped)
        .navigationTitle("ComfyUI Settings")
        .onAppear {
            Task {
                settingsService = await sharedContainer.resolve(SettingsService.self)
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        guard let service = settingsService else { return }
        let settings = service.loadComfyUISettings()
        serverURL = settings.serverURL
        timeout = settings.timeout
    }

    private func saveSettings() {
        guard let service = settingsService else { return }
        let settings = SettingsService.ComfyUISettings(
            serverURL: serverURL,
            timeout: timeout
        )
        service.saveComfyUISettings(settings)
    }
}

#Preview("New Agent") {
    NewAgentView()
}

#Preview("New Task") {
    NewTaskView()
}

#Preview("Settings") {
    SettingsView()
}

#Preview("DeviantArt Settings") {
    NavigationStack {
        DeviantArtSettingsView()
    }
}

#Preview("DeviantArt - Connected") {
    DeviantArtSettingsView()
        .onAppear {
            // Simulating connected state would require state manipulation
        }
}

#Preview("Patreon Settings") {
    NavigationStack {
        PatreonSettingsView()
    }
}

#Preview("ComfyUI Settings") {
    NavigationStack {
        ComfyUISettingsView()
    }
}

#Preview("Dark Mode") {
    NewAgentView()
        .preferredColorScheme(.dark)
}
