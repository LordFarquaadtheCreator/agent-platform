import SwiftUI
#if canImport(Charts)
import Charts

struct PatreonStatsCard: View {
    let totalPatrons: Int
    let activePatrons: Int
    let totalRevenue: String
    let monthlyRevenue: String
    let statsHistory: [PatreonStatsRecord]

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                AppText("Stats", style: .headline)

                HStack(spacing: AppTheme.Spacing.large) {
                    PatreonStatItem(
                        title: "Total Patrons",
                        value: "\(totalPatrons)",
                        subtitle: "All time"
                    )
                    PatreonStatItem(
                        title: "Active",
                        value: "\(activePatrons)",
                        subtitle: "Current"
                    )
                    PatreonStatItem(
                        title: "Revenue",
                        value: totalRevenue,
                        subtitle: "Total"
                    )
                    PatreonStatItem(
                        title: "Monthly",
                        value: monthlyRevenue,
                        subtitle: "Recurring"
                    )
                }

                if !statsHistory.isEmpty {
                    Divider()

                    AppText("Revenue Trend (30 days)", style: .caption, color: AppTheme.ColorToken.textSecondary)

                    Chart(statsHistory.prefix(30)) { stat in
                        LineMark(
                            x: .value("Date", stat.timestamp),
                            y: .value("Revenue", stat.monthlyRevenueCents / 100) // Convert to dollars
                        )
                        .foregroundStyle(AppTheme.ColorToken.accent)
                    }
                    .frame(height: 100)
                }
            }
        }
    }
}

private struct PatreonStatItem: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
            AppText(title, style: .caption, color: AppTheme.ColorToken.textSecondary)
            AppText(value, style: .title2)
            AppText(subtitle, style: .caption, color: AppTheme.ColorToken.textSecondary)
        }
    }
}

#if DEBUG
#Preview("Stats Card") {
    PatreonStatsCard(
        totalPatrons: 150,
        activePatrons: 120,
        totalRevenue: "$15,000",
        monthlyRevenue: "$1,200",
        statsHistory: []
    )
    .frame(width: 400)
}

#Preview("Stats Card with History") {
    let history = (0..<30).map { i in
        PatreonStatsRecord(
            id: UUID().uuidString,
            timestamp: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
            totalPatrons: 100 + i,
            activePatrons: 80 + i,
            totalRevenueCents: 10000 + (i * 100),
            monthlyRevenueCents: 1000 + (i * 10)
        )
    }

    PatreonStatsCard(
        totalPatrons: 150,
        activePatrons: 120,
        totalRevenue: "$15,000",
        monthlyRevenue: "$1,200",
        statsHistory: history
    )
    .frame(width: 400)
}
#endif
#endif
