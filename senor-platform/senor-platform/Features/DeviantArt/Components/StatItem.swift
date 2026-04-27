import SwiftUI

struct StatItem: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            if value > 0 {
                Text("\(value)")
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    HStack {
        StatItem(icon: "eye", value: 100)
        StatItem(icon: "star.fill", value: 50)
        StatItem(icon: "bubble.right", value: 0)
    }
}
