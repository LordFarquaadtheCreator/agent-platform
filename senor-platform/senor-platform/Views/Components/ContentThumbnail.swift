import SwiftUI

/// Reusable thumbnail component for content images
public struct ContentThumbnail: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat
    @Environment(\.privacyMode) private var isPrivacyMode

    public init(url: URL?, size: CGFloat = 60, cornerRadius: CGFloat = 10) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)

                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: isPrivacyMode ? 20 : 0)

                    case .failure:
                        placeholder

                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
            .overlay(
                AppIcon(AppTheme.Icon.content, size: .medium, color: AppTheme.ColorToken.textSecondary)
            )
    }
}

#Preview {
    AppHStack(spacing: .large) {
        ContentThumbnail(url: nil, size: AppTheme.Layout.thumbnailSize)
        ContentThumbnail(url: nil, size: 80)
        ContentThumbnail(url: nil, size: 100)
    }
    .appScreenPadding()
}
