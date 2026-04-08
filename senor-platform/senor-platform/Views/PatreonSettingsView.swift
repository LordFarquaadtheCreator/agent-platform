//
//  PatreonSettingsView.swift
//  senor-platform
//

import SwiftUI

struct PatreonSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PatreonSettingsViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.isConnected {
                    connectedView
                } else {
                    connectView
                }
            }
            .padding()
            .navigationTitle("Patreon Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.checkConnection()
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private var connectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("Connected to Patreon")
                .font(.headline)
            
            if let campaignName = viewModel.campaignName {
                Text(campaignName)
                    .foregroundStyle(.secondary)
            }
            
            Button("Disconnect", role: .destructive) {
                Task {
                    await viewModel.disconnect()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var connectView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Connect to Patreon")
                .font(.headline)
            
            Text("Link your Patreon creator account to publish posts directly.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            if viewModel.isConnecting {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                Button("Connect Account") {
                    Task {
                        await viewModel.connect()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

@MainActor
class PatreonSettingsViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var campaignName: String?
    @Published var isConnecting = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let settingsService = SettingsService()
    
    func checkConnection() async {
        isConnected = settingsService.patreonAccessToken != nil
        
        if isConnected {
            // Could fetch campaign info here
        }
    }
    
    func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        
        // OAuth flow would be implemented here
        // For now, just show a placeholder error
        errorMessage = "OAuth integration not fully implemented. Use Settings tab for now."
        showError = true
    }
    
    func disconnect() async {
        settingsService.patreonAccessToken = nil
        settingsService.patreonRefreshToken = nil
        isConnected = false
        campaignName = nil
    }
}

#Preview {
    PatreonSettingsView()
}
