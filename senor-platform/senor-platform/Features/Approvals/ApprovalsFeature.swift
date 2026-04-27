import SwiftUI

struct ApprovalsScreen: View {
    @EnvironmentObject private var appState: AppShellModel
    @ObservedObject var viewModel: ApprovalsViewModel
    @State private var selectedItems = Set<String>()
    @State private var rejectReason = ""
    @State private var showRejectDialog = false

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                title: "Approvals",
                detail: "\(viewModel.approvals.count) awaiting review",
                action: AnyView(
                    HStack {
                        Button("Approve All") {
                            Task { await approveSelected() }
                        }
                        .appButtonStyle(.borderedProminent)
                        .disabled(selectedItems.isEmpty)

                        Button("Reject") {
                            showRejectDialog = true
                        }
                        .appButtonStyle(.borderedDestructive)
                        .disabled(selectedItems.isEmpty)
                    }
                )
            )
            .padding(AppTheme.Spacing.screenPadding)

            AppDivider()

            if viewModel.approvals.isEmpty {
                Spacer()
                AppEmptyState(
                    title: "Queue Clear",
                    systemImage: AppTheme.Icon.approval,
                    message: "There is nothing pending approval right now."
                )
                Spacer()
            } else {
                List(viewModel.approvals, selection: $selectedItems) { item in
                    AppListRow {
                        AppVStack(spacing: .small, alignment: .leading) {
                            AppText(item.contentTitle, style: .headline)
                            AppHStack(spacing: .small) {
                                AppText(item.agentName, style: .caption, color: AppTheme.ColorToken.textSecondary)
                                AppText("•", style: .caption, color: AppTheme.ColorToken.textSecondary)
                                AppText(
                                    item.submittedAt.formatted(.relative(presentation: .named)),
                                    style: .caption,
                                    color: AppTheme.ColorToken.textSecondary
                                )
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .alert("Reject Selected", isPresented: $showRejectDialog) {
            TextField("Reason", text: $rejectReason)
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) {
                Task { await rejectSelected() }
            }
        } message: {
            AppText("Add an optional reason for this batch rejection.", style: .body)
        }
    }

    private func approveSelected() async {
        do {
            for id in selectedItems {
                try await viewModel.approve(contentId: id)
            }
            selectedItems.removeAll()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func rejectSelected() async {
        do {
            for id in selectedItems {
                try await viewModel.reject(contentId: id, reason: rejectReason.isEmpty ? nil : rejectReason)
            }
            rejectReason = ""
            selectedItems.removeAll()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Previews

// Note: Preview requires complex dependencies - use WorkspaceView for testing
