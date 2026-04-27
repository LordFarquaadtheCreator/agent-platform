import SwiftUI

// MARK: - AppTheme
// All visual values live here. No raw styling in feature code.

public enum AppTheme {

    // MARK: - Typography
    // Use these instead of .font(.headline), .font(.caption), etc.

    enum Typography {
        static let largeTitle: Font = .largeTitle.weight(.bold)
        static let title: Font = .title.weight(.bold)
        static let title2: Font = .title2.weight(.semibold)
        static let title3: Font = .title3.weight(.semibold)
        static let headline: Font = .headline.weight(.semibold)
        static let subheadline: Font = .subheadline
        static let body: Font = .body
        static let callout: Font = .callout
        static let caption: Font = .caption
        static let caption2: Font = .caption2
        static let metricValue: Font = .system(size: 28, weight: .bold, design: .rounded)
        static let metricLabel: Font = .caption.weight(.medium)
        static let monospace: Font = .system(.body, design: .monospaced)
        static let monospaceCaption: Font = .system(.caption, design: .monospaced)
    }

    // MARK: - ColorToken
    // Semantic colors only. No raw Color.blue, .red, etc. in feature code.

    enum ColorToken {
        // Accent
        static let accent = Color.blue

        // Backgrounds
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        static let chromeBackground = Color(nsColor: .windowBackgroundColor)
        static let sectionBackground = Color(nsColor: .secondarySystemFill)

        // Text
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.primary.opacity(0.5)

        // Status
        static let statusSuccess = Color.green
        static let statusWarning = Color.orange
        static let statusError = Color.red
        static let statusInfo = Color.blue
        static let statusNeutral = Color.gray

        // Borders
        static let subtleBorder = Color.primary.opacity(0.08)
        static let divider = Color.primary.opacity(0.1)
    }

    // MARK: - Spacing
    // Use these instead of raw .padding(4), .padding(16), etc.

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32

        // Semantic spacing
        static let screenPadding: CGFloat = 24
        static let cardPadding: CGFloat = 16
        static let cardGap: CGFloat = 16
        static let listRowPadding: CGFloat = 4
        static let listRowGap: CGFloat = 6
        static let sectionGap: CGFloat = 24
        static let interItemGap: CGFloat = 12
        static let tightGap: CGFloat = 4

        // Tag/Badge specific spacing (pill-shaped components)
        static let tagHorizontalPadding: CGFloat = 10
        static let tagVerticalPadding: CGFloat = 5
        static let badgeHorizontalPadding: CGFloat = 8
        static let badgeVerticalPadding: CGFloat = 4
    }

    // MARK: - CornerRadius
    // Use these instead of raw .cornerRadius(10), etc.

    enum CornerRadius {
        static let zero: CGFloat = 0
        static let small: CGFloat = 6
        static let control: CGFloat = 10
        static let card: CGFloat = 14
        static let pill: CGFloat = 999
    }

    // MARK: - Shadow
    // Use AppTheme.Shadow.token instead of raw .shadow(...)

    enum Shadow {
        static let clear: ShadowStyle = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        static let subtle: ShadowStyle = ShadowStyle(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        static let elevated: ShadowStyle = ShadowStyle(color: .black.opacity(0.1), radius: 16, x: 0, y: 4)
        static let toast: ShadowStyle = ShadowStyle(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

        // Legacy raw values for components that need them
        static let radius: CGFloat = 8
        static let y: CGFloat = 2
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Layout
    // Screen and component dimensions

    enum Layout {
        static let minSheetWidth: CGFloat = 620
        static let minSheetHeight: CGFloat = 460
        static let mediumSheetWidth: CGFloat = 720
        static let mediumSheetHeight: CGFloat = 560
        static let sidebarMinWidth: CGFloat = 220
        static let sidebarIdealWidth: CGFloat = 250
        static let detailMinWidth: CGFloat = 300
        static let detailIdealWidth: CGFloat = 320
        static let mainAreaMinWidth: CGFloat = 640
        static let iconSize: CGFloat = 16
        static let thumbnailSize: CGFloat = 60
        static let windowMinWidth: CGFloat = 1200
        static let windowMinHeight: CGFloat = 820
    }

    // MARK: - Icon
    // Centralized SF Symbol names

    enum Icon {
        static let agent = "cpu"
        static let agentFill = "cpu.fill"
        static let task = "list.bullet.rectangle"
        static let content = "doc.text.image"
        static let approval = "checkmark.shield"
        static let settings = "gear"
        static let add = "plus"
        static let addSquare = "plus.square"
        static let refresh = "arrow.clockwise"
        static let search = "magnifyingglass"
        static let clock = "clock"
        static let calendar = "calendar"
        static let chevronRight = "chevron.right"
        static let chevronDown = "chevron.down"
        static let exclamation = "exclamationmark.triangle"
        static let checkmark = "checkmark"
        static let xmark = "xmark"
        static let more = "ellipsis"
        static let document = "doc.text"
        static let folder = "folder"
        static let trash = "trash"
        static let edit = "pencil"
        static let share = "square.and.arrow.up"
        static let success = "checkmark.circle"
        static let error = "xmark.circle"
        static let upload = "arrow.up.circle"
        static let save = "checkmark"
        static let sidebar = "sidebar.right"
        static let taskAdd = "plus.square"
    }
}
