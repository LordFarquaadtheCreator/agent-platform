import SwiftUI
import MarkdownUI

struct DeviationDetailPanel: View {
    let deviation: DeviantArtClient.Deviation
    @ObservedObject var viewModel: DeviantArtViewModel
    @EnvironmentObject private var appState: AppShellModel
    @Environment(\.privacyMode) private var isPrivacyMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                fullImageSection
                titleSection
                descriptionSection
                tagsSection
                commentsSection
                actionsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appScreenPadding()
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task {
            await viewModel.loadMetadata(for: deviation.id)
        }
    }

    private var fullImageSection: some View {
        Group {
            let contentURL = deviation.content?.src.flatMap { URL(string: $0) }
            let thumbURL = deviation.thumbs?.max {
                max($0.width, $0.height) < max($1.width, $1.height)
            }.flatMap { URL(string: $0.src) }
            if let fullURL = contentURL ?? thumbURL {
                AsyncImage(url: fullURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .blur(radius: isPrivacyMode ? 20 : 0)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))

                    case .failure:
                        placeholderImage

                    default:
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(ProgressView())
                    }
                }
            }
        }
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(AppIcon(AppTheme.Icon.content, size: .large, color: AppTheme.ColorToken.textSecondary))
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppText(deviation.title, style: .title2)
                .lineLimit(2)

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.ColorToken.statusSuccess)
                AppText("Published", style: .body)
                    .foregroundColor(AppTheme.ColorToken.statusSuccess)

                if let category = deviation.category {
                    AppText("·", style: .body, color: AppTheme.ColorToken.textSecondary)
                    CategoryBadge(category: category)
                }
            }

            if let stats = deviation.stats {
                HStack(spacing: AppTheme.Spacing.medium) {
                    if let views = stats.views, views > 0 {
                        Label("\(views)", systemImage: "eye")
                    }
                    if let favs = stats.favourites, favs > 0 {
                        Label("\(favs)", systemImage: "star.fill")
                    }
                    if let comments = stats.comments, comments > 0 {
                        Label("\(comments)", systemImage: "bubble.right")
                    }
                    if let downloads = stats.downloads, downloads > 0 {
                        Label("\(downloads)", systemImage: "arrow.down.circle")
                    }
                }
                .foregroundStyle(AppTheme.ColorToken.textSecondary)
            }

            if let published = deviation.publishedTime {
                let dateText = RelativeDateFormatter.format(unixTime: published)
                AppText("Published \(dateText)", style: .caption, color: AppTheme.ColorToken.textSecondary)
            }
        }
    }

    private var descriptionSection: some View {
        Group {
            if let metadata = viewModel.deviationMetadata[deviation.id],
               let description = metadata.description,
               !description.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    AppText("Description", style: .title3)
                    let markdownContent = HTMLUtils.toMarkdown(description)
                    Markdown(markdownContent)
                        .markdownTheme(.gitHub)
                }
            }
        }
    }

    private var tagsSection: some View {
        Group {
            if let metadata = viewModel.deviationMetadata[deviation.id],
               let tags = metadata.tags,
               !tags.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    AppText("Tags", style: .title3)
                    FlowLayout(spacing: AppTheme.Spacing.small) {
                        ForEach(tags, id: \.tagName) { tag in
                            TagPill(name: tag.tagName)
                        }
                    }
                }
            }
        }
    }

    private var commentsSection: some View {
        Group {
            if let stats = deviation.stats,
               let comments = stats.comments, comments > 0 {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    AppText("Comments", style: .title3)
                    AppText("\(comments) comments available", style: .body, color: AppTheme.ColorToken.textSecondary)
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            if let url = URL(string: deviation.url) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    appState.showToast("Link copied to clipboard")
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Link")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.ColorToken.accent)
                    .foregroundStyle(AppTheme.ColorToken.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
                }
                .buttonStyle(.plain)
            }

            if let metadata = viewModel.deviationMetadata[deviation.id],
               let license = metadata.license {
                AppText("License: \(license)", style: .caption, color: AppTheme.ColorToken.textSecondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("Standard Deviation") {
    DeviationDetailPanel(deviation: .preview, viewModel: .preview)
        .environmentObject(AppShellModel())
}

#Preview("No Thumbnail") {
    let deviation = DeviantArtClient.Deviation(
        deviationid: "no-thumb",
        url: "https://deviantart.com/art/no-thumb",
        title: "Deviation Without Thumbnail",
        category: "Photography",
        author: nil,
        stats: DeviantArtClient.Deviation.Stats(
            views: 500,
            favourites: 50,
            comments: 10,
            downloads: 20
        ),
        publishedTime: "1700000000",
        allowsComments: true,
        isFavourited: nil,
        isDeleted: nil,
        thumbs: nil,
        content: DeviantArtClient.Deviation.ContentInfo(
            src: "https://example.com/full.jpg",
            width: 1920,
            height: 1080,
            filesize: 1024000
        )
    )
    DeviationDetailPanel(deviation: deviation, viewModel: .preview)
        .environmentObject(AppShellModel())
}

#Preview("No Content Src") {
    let deviation = DeviantArtClient.Deviation(
        deviationid: "no-content",
        url: "https://deviantart.com/art/no-content",
        title: "Deviation Without Content",
        category: "Traditional",
        author: nil,
        stats: DeviantArtClient.Deviation.Stats(
            views: 300,
            favourites: 30,
            comments: 5,
            downloads: nil
        ),
        publishedTime: "1700000000",
        allowsComments: false,
        isFavourited: nil,
        isDeleted: nil,
        thumbs: [
            DeviantArtClient.Deviation.Thumb(src: "https://example.com/thumb.jpg", width: 400, height: 300)
        ],
        content: nil
    )
    DeviationDetailPanel(deviation: deviation, viewModel: .preview)
        .environmentObject(AppShellModel())
}

#Preview("No Stats") {
    let deviation = DeviantArtClient.Deviation(
        deviationid: "no-stats",
        url: "https://deviantart.com/art/no-stats",
        title: "Deviation Without Stats",
        category: nil,
        author: nil,
        stats: nil,
        publishedTime: nil,
        allowsComments: nil,
        isFavourited: nil,
        isDeleted: nil,
        thumbs: nil,
        content: nil
    )
    DeviationDetailPanel(deviation: deviation, viewModel: .preview)
        .environmentObject(AppShellModel())
}

#Preview("Long Title") {
    let deviation = DeviantArtClient.Deviation(
        deviationid: "long-title",
        url: "https://deviantart.com/art/long-title",
        title: "This is a Very Long Deviation Title That Tests How the UI Handles Text Truncation and Layout Behavior",
        category: "Digital Art",
        author: nil,
        stats: DeviantArtClient.Deviation.Stats(
            views: 9999,
            favourites: 888,
            comments: 77,
            downloads: 66
        ),
        publishedTime: "1700000000",
        allowsComments: true,
        isFavourited: nil,
        isDeleted: nil,
        thumbs: nil,
        content: nil
    )
    DeviationDetailPanel(deviation: deviation, viewModel: .preview)
        .environmentObject(AppShellModel())
}

