import SwiftUI

struct ApprovalsScreen: View {
    @EnvironmentObject private var appState: AppShellModel
    @ObservedObject var viewModel: ApprovalsViewModel

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
                        .disabled(!viewModel.canApproveOrReject)

                        Button("Reject") {
                            viewModel.showRejectDialog = true
                        }
                        .appButtonStyle(.borderedDestructive)
                        .disabled(!viewModel.canApproveOrReject)
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
                List(viewModel.approvals, selection: $viewModel.selectedItems) { item in
                    AppListRow {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            AppText(item.contentTitle, style: .headline)
                            HStack(spacing: AppTheme.Spacing.small) {
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
        .alert("Reject Selected", isPresented: $viewModel.showRejectDialog) {
            // Alert title serves as the field label
            // swiftlint:disable:next unlabeled_input_field
            TextField("Reason", text: $viewModel.rejectReason)
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
            try await viewModel.approveSelected()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func rejectSelected() async {
        do {
            try await viewModel.rejectSelected()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}
