//
//  SettingsView.swift
//  senor-platform
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Toggle("Auto-approve Content", isOn: $viewModel.autoApprove)
                    
                    Picker("Default Timezone", selection: $viewModel.timezone) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { tz in
                            Text(tz).tag(tz)
                        }
                    }
                }
                
                Section("ComfyUI") {
                    TextField("Server URL", text: $viewModel.comfyUIServerURL)
                    
                    SecureField("API Key (optional)", text: $viewModel.comfyUIApiKey)
                }
                
                Section("DeviantArt") {
                    DeviantArtSettingsSection(
                        isConnected: $viewModel.deviantArtConnected,
                        onConnect: { viewModel.connectDeviantArt() },
                        onDisconnect: { viewModel.disconnectDeviantArt() }
                    )
                }
                
                Section("Patreon") {
                    PatreonSettingsSection(
                        isConnected: $viewModel.patreonConnected,
                        onConnect: { viewModel.connectPatreon() },
                        onDisconnect: { viewModel.disconnectPatreon() }
                    )
                }
                
                Section("Cache") {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(viewModel.cacheSize)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Clear Cache") {
                        Task {
                            await viewModel.clearCache()
                        }
                    }
                    .disabled(viewModel.isClearingCache)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await viewModel.save()
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.load()
            }
        }
        .frame(minWidth: 500, minHeight: 500)
    }
}

struct DeviantArtSettingsSection: View {
    @Binding var isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isConnected ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(isConnected ? .green : .red)
                Text(isConnected ? "Connected" : "Not Connected")
                    .foregroundStyle(isConnected ? .green : .secondary)
                Spacer()
            }
            
            if isConnected {
                Button("Disconnect", role: .destructive, action: onDisconnect)
                    .buttonStyle(.bordered)
            } else {
                Button("Connect to DeviantArt") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct PatreonSettingsSection: View {
    @Binding var isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isConnected ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(isConnected ? .green : .red)
                Text(isConnected ? "Connected" : "Not Connected")
                    .foregroundStyle(isConnected ? .green : .secondary)
                Spacer()
            }
            
            if isConnected {
                Button("Disconnect", role: .destructive, action: onDisconnect)
                    .buttonStyle(.bordered)
            } else {
                Button("Connect to Patreon") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var autoApprove = false
    @Published var timezone = TimeZone.current.identifier
    @Published var comfyUIServerURL = "http://127.0.0.1:8188"
    @Published var comfyUIApiKey = ""
    @Published var deviantArtConnected = false
    @Published var patreonConnected = false
    @Published var cacheSize = "0 MB"
    @Published var isClearingCache = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let settingsService = SettingsService()
    
    func load() async {
        autoApprove = settingsService.autoApprove
        timezone = settingsService.defaultTimezone
        comfyUIServerURL = settingsService.comfyUIServerURL
        comfyUIApiKey = settingsService.comfyUIApiKey ?? ""
        deviantArtConnected = settingsService.deviantArtAccessToken != nil
        patreonConnected = settingsService.patreonAccessToken != nil
        
        await updateCacheSize()
    }
    
    func save() async {
        settingsService.autoApprove = autoApprove
        settingsService.defaultTimezone = timezone
        settingsService.comfyUIServerURL = comfyUIServerURL
        settingsService.comfyUIApiKey = comfyUIApiKey.isEmpty ? nil : comfyUIApiKey
    }
    
    func connectDeviantArt() {
        // OAuth flow would be initiated here
        errorMessage = "OAuth flow not yet implemented"
        showError = true
    }
    
    func disconnectDeviantArt() {
        settingsService.deviantArtAccessToken = nil
        settingsService.deviantArtRefreshToken = nil
        deviantArtConnected = false
    }
    
    func connectPatreon() {
        // OAuth flow would be initiated here
        errorMessage = "OAuth flow not yet implemented"
        showError = true
    }
    
    func disconnectPatreon() {
        settingsService.patreonAccessToken = nil
        settingsService.patreonRefreshToken = nil
        patreonConnected = false
    }
    
    func updateCacheSize() async {
        let cacheService = sharedContainer.resolveOrCrash(CacheService.self)
        let stats = await cacheService.getCacheStats()
        let mb = Double(stats.totalSize) / 1024.0 / 1024.0
        cacheSize = String(format: "%.1f MB", mb)
    }
    
    func clearCache() async {
        isClearingCache = true
        defer { isClearingCache = false }
        
        do {
            let cacheService = sharedContainer.resolveOrCrash(CacheService.self)
            try await cacheService.invalidateAll(forPlatform: nil)
            await updateCacheSize()
        } catch {
            errorMessage = "Failed to clear cache: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    SettingsView()
}
