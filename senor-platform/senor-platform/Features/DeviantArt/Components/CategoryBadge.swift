import SwiftUI

struct CategoryBadge: View {
    let category: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .font(AppTheme.Typography.caption2)
            Text(category.capitalized)
                .font(AppTheme.Typography.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, AppTheme.Spacing.badgeHorizontalPadding)
        .padding(.vertical, AppTheme.Spacing.badgeVerticalPadding)
        .background(AppTheme.ColorToken.accent.opacity(0.9))
        .foregroundColor(.white)
        .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview {
    CategoryBadge(category: "Digital Art")
}

#Preview("Photography") {
    CategoryBadge(category: "Photography")
}
