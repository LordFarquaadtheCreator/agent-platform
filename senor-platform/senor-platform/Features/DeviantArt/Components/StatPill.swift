import SwiftUI

struct StatPill: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: AppTheme.Spacing.small) {
                Image(systemName: icon)
                    .font(AppTheme.Typography.caption2)
                Text("\(value)")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
            }
            Text(title)
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.ColorToken.textSecondary)
        }
        .padding(.vertical, AppTheme.Spacing.xSmall)
    }
}

// MARK: - Previews

#Preview {
    StatPill(title: "Views", value: 1234, icon: "eye")
}
