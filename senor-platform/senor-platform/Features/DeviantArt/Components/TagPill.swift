import SwiftUI

struct TagPill: View {
    let name: String

    var body: some View {
        Text(name)
            .font(AppTheme.Typography.caption)
            .padding(.horizontal, AppTheme.Spacing.tagHorizontalPadding)
            .padding(.vertical, AppTheme.Spacing.tagVerticalPadding)
            .background(AppTheme.ColorToken.textSecondary.opacity(0.15))
            .foregroundColor(AppTheme.ColorToken.textPrimary)
            .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview {
    HStack {
        TagPill(name: "swift")
        TagPill(name: "ui")
        TagPill(name: "artwork")
    }
}
