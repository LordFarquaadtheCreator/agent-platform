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
                            .markdownTheme(.app)
                    }
                }

                if let url = post.attributes.url, let linkURL = URL(string: url) {
                    Link(destination: linkURL) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open on Patreon")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.medium)
                        .background(AppTheme.ColorToken.accent)
                        .foregroundStyle(AppTheme.ColorToken.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
                    }
                    .appButtonStyle(.borderedProminent)
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

#Preview("Paid Post") {
    PatreonPostDetailPanel(post: .previewPaid)
        .frame(width: 350)
}

#Preview("Public Post") {
    PatreonPostDetailPanel(post: .previewPublic)
        .frame(width: 350)
}

#Preview("Long Content") {
    PatreonPostDetailPanel(post: .previewLongContent)
        .frame(width: 350)
}

#Preview("No Title") {
    let post = PatreonPost(
        id: "no-title",
        type: "post",
        attributes: .init(
            title: nil,
            content: "<p>Post without a title</p>",
            url: "https://patreon.com/posts/no-title",
            isPaid: true,
            isPublic: false,
            publishedAt: "2026-04-26T10:00:00.000Z"
        ),
        relationships: nil
    )
    PatreonPostDetailPanel(post: post)
        .frame(width: 350)
}

#Preview("No Content") {
    let post = PatreonPost(
        id: "no-content",
        type: "post",
        attributes: .init(
            title: "Title Only",
            content: nil,
            url: "https://patreon.com/posts/no-content",
            isPaid: false,
            isPublic: true,
            publishedAt: "2026-04-26T10:00:00.000Z"
        ),
        relationships: nil
    )
    PatreonPostDetailPanel(post: post)
        .frame(width: 350)
}

#Preview("No URL") {
    let post = PatreonPost(
        id: "no-url",
        type: "post",
        attributes: .init(
            title: "Draft Post",
            content: "<p>This post has no URL yet</p>",
            url: nil,
            isPaid: true,
            isPublic: false,
            publishedAt: nil
        ),
        relationships: nil
    )
    PatreonPostDetailPanel(post: post)
        .frame(width: 350)
}

#Preview("Free Patron Post") {
    PatreonPostDetailPanel(post: .previewFree)
        .frame(width: 350)
}

#Preview("Complex HTML") {
    let post = PatreonPost(
        id: "complex-html",
        type: "post",
        attributes: .init(
            title: "Rich Content Post",
            content: """
            <h1>Heading</h1>
            <p>Paragraph with <strong>bold</strong>, <em>italic</em>, and <a href="https://example.com">link</a>.</p>
            <blockquote>Blockquote for emphasis</blockquote>
            <code>inline code</code>
            <pre><code>code block\nwith multiple lines</code></pre>
            <ul>
                <li>Item one</li>
                <li>Item two</li>
            </ul>
            <ol>
                <li>First</li>
                <li>Second</li>
            </ol>
            """,
            url: "https://patreon.com/posts/complex",
            isPaid: true,
            isPublic: false,
            publishedAt: "2026-04-26T10:00:00.000Z"
        ),
        relationships: nil
    )
    PatreonPostDetailPanel(post: post)
        .frame(width: 350)
}
