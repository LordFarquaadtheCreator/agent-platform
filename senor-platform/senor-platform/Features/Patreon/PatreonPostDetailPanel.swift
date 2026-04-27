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
                        AppText("Published \(formatDate(published))", style: .caption, color: AppTheme.ColorToken.textSecondary)
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
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(AppTheme.ColorToken.chromeBackground)
    }

    private func formatDate(_ isoString: String) -> String {
        PatreonFormatters.formatDate(isoString)
    }
}
