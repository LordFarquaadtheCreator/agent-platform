import SwiftUI

struct StatPill: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.ColorToken.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview {
    StatPill(title: "Views", value: 1234, icon: "eye")
}
