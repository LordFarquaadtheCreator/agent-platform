import Foundation

/// Utility functions for HTML processing
public enum HTMLUtils {
    /// Converts HTML content to Markdown format
    /// - Parameter html: Raw HTML string
    /// - Returns: Markdown formatted string
    public static func toMarkdown(_ html: String) -> String {
        var markdown = html
            .replacingOccurrences(of: "<p>", with: "")
            .replacingOccurrences(of: "</p>", with: "\n\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "<strong>", with: "**")
            .replacingOccurrences(of: "</strong>", with: "**")
            .replacingOccurrences(of: "<b>", with: "**")
            .replacingOccurrences(of: "</b>", with: "**")
            .replacingOccurrences(of: "<em>", with: "*")
            .replacingOccurrences(of: "</em>", with: "*")
            .replacingOccurrences(of: "<i>", with: "*")
            .replacingOccurrences(of: "</i>", with: "*")
            .replacingOccurrences(of: "<li>", with: "- ")
            .replacingOccurrences(of: "</li>", with: "\n")
            .replacingOccurrences(of: "<ul>", with: "")
            .replacingOccurrences(of: "</ul>", with: "")
            .replacingOccurrences(of: "<ol>", with: "")
            .replacingOccurrences(of: "</ol>", with: "")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        // Convert anchor tags to markdown links: <a href="url">text</a> -> [text](url)
        let linkPattern = #"<a\s+href=["']([^"']+)["'][^>]*>([^<]*)</a>"#
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) {
            let range = NSRange(markdown.startIndex..., in: markdown)
            markdown = regex.stringByReplacingMatches(
                in: markdown,
                options: [],
                range: range,
                withTemplate: "[$2]($1)"
            )
        }

        // Strip any remaining HTML tags
        markdown = markdown.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips all HTML tags and returns plain text
    /// - Parameter html: Raw HTML string
    /// - Returns: Plain text string
    public static func stripTags(_ html: String) -> String {
        let plain = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return plain.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
