//
//  NewAgentView.swift
//  senor-platform
//

import SwiftUI
import Foundation

struct NewAgentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NewAgentViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Agent Details") {
                    TextField("Name", text: $viewModel.name)
                        .autocorrectionDisabled()
                    
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Toggle("Active", isOn: $viewModel.isActive)
                }
                
                Section("Configuration") {
                    TextField("Worker Script Path", text: $viewModel.workerScriptPath)
                    
                    TextEditor(text: $viewModel.configJson)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if viewModel.configJson.isEmpty {
                                Text("Configuration JSON...")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }
            }
            .navigationTitle("New Agent")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    AsyncActionButton("Create") {
                        await viewModel.createAgent()
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

@MainActor
class NewAgentViewModel: ObservableObject {
    @Published var name = ""
    @Published var description = ""
    @Published var isActive = true
    @Published var workerScriptPath = ""
    @Published var configJson = "{}"
    @Published var showError = false
    @Published var errorMessage = ""
    
    var isValid: Bool {
        !name.isEmpty && !workerScriptPath.isEmpty
    }
    
    func createAgent() async {
        do {
            let agent = AgentRecord(
                displayName: name,
                status: isActive ? .idle : .paused,
                nameSource: "manual",
                nameSeed: 0
            )
            
            let repository = await sharedContainer.resolveOrCrash(AgentRepository.self)
            _ = try await repository.create(agent: agent)
            
            await EventBus.shared.refreshAllData()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NewAgentView()
}
