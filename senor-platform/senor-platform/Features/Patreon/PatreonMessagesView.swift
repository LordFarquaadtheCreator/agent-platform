import SwiftUI

struct PatreonMessagesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AppText("Messages", style: .title3)

            AppCard {
                VStack(spacing: AppTheme.Spacing.medium) {
                    Image(systemName: "message.slash")
                        .font(AppTheme.Typography.title2)
                        .foregroundStyle(AppTheme.ColorToken.textSecondary)

                    AppText("Messaging not available", style: .body, color: AppTheme.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)

                    AppText("Patreon API does not currently support direct messaging", style: .caption, color: AppTheme.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(AppTheme.Spacing.large)
            }
        }
    }
}

#if DEBUG
#Preview("Messages") {
    PatreonMessagesView()
        .frame(width: 400)
}
#endif
