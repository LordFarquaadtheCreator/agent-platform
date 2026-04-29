import SwiftUI

struct StatItem: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            Image(systemName: icon)
                .font(AppTheme.Typography.caption2)
            if value > 0 {
                Text("\(value)")
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Previews

#Preview("Zero") {
    StatItem(icon: "eye", value: 0)
}

#Preview("Small") {
    StatItem(icon: "eye", value: 5)
}

#Preview("Large") {
    StatItem(icon: "eye", value: 999999)
}

#Preview("Multiple Icons") {
    HStack {
        StatItem(icon: "eye", value: 100)
        StatItem(icon: "star.fill", value: 50)
        StatItem(icon: "bubble.right", value: 0)
        StatItem(icon: "arrow.down.circle", value: 25)
    }
}
