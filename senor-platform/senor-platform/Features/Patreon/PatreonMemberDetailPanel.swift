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
            .appScreenPadding()
        }
        .background(AppTheme.ColorToken.chromeBackground)
    }

    private func statusColor(for status: String) -> Color {
        PatreonFormatters.statusColor(for: status)
    }
}

// MARK: - Previews

#Preview("Active Patron") {
    PatreonMemberDetailPanel(member: .previewActive)
        .frame(width: 350)
}

#Preview("Declined Patron") {
    PatreonMemberDetailPanel(member: .previewDeclined)
        .frame(width: 350)
}

#Preview("Former Patron") {
    PatreonMemberDetailPanel(member: .previewFormer)
        .frame(width: 350)
}

#Preview("No Email") {
    PatreonMemberDetailPanel(member: .previewNoEmail)
        .frame(width: 350)
}

#Preview("Minimal Info") {
    let member = PatreonMember(
        id: "minimal",
        type: "member",
        attributes: .init(
            fullName: nil,
            email: nil,
            patronStatus: nil,
            lastChargeStatus: nil,
            lifetimeSupportCents: nil,
            currentlyEntitledAmountCents: nil,
            isFollower: nil,
            lastChargeDate: nil,
            pledgeRelationshipStart: nil,
            note: nil
        ),
        relationships: nil
    )
    PatreonMemberDetailPanel(member: member)
        .frame(width: 350)
}

#Preview("High Lifetime") {
    let member = PatreonMember(
        id: "high-lifetime",
        type: "member",
        attributes: .init(
            fullName: "Super Supporter",
            email: "super@example.com",
            patronStatus: "active_patron",
            lastChargeStatus: "Paid",
            lifetimeSupportCents: 999999,
            currentlyEntitledAmountCents: 5000,
            isFollower: true,
            lastChargeDate: "2026-04-26T00:00:00.000Z",
            pledgeRelationshipStart: "2020-01-01T00:00:00.000Z",
            note: "VIP supporter since day one!"
        ),
        relationships: nil
    )
    PatreonMemberDetailPanel(member: member)
        .frame(width: 350)
}

#Preview("Long Name") {
    let member = PatreonMember(
        id: "long-name",
        type: "member",
        attributes: .init(
            fullName: "Very Long Full Name That Tests Layout Truncation and Text Handling in Member Detail Panel",
            email: "long@example.com",
            patronStatus: "active_patron",
            lastChargeStatus: "Paid",
            lifetimeSupportCents: 10000,
            currentlyEntitledAmountCents: 500,
            isFollower: true,
            lastChargeDate: "2026-04-26T00:00:00.000Z",
            pledgeRelationshipStart: "2025-01-01T00:00:00.000Z",
            note: nil
        ),
        relationships: nil
    )
    PatreonMemberDetailPanel(member: member)
        .frame(width: 350)
}

#Preview("No Pledge Info") {
    let member = PatreonMember(
        id: "no-pledge",
        type: "member",
        attributes: .init(
            fullName: "Free Follower",
            email: "follower@example.com",
            patronStatus: nil,
            lastChargeStatus: nil,
            lifetimeSupportCents: nil,
            currentlyEntitledAmountCents: nil,
            isFollower: true,
            lastChargeDate: nil,
            pledgeRelationshipStart: nil,
            note: nil
        ),
        relationships: nil
    )
    PatreonMemberDetailPanel(member: member)
        .frame(width: 350)
}
