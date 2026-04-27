import SwiftUI

struct PatreonMemberDetailPanel: View {
    let member: PatreonMember

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    AppText(member.attributes?.fullName ?? "Patron", style: .title2)

                    if let status = member.attributes?.patronStatus {
                        AppStatusPill(
                            title: status,
                            color: statusColor(for: status)
                        )
                    }
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    if let email = member.attributes?.email {
                        LabeledContent("Email", value: email)
                    }

                    if let lifetime = member.attributes?.lifetimeSupportCents {
                        LabeledContent("Lifetime Support", value: PatreonFormatters.formatCents(lifetime))
                    }

                    if let currentlyEntitled = member.attributes?.currentlyEntitledAmountCents {
                        LabeledContent("Current Pledge", value: PatreonFormatters.formatCents(currentlyEntitled))
                    }

                    if let lastChargeStatus = member.attributes?.lastChargeStatus {
                        LabeledContent("Last Charge", value: lastChargeStatus)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(AppTheme.ColorToken.chromeBackground)
    }

    private func statusColor(for status: String) -> Color {
        PatreonFormatters.statusColor(for: status)
    }
}
