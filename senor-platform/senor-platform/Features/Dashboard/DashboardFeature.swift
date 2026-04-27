import SwiftUI

struct DashboardScreen: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                AppSectionHeader(
                    title: "Dashboard",
                    detail: "Operational snapshot across agents, tasks, content, and approvals."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.medium) {
                    AppMetricCard(
                        title: "Active Agents",
                        value: "\(model.snapshot.activeAgentCount)",
                        icon: AppTheme.Icon.agent,
                        tint: AppTheme.ColorToken.statusInfo
                    )
                    AppMetricCard(
                        title: "Pending Approvals",
                        value: "\(model.snapshot.pendingApprovalCount)",
                        icon: AppTheme.Icon.approval,
                        tint: AppTheme.ColorToken.statusWarning
                    )
                    AppMetricCard(
                        title: "Enabled Tasks",
                        value: "\(model.snapshot.scheduledTaskCount)",
                        icon: AppTheme.Icon.task,
                        tint: AppTheme.ColorToken.statusSuccess
                    )
                    AppMetricCard(
                        title: "Published Content",
                        value: "\(model.snapshot.publishedContentCount)",
                        icon: AppTheme.Icon.content,
                        tint: AppTheme.ColorToken.accent
                    )
                }

                AppCard {
                    AppVStack(spacing: .medium, alignment: .leading) {
                        AppSectionHeader(title: "Recent Activity")
                        if model.snapshot.recentContent.isEmpty {
                            AppEmptyState(
                                title: "No Recent Content",
                                systemImage: AppTheme.Icon.clock,
                                message: "Generated content will appear here once the workflow starts producing output."
                            )
                        } else {
                            ForEach(model.snapshot.recentContent) { item in
                                AppHStack(spacing: .medium) {
                                    AppVStack(spacing: .tight, alignment: .leading) {
                                        AppText(item.title, style: .headline)
                                        AppText(
                                            item.createdAt.formatted(.relative(presentation: .named)),
                                            style: .caption,
                                            color: AppTheme.ColorToken.textSecondary
                                        )
                                    }
                                    Spacer()
                                    AppStatusPill(
                                        title: item.status.title,
                                        color: StatusColor.from(item.status.rawValue).swiftUIColor
                                    )
                                }
                                if item.id != model.snapshot.recentContent.last?.id {
                                    AppDivider()
                                }
                            }
                        }
                    }
                }
            }
            .appScreenPadding()
        }
        .background(AppTheme.ColorToken.chromeBackground)
    }
}
