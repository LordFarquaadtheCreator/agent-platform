import SwiftUI

struct CategoryBadge: View {
    let category: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .font(.caption2)
            Text(category.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
