//
//  SheetViews.swift
//  senor-platform
//

import SwiftUI
import AppKit

// MARK: - New Agent View

struct NewAgentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: NameCategory = .games
    @State private var useAutoName = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Agent")
                .font(.title)
                .bold()

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Form {
                Toggle("Auto-generate name", isOn: $useAutoName)

                if useAutoName {
                    Picker("Name Category", selection: $selectedCategory) {
                        ForEach(NameCategory.allCases, id: \.self) { category in
                            Text(category.displayName)
                                .tag(category)
                        }
                    }
                }

                Section {
                    Text("The agent will be created with a unique pop-culture inspired name. You can modify settings after creation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 400)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createAgent()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
        .disabled(isCreating)
        .overlay {
            if isCreating {
                ProgressView("Creating...")
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func createAgent() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                // Emit event to create agent through EventBus
                EventBus.shared.createAgent(name: nil)

                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - New Task View

struct NewTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var taskName = ""
    @State private var taskTypeId = ""
    @State private var selectedAgentId = ""
    @State private var goScriptPath = ""
    @State private var taskMetadata = "{}"

    // Schedule state
    @State private var scheduleKind: ScheduleKind = .oneTime
    @State private var oneTimeDate = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var dailyTime = Date()
    @State private var selectedWeekdays: Set<ScheduleSpec.Weekday> = [.monday]
    @State private var selectedMonthDays: Set<Int> = [1]
    @State private var timezone = TimeZone.current.identifier

    @State private var availableAgents: [AgentRecord] = []
    @State private var availableTaskTypes: [TaskTypeRecord] = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showValidationError = false

    enum ScheduleKind: String, CaseIterable {
        case oneTime = "One Time"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Create New Task")
                .font(.title)
                .bold()
                .padding()

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Form {
                Section("Basic Info") {
                    TextField("Task Name", text: $taskName)

                    Picker("Agent", selection: $selectedAgentId) {
                        Text("Select Agent...").tag("")
                        ForEach(availableAgents, id: \.id) { agent in
                            Text(agent.displayName).tag(agent.id)
                        }
                    }

                    Picker("Task Type", selection: $taskTypeId) {
                        Text("Select Type...").tag("")
                        ForEach(availableTaskTypes, id: \.id) { type in
                            Text(type.name).tag(type.id)
                        }
                    }
                }

                Section("Schedule") {
                    Picker("Schedule Type", selection: $scheduleKind) {
                        ForEach(ScheduleKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }

                    switch scheduleKind {
                    case .oneTime:
                        DatePicker("Run At", selection: $oneTimeDate, in: Date()...)
                    case .daily:
                        DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                    case .weekly:
                        DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                        VStack(alignment: .leading) {
                            Text("Days:")
                                .font(.caption)
                            HStack {
                                ForEach(ScheduleSpec.Weekday.allCases, id: \.self) { day in
                                    Toggle(day.shortName, isOn: Binding(
                                        get: { selectedWeekdays.contains(day) },
                                        set: { isOn in
                                            if isOn {
                                                selectedWeekdays.insert(day)
                                            } else {
                                                selectedWeekdays.remove(day)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.button)
                                    .font(.caption)
                                }
                            }
                        }
                    case .monthly:
                        DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                        Stepper("Day of month: \(selectedMonthDays.sorted().map(String.init).joined(separator: ", "))", value: .constant(selectedMonthDays.count), in: 1...31)
                    }
                }

                Section("Script") {
                    TextField("Go Script Path", text: $goScriptPath)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Configuration (JSON)") {
                    TextEditor(text: $taskMetadata)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)

                    HStack {
                        Button("Format JSON") {
                            formatJSON()
                        }
                        .buttonStyle(.bordered)

                        Button("Validate") {
                            validateJSON()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createTask()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isCreating)
            }
            .padding()
        }
        .frame(width: 600, height: 600)
        .disabled(isCreating)
        .overlay {
            if isCreating {
                ProgressView("Creating...")
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .task {
            await loadData()
        }
        .alert("Validation Error", isPresented: $showValidationError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Invalid input")
        }
    }

    private var isValid: Bool {
        !taskName.isEmpty &&
        !selectedAgentId.isEmpty &&
        !taskTypeId.isEmpty &&
        !goScriptPath.isEmpty &&
        isValidJSON(taskMetadata)
    }

    private func loadData() async {
        let container = sharedContainer
        let agentRepo = container.resolveOrCrash(AgentRepository.self)
        let taskTypeRepo = container.resolveOrCrash(TaskTypeRepository.self)

        do {
            let agents = try await agentRepo.listAll()
            let types = try await taskTypeRepo.listAll()

            await MainActor.run {
                self.availableAgents = agents
                self.availableTaskTypes = types
            }
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
    }

    private func formatJSON() {
        guard let data = taskMetadata.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formattedData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let formatted = String(data: formattedData, encoding: .utf8) else {
            return
        }
        taskMetadata = formatted
    }

    private func validateJSON() {
        if isValidJSON(taskMetadata) {
            errorMessage = "JSON is valid!"
        } else {
            errorMessage = "Invalid JSON syntax"
            showValidationError = true
        }
    }

    private func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return false
        }
        return true
    }

    private func createTask() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                // Build schedule spec
                let scheduleSpec: ScheduleSpec
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: dailyTime)
                let scheduleTime = ScheduleSpec.ScheduleTime(
                    hour: timeComponents.hour ?? 9,
                    minute: timeComponents.minute ?? 0
                )

                switch scheduleKind {
                case .oneTime:
                    scheduleSpec = .oneTime(date: oneTimeDate)
                case .daily:
                    scheduleSpec = .daily(time: scheduleTime, timezone: timezone)
                case .weekly:
                    let days = Array(selectedWeekdays).sorted { $0.rawValue < $1.rawValue }
                    scheduleSpec = .weekly(time: scheduleTime, days: days, timezone: timezone)
                case .monthly:
                    let days = Array(selectedMonthDays).sorted()
                    scheduleSpec = .monthly(time: scheduleTime, days: days, timezone: timezone)
                }

                // Get next run time
                let compiler = ScheduleCompiler()
                let nextRunAt = compiler.nextRunTime(from: scheduleSpec, after: Date())

                // Create task
                let task = TaskRecord(
                    agentId: selectedAgentId,
                    taskTypeId: taskTypeId,
                    taskName: taskName,
                    taskMetadataJson: taskMetadata,
                    goScriptPath: goScriptPath
                )

                let container = sharedContainer
                let taskRepo = container.resolveOrCrash(TaskRepository.self)
                let savedTask = try await taskRepo.create(task: task)

                // Create schedule
                let coder = ScheduleSpecCoder()
                let schedulePayload = coder.encode(scheduleSpec)
                let cronExpression = compiler.compileToCron(scheduleSpec)

                let schedule = TaskScheduleRecord(
                    taskId: savedTask.id,
                    scheduleKind: scheduleKind == .oneTime ? "one_time" : "recurring",
                    schedulePayloadJson: schedulePayload,
                    cronExpression: cronExpression,
                    timezone: timezone,
                    nextRunAt: nextRunAt
                )

                let scheduleRepo = container.resolveOrCrash(TaskScheduleRepository.self)
                _ = try await scheduleRepo.create(schedule: schedule)

                await MainActor.run {
                    isCreating = false
                    // Emit event to refresh
                    EventBus.shared.refreshAllData()
                }

            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

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

    private let settingsService = sharedContainer.resolveOrCrash(SettingsService.self)

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
            loadSettings()
        }
    }

    private func loadSettings() {
        let settings = settingsService.loadGeneralSettings()
        launchAtLogin = settings.launchAtLogin
        showNotifications = settings.showNotifications
        logLevel = settings.logLevel
    }

    private func saveSettings() {
        let settings = SettingsService.GeneralSettings(
            launchAtLogin: launchAtLogin,
            showNotifications: showNotifications,
            logLevel: logLevel
        )
        settingsService.saveGeneralSettings(settings)
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

    private let settingsService = sharedContainer.resolveOrCrash(SettingsService.self)
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
    }

    private func loadSettings() {
        let settings = settingsService.loadGeneralSettings()
        logLevel = settings.logLevel
    }

    private func updateLogLevel() {
        var settings = settingsService.loadGeneralSettings()
        settings = SettingsService.GeneralSettings(
            launchAtLogin: settings.launchAtLogin,
            showNotifications: settings.showNotifications,
            logLevel: logLevel
        )
        settingsService.saveGeneralSettings(settings)
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
        settingsService.clearAllSettings()
        // Reset to defaults
        logLevel = "info"
        enableDebugMode = false
        logger.info("All settings reset to defaults")
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

    private let settingsService = sharedContainer.resolveOrCrash(SettingsService.self)

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
            loadSettings()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func loadSettings() {
        let settings = settingsService.loadDeviantArtSettings()
        clientId = settings.clientId
        clientSecret = settings.clientSecret
        isAuthenticated = settings.isAuthenticated
    }

    private func saveCredentials() {
        let settings = SettingsService.DeviantArtSettings(
            clientId: clientId,
            clientSecret: clientSecret,
            accessToken: nil,
            refreshToken: nil,
            tokenExpiry: nil
        )
        settingsService.saveDeviantArtSettings(settings)
        // Note: Actual OAuth flow would be implemented here
        errorMessage = "Credentials saved. OAuth flow not yet implemented."
        showError = true
    }

    private func disconnect() {
        let settings = SettingsService.DeviantArtSettings(
            clientId: clientId,
            clientSecret: clientSecret,
            accessToken: nil,
            refreshToken: nil,
            tokenExpiry: nil
        )
        settingsService.saveDeviantArtSettings(settings)
        isAuthenticated = false
    }
}

struct PatreonSettingsView: View {
    @State private var creatorAccessToken = ""
    @State private var campaignId = ""
    @State private var isAuthenticated = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let settingsService = sharedContainer.resolveOrCrash(SettingsService.self)

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
            loadSettings()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func loadSettings() {
        let settings = settingsService.loadPatreonSettings()
        creatorAccessToken = settings.accessToken
        campaignId = settings.campaignId ?? ""
        isAuthenticated = settings.isAuthenticated
    }

    private func saveCredentials() {
        let settings = SettingsService.PatreonSettings(
            accessToken: creatorAccessToken,
            campaignId: campaignId.isEmpty ? nil : campaignId,
            tokenExpiry: nil
        )
        settingsService.savePatreonSettings(settings)
        isAuthenticated = true
    }

    private func disconnect() {
        let settings = SettingsService.PatreonSettings(
            accessToken: "",
            campaignId: nil,
            tokenExpiry: nil
        )
        settingsService.savePatreonSettings(settings)
        creatorAccessToken = ""
        campaignId = ""
        isAuthenticated = false
    }
}

struct ComfyUISettingsView: View {
    @State private var serverURL = "http://127.0.0.1:8188"
    @State private var timeout = 300

    private let settingsService = sharedContainer.resolveOrCrash(SettingsService.self)

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
            loadSettings()
        }
    }

    private func loadSettings() {
        let settings = settingsService.loadComfyUISettings()
        serverURL = settings.serverURL
        timeout = settings.timeout
    }

    private func saveSettings() {
        let settings = SettingsService.ComfyUISettings(
            serverURL: serverURL,
            timeout: timeout
        )
        settingsService.saveComfyUISettings(settings)
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
