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

#Preview("Short") {
    TagPill(name: "art")
}

#Preview("Long") {
    TagPill(name: "verylongtagname")
}

#Preview("With Spaces") {
    TagPill(name: "fan art")
}

#Preview("Multiple") {
    FlowLayout {
        TagPill(name: "digital")
        TagPill(name: "art")
        TagPill(name: "fantasy")
        TagPill(name: "illustration")
        TagPill(name: "character design")
        TagPill(name: "portrait")
        TagPill(name: "colorful")
    }
}
