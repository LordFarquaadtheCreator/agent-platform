import SwiftUI

struct ContentInspectorCard: View {
    @EnvironmentObject private var appState: AppShellModel
    let content: ContentSummary
    @ObservedObject var approvalsViewModel: ApprovalsViewModel
    @State private var rejectReason = ""
    @State private var showRejectDialog = false
    @State private var isProcessing = false

    var body: some View {
        AppCard {
            AppVStack(spacing: .medium, alignment: .leading) {
                AppText(content.title, style: .title3)
                AppStatusPill(
                    title: content.status.title,
                    color: StatusColor.from(content.status.rawValue).swiftUIColor
                )
                AppDivider()
                LabeledContent("Version", value: "\(content.version)")
                LabeledContent("Created", value: content.createdAt.formatted())

                Button("Edit JSON") {
                    appState.present(.editContent(content.id))
                }
                .appButtonStyle(.bordered)

                Button("Version History") {
                    appState.present(.versionHistory(content.id))
                }
                .appButtonStyle(.bordered)

                if content.status == .pending {
                    Button("Approve") {
                        Task { await approve() }
                    }
                    .appButtonStyle(.borderedProminent)
                    .tint(AppTheme.ColorToken.statusSuccess)

                    Button("Reject") {
                        showRejectDialog = true
                    }
                    .appButtonStyle(.borderedDestructive)
                }

                if content.status == .approved {
                    Button("Publish to DeviantArt") {
                        Task { await publish(.deviantArt) }
                    }
                    .appButtonStyle(.borderedProminent)

                    Button("Publish to Patreon") {
                        Task { await publish(.patreon) }
                    }
                    .appButtonStyle(.bordered)
                }
            }
        }
        .disabled(isProcessing)
        .alert("Reject Content", isPresented: $showRejectDialog) {
            TextField("Reason", text: $rejectReason)
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) {
                Task { await reject() }
            }
        } message: {
            AppText("Add an optional reason for rejecting this content.", style: .body)
        }
    }

    private func approve() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await approvalsViewModel.approve(contentId: content.id)
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func reject() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await approvalsViewModel.reject(contentId: content.id, reason: rejectReason.isEmpty ? nil : rejectReason)
            rejectReason = ""
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func publish(_ platform: PublicationPlatform) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await approvalsViewModel.publish(
                PublicationRequest(
                    contentId: content.id,
                    platform: platform,
                    title: content.title,
                    category: nil,
                    isMature: false,
                    tags: nil,
                    campaignId: nil,
                    isPaid: nil,
                    isPublic: nil,
                    tiers: nil
                )
            )
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Previews
// Note: ContentInspectorCard previews require complex dependency setup.
// For now, preview the ContentScreen to see this component in context.
