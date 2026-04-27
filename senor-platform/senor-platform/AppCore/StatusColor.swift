import SwiftUI

/// Centralized status color mapping
public enum StatusColor: String, CaseIterable, Sendable {
    case gray
    case blue
    case green
    case yellow
    case orange
    case red
    case purple

    public var swiftUIColor: Color {
        switch self {
        case .gray: return .gray
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        case .purple: return .purple
        }
    }

    /// Get color from status string
    public static func from(_ status: String) -> StatusColor {
        switch status.lowercased() {
        case "pending", "scheduled", "queued":
            return .gray

        case "running", "active", "publishing", "in_progress":
            return .blue

        case "completed", "success", "approved", "published":
            return .green

        case "warning", "stale", "retry":
            return .yellow

        case "cancelled", "skipped":
            return .orange

        case "failed", "error", "rejected":
            return .red

        default:
            return .gray
        }
    }

    /// Get color from approval status
    public static func from(approval: ApprovalStatus) -> StatusColor {
        switch approval {
        case .pending: return .yellow
        case .approved: return .green
        case .rejected: return .red
        }
    }

    /// Get color from task run status
    public static func from(taskStatus: TaskRunStatus) -> StatusColor {
        switch taskStatus {
        case .pending: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }

    /// Get color from publication state
    public static func from(publication: PublicationState) -> StatusColor {
        switch publication {
        case .pending: return .gray
        case .scheduled: return .blue
        case .publishing: return .yellow
        case .published: return .green
        case .failed: return .red
        }
    }
}

// MARK: - SwiftUI View Extension

public struct StatusBadge: View {
    let status: String
    let color: StatusColor

    public init(status: String, color: StatusColor? = nil) {
        self.status = status
        self.color = color ?? StatusColor.from(status)
    }

    public var body: some View {
        Text(status.capitalized)
            .font(AppTheme.Typography.caption)
            .fontWeight(.medium)
            .padding(.horizontal, AppTheme.Spacing.badgeHorizontalPadding)
            .padding(.vertical, AppTheme.Spacing.badgeVerticalPadding)
            .background(color.swiftUIColor.opacity(0.15))
            .foregroundStyle(color.swiftUIColor)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusBadge(status: "pending")
        StatusBadge(status: "running")
        StatusBadge(status: "completed")
        StatusBadge(status: "failed")
    }
    .padding()
}
