//
//  DeviantArtSettingsView.swift
//  senor-platform
//

import SwiftUI

struct DeviantArtSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DeviantArtSettingsViewModel()
    
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
            .navigationTitle("DeviantArt Settings")
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
            
            Text("Connected to DeviantArt")
                .font(.headline)
            
            if let username = viewModel.username {
                Text("@\(username)")
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
                .foregroundStyle(.blue)
            
            Text("Connect to DeviantArt")
                .font(.headline)
            
            Text("Link your DeviantArt account to publish content directly to your gallery.")
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
class DeviantArtSettingsViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var username: String?
    @Published var isConnecting = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let settingsService = SettingsService()
    
    func checkConnection() async {
        isConnected = settingsService.deviantArtAccessToken != nil
        
        if isConnected {
            // Could fetch user info here
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
        settingsService.deviantArtAccessToken = nil
        settingsService.deviantArtRefreshToken = nil
        isConnected = false
    }
}

#Preview {
    DeviantArtSettingsView()
}
