import Foundation
import SwiftUI

/// Shared formatters for Patreon data types
public enum PatreonFormatters {

    /// Format cents as dollar amount (e.g., 500 -> "$5.00")
    public static func formatCents(_ cents: Int?) -> String {
        guard let cents = cents else { return "-" }
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    /// Format ISO8601 date string to readable format
    public static func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else {
            // Try without fractional seconds
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            guard let fallbackDate = fallbackFormatter.date(from: isoString) else { return isoString }
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: fallbackDate)
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }

    /// Get color for patron status
    public static func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active_patron":
            return AppTheme.ColorToken.statusSuccess
        case "declined_patron":
            return AppTheme.ColorToken.statusError
        case "former_patron":
            return AppTheme.ColorToken.textSecondary
        default:
            return AppTheme.ColorToken.statusInfo
        }
    }
}