#Preview("With Metadata") {
    // Uses base preview - metadata loaded via viewModel.loadMetadata() in actual use
    DeviationDetailPanel(deviation: .preview, viewModel: .preview)
        .environmentObject(AppShellModel())
}

#Preview("Deleted Deviation") {
    let deviation = DeviantArtClient.Deviation(
        deviationid: "deleted",
        url: "https://deviantart.com/art/deleted",
        title: "Deleted Deviation",
        category: "Other",
        author: nil,
        stats: nil,
        publishedTime: nil,
        allowsComments: nil,
        isFavourited: nil,
        isDeleted: true,
        thumbs: nil,
        content: nil
    )
    DeviationDetailPanel(deviation: deviation, viewModel: .preview)
        .environmentObject(AppShellModel())
}

#Preview("Zero Stats") {
    let deviation = DeviantArtClient.Deviation(
        deviationid: "zero-stats",
        url: "https://deviantart.com/art/zero-stats",
        title: "Zero Stats",
        category: "Literature",
        author: nil,
        stats: DeviantArtClient.Deviation.Stats(
            views: 0,
            favourites: 0,
            comments: 0,
            downloads: 0
        ),
        publishedTime: "1700000000",
        allowsComments: true,
        isFavourited: nil,
        isDeleted: nil,
        thumbs: nil,
        content: nil
    )
    DeviationDetailPanel(deviation: deviation, viewModel: .preview)
        .environmentObject(AppShellModel())
}
