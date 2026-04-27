import Foundation

/// Formats dates as relative time strings (e.g., "2 hours ago", "3 days ago")
public struct RelativeDateFormatter {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Format a Date as relative time string
    public static func format(_ date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Format Unix timestamp (seconds since 1970) as relative time
    public static func format(unixTime: String) -> String {
        guard let timestamp = Double(unixTime) else {
            return unixTime
        }
        let date = Date(timeIntervalSince1970: timestamp)
        return format(date)
    }

    /// Format with full date fallback for older dates
    public static func formatWithFallback(_ date: Date, threshold: TimeInterval = 7 * 24 * 3600) -> String {
        let age = Date().timeIntervalSince(date)
        if age < threshold {
            return format(date)
        } else {
            return dateFormatter.string(from: date)
        }
    }
}
