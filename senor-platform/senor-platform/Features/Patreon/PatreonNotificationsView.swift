import SwiftUI

struct PatreonNotificationsView: View {
    let events: [PatreonPledgeEventRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AppText("Notifications", style: .title3)

            if events.isEmpty {
                AppCard {
                    VStack(spacing: AppTheme.Spacing.small) {
                        Image(systemName: "bell.slash")
                            .font(AppTheme.Typography.title2)
                            .foregroundStyle(AppTheme.ColorToken.textSecondary)
                        AppText("No recent activity", style: .body, color: AppTheme.ColorToken.textSecondary)
                    }
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: AppTheme.Spacing.small) {
                        ForEach(events) { event in
                            NotificationRow(event: event)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

private struct NotificationRow: View {
    let event: PatreonPledgeEventRecord

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: iconForEventType(event.eventType))
                .foregroundStyle(colorForEventType(event.eventType))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                AppText(textForEventType(event), style: .body)
                AppText(formatDate(event.date), style: .caption, color: AppTheme.ColorToken.textSecondary)
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.small)
        .background(AppTheme.ColorToken.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
    }

    private func iconForEventType(_ type: String) -> String {
        switch type {
        case "pledge_start": return "person.badge.plus"
        case "pledge_upgrade": return "arrow.up.circle"
        case "pledge_downgrade": return "arrow.down.circle"
        case "pledge_delete": return "person.badge.minus"
        case "subscription": return "repeat"
        default: return "bell"
        }
    }

    private func colorForEventType(_ type: String) -> Color {
        switch type {
        case "pledge_start": return AppTheme.ColorToken.statusSuccess
        case "pledge_upgrade": return AppTheme.ColorToken.statusInfo
        case "pledge_downgrade": return AppTheme.ColorToken.statusWarning
        case "pledge_delete": return AppTheme.ColorToken.statusError
        case "subscription": return AppTheme.ColorToken.accent
        default: return AppTheme.ColorToken.textSecondary
        }
    }

    private func textForEventType(_ event: PatreonPledgeEventRecord) -> String {
        switch event.eventType {
        case "pledge_start":
            return "New patron joined"
        case "pledge_upgrade":
            return "Pledge upgraded"
        case "pledge_downgrade":
            return "Pledge downgraded"
        case "pledge_delete":
            return "Patron left"
        case "subscription":
            return "Subscription renewed"
        default:
            return "Unknown event"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#if DEBUG
#Preview("Empty Notifications") {
    PatreonNotificationsView(events: [])
        .frame(width: 400)
}

#Preview("With Notifications") {
    let events = [
        PatreonPledgeEventRecord(id: "1", memberId: "m1", eventType: "pledge_start", date: Date(), amountCents: 500, paymentStatus: "Paid", tierId: "t1", tierTitle: "Basic"),
        PatreonPledgeEventRecord(id: "2", memberId: "m2", eventType: "pledge_upgrade", date: Date().addingTimeInterval(-3600), amountCents: 1500, paymentStatus: "Paid", tierId: "t2", tierTitle: "Premium"),
        PatreonPledgeEventRecord(id: "3", memberId: "m3", eventType: "pledge_delete", date: Date().addingTimeInterval(-86400), amountCents: nil, paymentStatus: nil, tierId: nil, tierTitle: nil)
    ]

    PatreonNotificationsView(events: events)
        .frame(width: 400)
}
#endif
