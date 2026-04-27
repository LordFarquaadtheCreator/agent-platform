import SwiftUI
import MarkdownUI

struct DeviationDetailPanel: View {
    let deviation: DeviantArtClient.Deviation
    @ObservedObject var viewModel: DeviantArtViewModel
    @EnvironmentObject private var appState: AppShellModel

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
            .padding()
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task {
            await viewModel.loadMetadata(for: deviation.id)
        }
    }

    private var fullImageSection: some View {
        Group {
            if let fullURL = deviation.content?.src.flatMap({ URL(string: $0) })
                ?? deviation.thumbs?.max(by: { max($0.width, $0.height) < max($1.width, $1.height) }).flatMap({ URL(string: $0.src) }) {
                AsyncImage(url: fullURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
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
                    Text("·")
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
                .foregroundColor(AppTheme.ColorToken.textSecondary)
            }

            if let published = deviation.publishedTime {
                AppText("Published \(RelativeDateFormatter.format(unixTime: published))", style: .caption, color: AppTheme.ColorToken.textSecondary)
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
                    FlowLayout(spacing: 8) {
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
                    AppText("\(comments) comments available on DeviantArt", style: .body, color: AppTheme.ColorToken.textSecondary)
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
                    .foregroundColor(.white)
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

#Preview {
    DeviationDetailPanel(deviation: DeviantArtClient.Deviation.preview, viewModel: DeviantArtViewModel.preview)
        .environmentObject(AppShellModel())
}
