import SwiftUI
import MarkdownUI

struct PatreonPostDetailPanel: View {
    let post: PatreonPost

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    AppText(post.attributes.title ?? "Untitled", style: .title2)
                        .lineLimit(2)

                    HStack {
                        if post.attributes.isPaid == true {
                            Label("Paid", systemImage: "lock.fill")
                                .foregroundStyle(AppTheme.ColorToken.accent)
                        } else if post.attributes.isPublic == true {
                            Label("Public", systemImage: "globe")
                                .foregroundStyle(AppTheme.ColorToken.statusSuccess)
                        }
                        Spacer()
                    }

                    if let published = post.attributes.publishedAt {
                        let dateString = formatDate(published)
                        AppText("Published \(dateString)", style: .caption, color: AppTheme.ColorToken.textSecondary)
                    }
                }

                if let content = post.attributes.content {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                        AppText("Content", style: .title3)
                        let markdownContent = HTMLUtils.toMarkdown(content)
                        Markdown(markdownContent)
                            .markdownTheme(.gitHub)
                    }
                }

                if let url = post.attributes.url, let linkURL = URL(string: url) {
                    Link(destination: linkURL) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open on Patreon")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.ColorToken.accent)
                        .foregroundStyle(AppTheme.ColorToken.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appScreenPadding()
        }
        .background(AppTheme.ColorToken.chromeBackground)
    }

    private func formatDate(_ isoString: String) -> String {
        PatreonFormatters.formatDate(isoString)
    }
}

// MARK: - Previews

#Preview("Post Detail") {
    let mockPost = PatreonPost(
        id: "preview-post-1",
        type: "post",
        attributes: PatreonPost.PatreonPostAttributes(
            title: "Exclusive Art Preview",
            content: "<p>This is a preview of exclusive content for patrons!</p>",
            url: "https://patreon.com/posts/preview-1",
            isPaid: true,
            isPublic: false,
            publishedAt: "2026-04-26T10:00:00.000Z"
        ),
        relationships: nil
    )
    PatreonPostDetailPanel(post: mockPost)
        .frame(width: 350)
}
