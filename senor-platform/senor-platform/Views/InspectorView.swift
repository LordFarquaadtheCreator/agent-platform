//
//  InspectorView.swift
//  senor-platform
//

import SwiftUI

struct InspectorView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        Group {
            if let agent = viewModel.selectedAgent {
                AgentInspector(agent: agent)
            } else if let content = viewModel.selectedContentItem {
                ContentInspector(viewModel: viewModel, content: content)
            } else {
                EmptyInspector()
            }
        }
    }
}

struct EmptyInspector: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select an item to view details")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Agent Inspector

struct AgentInspector: View {
    let agent: AgentViewModel
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.name)
                            .font(.title2)
                            .bold()

                        HStack {
                            Image(systemName: agent.status.icon)
                                .foregroundStyle(agent.status.color)
                            Text(agent.status.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        isEditing.toggle()
                    } label: {
                        Image(systemName: "pencil")
                    }
                }

                Divider()

                // Status Section
                GroupBox("Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Current State", value: agent.status.rawValue)
                        if let lastActivity = agent.lastActivity {
                            LabeledContent("Last Activity", value: lastActivity.formatted())
                        }
                        LabeledContent("Active Tasks", value: "\(agent.taskCount)")
                    }
                }

                // Actions
                GroupBox("Actions") {
                    HStack(spacing: 12) {
                        Button("Start") {
                            // Start agent
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Stop") {
                            // Stop agent
                        }
                        .buttonStyle(.bordered)

                        Button("Restart") {
                            // Restart agent
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }

                // Logs Section
                GroupBox("Recent Logs") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No recent activity")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 250)
    }
}

// MARK: - Content Inspector

struct ContentInspector: View {
    @ObservedObject var viewModel: ContentViewModel
    let content: ContentItemViewModel
    @State private var showVersionHistory = false
    @State private var showJSONEditor = false
    @State private var showRejectDialog = false
    @State private var rejectReason = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Preview Image
                ContentThumbnail(url: content.previewImage, size: 200, cornerRadius: 8)

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.title3)
                        .bold()

                    HStack {
                        StatusBadge(status: content.status.rawValue)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("Version \(content.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Details
                GroupBox("Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Created", value: content.createdAt.formatted())
                        LabeledContent("ID", value: content.id.prefix(8))
                    }
                }

                // Actions
                GroupBox("Actions") {
                    VStack(spacing: 8) {
                        Button {
                            showJSONEditor = true
                        } label: {
                            Label("Edit JSON", systemImage: "curlybraces")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            showVersionHistory = true
                        } label: {
                            Label("Version History", systemImage: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.bordered)

                        HStack(spacing: 8) {
                            Button {
                                approveContent()
                            } label: {
                                Label("Approve", systemImage: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(content.status != .pending)

                            Button {
                                showRejectDialog = true
                            } label: {
                                Label("Reject", systemImage: "xmark")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(content.status != .pending)
                        }
                    }
                }

                // Publish Section
                if content.status == .approved {
                    GroupBox("Publish") {
                        VStack(spacing: 8) {
                            Button {
                                publishToDeviantArt()
                            } label: {
                                Label("DeviantArt", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                publishToPatreon()
                            } label: {
                                Label("Patreon", systemImage: "dollarsign.circle")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 250)
        .sheet(isPresented: $showJSONEditor) {
            JSONEditorView(contentId: content.id)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showVersionHistory) {
            VersionHistoryView(contentId: content.id)
                .frame(minWidth: 500, minHeight: 400)
        }
        .alert("Reject Content", isPresented: $showRejectDialog) {
            TextField("Reason (optional)", text: $rejectReason)
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) {
                rejectContent()
            }
        } message: {
            Text("Provide a reason for rejection (optional)")
        }
        .disabled(isProcessing)
    }

    private func approveContent() {
        isProcessing = true
        Task {
            do {
                try await viewModel.approveContent(id: content.id)
                isProcessing = false
            } catch {
                isProcessing = false
            }
        }
    }

    private func rejectContent() {
        isProcessing = true
        Task {
            do {
                try await viewModel.rejectContent(id: content.id, reason: rejectReason.isEmpty ? nil : rejectReason)
                rejectReason = ""
                isProcessing = false
            } catch {
                isProcessing = false
            }
        }
    }

    private func publishToDeviantArt() {
        isProcessing = true
        Task {
            do {
                // Resolve PublicationService and publish content
                if let publicationService = await sharedContainer.resolveOptional(PublicationService.self) {
                    _ = try await publicationService.publishToDeviantArt(
                        contentId: content.id,
                        title: content.title,
                        tags: nil,
                        category: nil
                    )
                }
                isProcessing = false
            } catch {
                isProcessing = false
            }
        }
    }

    private func publishToPatreon() {
        isProcessing = true
        Task {
            do {
                // Resolve PublicationService and publish content
                if let publicationService = await sharedContainer.resolveOptional(PublicationService.self) {
                    _ = try await publicationService.publishToPatreon(
                        contentId: content.id,
                        campaignId: nil,
                        tierIds: nil
                    )
                }
                isProcessing = false
            } catch {
                isProcessing = false
            }
        }
    }
}

#Preview("Inspector - Empty") {
    InspectorView(viewModel: ContentViewModel())
}

#Preview("Inspector - Agent Selected") {
    let viewModel = ContentViewModel()
    viewModel.selectedAgentId = "1"
    viewModel.agents = [
        AgentViewModel(id: "1", name: "HAL-9000", status: .running, lastActivity: Date(), taskCount: 5)
    ]
    return InspectorView(viewModel: viewModel)
        .frame(width: 300)
}

#Preview("Inspector - Agent Error State") {
    let viewModel = ContentViewModel()
    viewModel.selectedAgentId = "1"
    viewModel.agents = [
        AgentViewModel(id: "1", name: "Corrupted Agent", status: .error, lastActivity: Date().addingTimeInterval(-7200), taskCount: 0)
    ]
    return InspectorView(viewModel: viewModel)
        .frame(width: 300)
}

#Preview("Inspector - Content Selected") {
    let viewModel = ContentViewModel()
    viewModel.selectedContentId = "1"
    viewModel.contentItems = [
        ContentItemViewModel(id: "1", title: "Amazing Artwork", previewImage: nil, createdAt: Date(), status: .approved, version: 3)
    ]
    return InspectorView(viewModel: viewModel)
        .frame(width: 300)
}

#Preview("Inspector - Dark Mode") {
    InspectorView(viewModel: ContentViewModel())
        .preferredColorScheme(.dark)
        .frame(width: 300)
}
