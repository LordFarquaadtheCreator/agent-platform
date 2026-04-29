import SwiftUI

struct StatPill: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xSmall) {
            HStack(spacing: AppTheme.Spacing.small) {
                Image(systemName: icon)
                    .font(AppTheme.Typography.caption2)
                Text("\(value)")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
            }
            Text(title)
                .font(AppTheme.Typography.caption2)
                .foregroundStyle(AppTheme.ColorToken.textSecondary)
        }
        .padding(.vertical, AppTheme.Spacing.xSmall)
    }
}

// MARK: - Previews

#Preview("Zero") {
    StatPill(title: "Views", value: 0, icon: "eye")
}

#Preview("Small") {
    StatPill(title: "Views", value: 50, icon: "eye")
}

#Preview("Large") {
    StatPill(title: "Views", value: 9999999, icon: "eye")
}

#Preview("Row") {
    HStack {
        StatPill(title: "Deviations", value: 200, icon: "photo")
        StatPill(title: "Watchers", value: 150, icon: "eye")
        StatPill(title: "Friends", value: 23, icon: "person.2")
    }
}
