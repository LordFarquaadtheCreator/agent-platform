import SwiftUI

/// Reusable not connected state view
public struct NotConnectedView: View {
    let title: String
    let systemImage: String
    let message: String

    public init(title: String, systemImage: String, message: String) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
    }

    public var body: some View {
        VStack {
            Spacer()
            AppEmptyState(
                title: title,
                systemImage: systemImage,
                message: message
            )
            Spacer()
        }
    }
}

/// Reusable loading state view
public struct LoadingStateView: View {
    let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack {
            Spacer()
            if let message = message {
                VStack(spacing: AppTheme.Spacing.medium) {
                    ProgressView()
                    AppText(message, style: .caption, color: AppTheme.ColorToken.textSecondary)
                }
            } else {
                ProgressView()
            }
            Spacer()
        }
    }
}

/// Reusable error state view
public struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    public init(title: String = "Error", message: String, retryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack {
            Spacer()
            AppCard {
                AppVStack(spacing: .medium, alignment: .center) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.ColorToken.statusError)

                    AppText(title, style: .headline)
                    AppText(message, style: .body, color: AppTheme.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)

                    if let retryAction = retryAction {
                        Button("Retry") {
                            retryAction()
                        }
                        .appButtonStyle(.bordered)
                    }
                }
            }
            Spacer()
        }
    }
}

/// Reusable empty state view (renamed to avoid SwiftUI.EmptyView conflict)
public struct EmptyDataView: View {
    let title: String
    let systemImage: String
    let message: String

    public init(title: String, systemImage: String, message: String) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
    }

    public var body: some View {
        VStack {
            Spacer()
            AppEmptyState(
                title: title,
                systemImage: systemImage,
                message: message
            )
            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Not Connected") {
    NotConnectedView(
        title: "Not Connected",
        systemImage: "paintbrush",
        message: "DeviantArt credentials configured but not authenticated. Complete OAuth in Settings."
    )
}

#Preview("Loading") {
    LoadingStateView()
}

#Preview("Loading with Message") {
    LoadingStateView(message: "Refreshing session...")
}

#Preview("Error") {
    ErrorStateView(
        title: "Connection Error",
        message: "Failed to load data from server."
    )
}

#Preview("Error with Retry") {
    ErrorStateView(title: "Connection Error", message: "Failed to load data from server.") {}
}

#Preview("Empty Data") {
    EmptyDataView(
        title: "No Data",
        systemImage: "doc.plaintext",
        message: "No items found."
    )
}
