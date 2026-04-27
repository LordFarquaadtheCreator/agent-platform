import SwiftUI

struct PatreonScreen: View {
    @ObservedObject var model: PatreonModel

    var body: some View {
        VStack(spacing: 0) {
            header

            AppDivider()

            if model.isAnyLoading && !hasAnyData {
                loadingState
            } else if case .notConfigured = model.authState {
                notConfiguredState
            } else if case .expired = model.authState {
                authExpiredState
            } else {
                contentScrollView
            }
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task { await model.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppSectionHeader(
                title: "Patreon",
                detail: model.identity?.data.attributes.fullName ?? model.identity?.data.attributes.vanity
            )
            .padding(AppTheme.Spacing.screenPadding)

            // Auth state indicator
            HStack {
                authStatePill
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.screenPadding)
        }
    }

    private var authStatePill: some View {
        let (text, color): (String, Color) = {
            switch model.authState {
            case .authenticated:
                return ("Connected", AppTheme.ColorToken.statusSuccess)
            case .expired:
                return ("Session Expired", AppTheme.ColorToken.statusWarning)
            case .unauthenticated:
                return ("Not Connected", AppTheme.ColorToken.statusError)
            case .notConfigured:
                return ("Not Configured", AppTheme.ColorToken.textSecondary)
            }
        }()

        return AppStatusPill(title: text, color: color)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack {
            Spacer()
            if model.isRefreshingToken {
                VStack(spacing: AppTheme.Spacing.medium) {
                    ProgressView()
                    AppText("Refreshing session...", style: .caption, color: AppTheme.ColorToken.textSecondary)
                }
            } else {
                ProgressView()
            }
            Spacer()
        }
    }

    private var notConfiguredState: some View {
        VStack {
            Spacer()
            AppEmptyState(
                title: "Patreon Not Configured",
                systemImage: "heart",
                message: "Add your Patreon access token in Settings to see your campaign, posts, and patrons."
            )
            Spacer()
        }
    }

    private var authExpiredState: some View {
        VStack {
            Spacer()
            AppEmptyState(
                title: "Session Expired",
                systemImage: "exclamationmark.triangle",
                message: "Your Patreon session has expired. Please reconnect your account in Settings."
            )
            Spacer()
        }
    }

    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                // Profile/Campaign Card
                if let error = model.profileError {
                    errorCard(error, retryAction: { Task { await model.retryProfile() } })
                } else if let identity = model.identity {
                    profileCard(identity)
                }

                // Campaign stats
                if let campaign = model.campaign {
                    campaignStatsCard(campaign)
                }

                // Posts Section
                if let error = model.postsError {
                    errorCard(error, title: "Posts Error", retryAction: { Task { await model.retryPosts() } })
                } else if !model.posts.isEmpty {
                    postsSection
                } else if !model.isLoadingPosts {
                    emptySectionCard(title: "No Posts", message: "No posts found for this campaign.")
                }

                // Members Section
                if let error = model.membersError {
                    errorCard(error, title: "Members Error", retryAction: { Task { await model.retryMembers() } })
                } else if !model.members.isEmpty {
                    membersSection
                } else if !model.isLoadingMembers {
                    emptySectionCard(title: "No Patrons", message: "No active patrons found.")
                }
            }
            .appScreenPadding()
        }
    }

    // MARK: - Cards

    private func profileCard(_ identity: PatreonIdentityResponse) -> some View {
        AppCard {
            AppVStack(spacing: .medium, alignment: .leading) {
                HStack {
                    AppText(identity.data.attributes.fullName ?? "Patreon Creator", style: .title2)
                    Spacer()
                    if let url = identity.data.attributes.url {
                        Link(destination: URL(string: url)!) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(AppTheme.ColorToken.accent)
                        }
                    }
                }

                if let email = identity.data.attributes.email {
                    AppText(email, style: .body, color: AppTheme.ColorToken.textSecondary)
                }

                if let vanity = identity.data.attributes.vanity {
                    AppText("@\(vanity)", style: .caption, color: AppTheme.ColorToken.textSecondary)
                }
            }
        }
    }

    private func campaignStatsCard(_ campaign: PatreonCampaign) -> some View {
        AppCard {
            AppVStack(spacing: .medium, alignment: .leading) {
                AppText(campaign.attributes.creationName ?? "Campaign", style: .headline)

                if let summary = campaign.attributes.summary {
                    AppText(summary, style: .body, color: AppTheme.ColorToken.textSecondary)
                        .lineLimit(3)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.medium) {
                    AppMetricCard(
                        title: "Patrons",
                        value: "\(campaign.attributes.patronCount ?? 0)",
                        icon: "person.2",
                        tint: AppTheme.ColorToken.accent
                    )
                    AppMetricCard(
                        title: "Monthly",
                        value: formatCents(campaign.attributes.pledgeSum),
                        icon: "dollarsign.circle",
                        tint: AppTheme.ColorToken.statusSuccess
                    )
                    AppMetricCard(
                        title: "Posts",
                        value: "\(model.posts.count)",
                        icon: "doc.text",
                        tint: AppTheme.ColorToken.statusInfo
                    )
                }
            }
        }
    }

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack {
                AppText("Recent Posts", style: .title3)
                Spacer()
                if model.isLoadingPosts {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: AppTheme.Spacing.medium) {
                    ForEach(model.posts) { post in
                        postCard(post)
                    }
                }
            }
            .frame(maxHeight: 400)
        }
    }

    private func postCard(_ post: PatreonPost) -> some View {
        AppCard {
            AppVStack(spacing: .small, alignment: .leading) {
                HStack {
                    AppText(post.attributes.title ?? "Untitled", style: .headline)
                    Spacer()
                    if post.attributes.isPaid == true {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(AppTheme.ColorToken.accent)
                    } else if post.attributes.isPublic == true {
                        Image(systemName: "globe")
                            .foregroundStyle(AppTheme.ColorToken.statusSuccess)
                    }
                }

                if let published = post.attributes.publishedAt {
                    AppText(formatDate(published), style: .caption, color: AppTheme.ColorToken.textSecondary)
                }

                if let content = post.attributes.content {
                    // Convert HTML to Markdown for rendering
                    Text(AttributedString(htmlString: content, lineLimit: 2))
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.ColorToken.textSecondary)
                }
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack {
                AppText("Active Patrons", style: .title3)
                Spacer()
                if model.isLoadingMembers {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: AppTheme.Spacing.medium) {
                ForEach(model.members.prefix(8)) { member in
                    memberCard(member)
                }
            }
        }
    }

    private func memberCard(_ member: PatreonMember) -> some View {
        AppCard {
            AppVStack(spacing: .small, alignment: .leading) {
                AppText(member.attributes?.fullName ?? "Patron", style: .headline)

                if let status = member.attributes?.patronStatus {
                    AppStatusPill(
                        title: status,
                        color: statusColor(for: status)
                    )
                }

                if let lifetime = member.attributes?.lifetimeSupportCents {
                    AppText("Lifetime: \(formatCents(lifetime))", style: .caption, color: AppTheme.ColorToken.textSecondary)
                }
            }
        }
    }

    private func errorCard(_ error: PatreonError, title: String = "Error", retryAction: @escaping () -> Void) -> some View {
        AppCard {
            AppVStack(spacing: .medium, alignment: .center) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.ColorToken.statusError)

                AppText(title, style: .headline)
                AppText(error.displayMessage, style: .body, color: AppTheme.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)

                if error.isRetryable {
                    Button("Retry") {
                        retryAction()
                    }
                    .appButtonStyle(.bordered)
                }
            }
        }
    }

    private func emptySectionCard(title: String, message: String) -> some View {
        AppCard {
            AppVStack(spacing: .medium, alignment: .center) {
                Image(systemName: "doc.plaintext")
                    .font(.title2)
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)

                AppText(title, style: .headline)
                AppText(message, style: .body, color: AppTheme.ColorToken.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private var hasAnyData: Bool {
        model.identity != nil || !model.posts.isEmpty || !model.members.isEmpty
    }

    private func formatCents(_ cents: Int?) -> String {
        guard let cents = cents else { return "-" }
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    private func formatDate(_ isoString: String) -> String {
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

    private func stripHTML(_ html: String) -> String {
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                  .replacingOccurrences(of: "&quot;", with: "\"")
                  .replacingOccurrences(of: "&amp;", with: "&")
                  .replacingOccurrences(of: "&lt;", with: "<")
                  .replacingOccurrences(of: "&gt;", with: ">")
    }

    private func statusColor(for status: String) -> Color {
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

// MARK: - AttributedString HTML Extension

extension AttributedString {
    init(htmlString: String, lineLimit: Int? = nil) {
        guard let data = htmlString.data(using: .utf8),
              let nsAttributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                         .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
              ) else {
            self.init(htmlString)
            return
        }
        self.init(nsAttributedString)
    }
}
