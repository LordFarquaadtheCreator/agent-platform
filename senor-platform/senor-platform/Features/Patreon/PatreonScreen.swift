import SwiftUI
import MarkdownUI

struct PatreonScreen: View {
    @ObservedObject var viewModel: PatreonViewModel
    @ObservedObject var router: AppRouter
    @ObservedObject var connectivityService: ConnectivityService

    var body: some View {
        VStack(spacing: 0) {
            header

            AppDivider()

            if viewModel.isAnyLoading && !hasAnyData {
                LoadingStateView(
                    message: viewModel.isRefreshingToken ? "Refreshing session..." : nil
                )
            } else if !connectivityService.isOnline {
                OfflineView(serviceName: "Patreon") {
                    Task { await viewModel.refresh() }
                }
            } else if case .notConfigured = viewModel.authState {
                NotConnectedView(
                    title: "Patreon Not Configured",
                    systemImage: "heart",
                    message: "Add your Patreon access token in Settings to see your campaign, posts, and patrons."
                )
            } else if case .expired = viewModel.authState {
                ErrorStateView(
                    title: "Session Expired",
                    message: "Your Patreon session has expired. Please reconnect your account in Settings."
                )
            } else {
                contentScrollView
            }
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task { await viewModel.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(spacing: AppTheme.Spacing.medium) {
                AppSectionHeader(
                    title: "Patreon",
                    detail: viewModel.identity?.data.attributes.fullName ?? viewModel.identity?.data.attributes.vanity
                )
                Spacer()
                if viewModel.isAnyLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, AppTheme.Spacing.small)
                }

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: AppTheme.Icon.refresh)
                }
                .disabled(viewModel.isAnyLoading)
            }

			authStatePill
        }
		.padding(AppTheme.Spacing.screenPadding)
	}

    private var authStatePill: some View {
        let (text, color): (String, Color) = {
            switch viewModel.authState {
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

    // MARK: - Content

    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                // Profile/Campaign Card
                if let error = viewModel.profileError {
                    errorCard(error) { Task { await viewModel.retryProfile() } }
                } else if let identity = viewModel.identity {
                    profileCard(identity)
                }

                // Stats Card (NEW)
                statsCard

                // Notifications Section
                notificationsSection

                // Posts Section (restructured)
                if let error = viewModel.postsError {
                    errorCard(error, title: "Posts Error") { Task { await viewModel.retryPosts() } }
                } else if !viewModel.posts.isEmpty {
                    postsSection
                } else if !viewModel.isLoadingPosts {
                    emptySectionCard(title: "No Posts", message: "No posts found for this campaign.")
                }

                // Members Section (restructured)
                if let error = viewModel.membersError {
                    errorCard(error, title: "Members Error") { Task { await viewModel.retryMembers() } }
                } else if !viewModel.members.isEmpty {
                    membersSection
                } else if !viewModel.isLoadingMembers {
                    emptySectionCard(title: "No Patrons", message: "No active patrons found.")
                }
            }
            .appScreenPadding()
        }
    }

    // MARK: - Cards

    private func profileCard(_ identity: PatreonIdentityResponse) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack {
                    AppText(identity.data.attributes.fullName ?? "Patreon Creator", style: .title2)
                    Spacer()
                    if let urlString = identity.data.attributes.url,
                       let url = URL(string: urlString) {
                        Link(destination: url) {
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
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                AppText(campaign.attributes.creationName ?? "Campaign", style: .headline)

                if let summary = campaign.attributes.summary {
                    Markdown(summary)
                        .markdownTheme(.app)
						.foregroundStyle(AppTheme.ColorToken.textSecondary)
                        .lineLimit(3)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: AppTheme.Spacing.medium
                ) {
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
                        value: "\(viewModel.posts.count)",
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
                AppText("Posts", style: .title3)
                Spacer()
                if viewModel.isLoadingPosts {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: AppTheme.Spacing.medium
                ) {
                    ForEach(viewModel.posts) { post in
                        postCardSquare(post)
                    }
                }
            }
            .frame(height: 400) // Fixed height as per sketch
        }
    }

    private func postCard(_ post: PatreonPost) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
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
                    // Convert HTML to Markdown and render
                    let markdownContent = HTMLUtils.toMarkdown(content)
                    Markdown(markdownContent)
                        .markdownTheme(.app)
                        .lineLimit(4)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                .stroke(
                    router.selectedPostID == post.id
                        ? AppTheme.ColorToken.accent
                        : AppTheme.ColorToken.clear,
                    lineWidth: 2
                )
        )
        .onTapGesture {
            router.selectedPostID = post.id
            router.selectedMemberID = nil
            Task { await viewModel.loadSelectedPost(postId: post.id) }
        }
    }

    private func postCardSquare(_ post: PatreonPost) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                // Optional image placeholder
                Rectangle()
                    .fill(AppTheme.ColorToken.chromeBackground)
                    .frame(height: 100)
                    .overlay {
                        if let _ = post.attributes.content {
                            // Image would be extracted from content HTML
                            // For now, placeholder
                            Image(systemName: "photo")
                                .foregroundStyle(AppTheme.ColorToken.textSecondary)
                        }
                    }

                AppText(post.attributes.title ?? "Untitled", style: .headline)
                    .lineLimit(2)

                if let published = post.attributes.publishedAt {
                    AppText(formatDate(published), style: .caption, color: AppTheme.ColorToken.textSecondary)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                .stroke(
                    router.selectedPostID == post.id
                        ? AppTheme.ColorToken.accent
                        : AppTheme.ColorToken.clear,
                    lineWidth: 2
                )
        )
        .onTapGesture {
            router.selectedPostID = post.id
            router.selectedMemberID = nil
            Task { await viewModel.loadSelectedPost(postId: post.id) }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack {
                AppText("Patrons", style: .title3)
                Spacer()
                if viewModel.isLoadingMembers {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            // Filter tabs
            Picker("Filter", selection: $memberFilter) {
                Text("Active").tag(MemberFilter.active)
                Text("Inactive").tag(MemberFilter.inactive)
                Text("All").tag(MemberFilter.all)
            }
            .pickerStyle(.segmented)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: AppTheme.Spacing.small) {
                    ForEach(filteredMembers) { member in
                        memberCard(member)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }

    @State private var memberFilter: MemberFilter = .active

    private enum MemberFilter {
        case active, inactive, all
    }

    private var filteredMembers: [PatreonMember] {
        switch memberFilter {
        case .active:
            return viewModel.members.filter { $0.attributes?.patronStatus == "active_patron" }
        case .inactive:
            return viewModel.members.filter { $0.attributes?.patronStatus != "active_patron" }
        case .all:
            return viewModel.members
        }
    }

    private func memberCard(_ member: PatreonMember) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                AppText(member.attributes?.fullName ?? "Patron", style: .headline)

                if let status = member.attributes?.patronStatus {
                    AppStatusPill(
                        title: status,
                        color: statusColor(for: status)
                    )
                }

                if let lifetime = member.attributes?.lifetimeSupportCents {
                    let centsText = formatCents(lifetime)
                    AppText("Lifetime: \(centsText)", style: .caption, color: AppTheme.ColorToken.textSecondary)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                .stroke(
                    router.selectedMemberID == member.id
                        ? AppTheme.ColorToken.accent
                        : AppTheme.ColorToken.clear,
                    lineWidth: 2
                )
        )
        .onTapGesture {
            router.selectedMemberID = member.id
            router.selectedPostID = nil
        }
    }

    private func errorCard(
        _ error: PatreonError,
        title: String = "Error",
        retryAction: @escaping () -> Void
    ) -> some View {
        AppCard {
            VStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(AppTheme.Typography.title2)
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

    private var statsCard: some View {
        PatreonStatsCard(
            totalPatrons: viewModel.totalPatrons,
            activePatrons: viewModel.activePatrons,
            totalRevenue: formatCents(viewModel.totalRevenueCents),
            monthlyRevenue: formatCents(viewModel.monthlyRevenueCents),
            statsHistory: viewModel.statsHistory
        )
    }

    private var notificationsSection: some View {
        PatreonNotificationsView(events: viewModel.pledgeEvents)
    }

    private func emptySectionCard(title: String, message: String) -> some View {
        AppCard {
            VStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                Image(systemName: "doc.plaintext")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)

                AppText(title, style: .headline)
                AppText(message, style: .body, color: AppTheme.ColorToken.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private var hasAnyData: Bool {
        viewModel.identity != nil || !viewModel.posts.isEmpty || !viewModel.members.isEmpty
    }

    private func formatCents(_ cents: Int?) -> String {
        PatreonFormatters.formatCents(cents)
    }

    private func formatDate(_ isoString: String) -> String {
        PatreonFormatters.formatDate(isoString)
    }

    private func statusColor(for status: String) -> Color {
        PatreonFormatters.statusColor(for: status)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Not Configured") {
	PatreonScreen(
		viewModel: previewPatreonViewModel(isAuthenticated: false),
		router: AppRouter(),
		connectivityService: ConnectivityService()
	)
}

#Preview("Empty") {
	PatreonScreen(
		viewModel: previewPatreonViewModel(postCount: 0, memberCount: 0),
		router: AppRouter(),
		connectivityService: ConnectivityService()
	)
}

#Preview("Single") {
	PatreonScreen(
		viewModel: previewPatreonViewModel(postCount: 1, memberCount: 1),
		router: AppRouter(),
		connectivityService: ConnectivityService()
	)
}

#Preview("Many") {
	PatreonScreen(
		viewModel: previewPatreonViewModel(postCount: 15, memberCount: 8),
		router: AppRouter(),
		connectivityService: ConnectivityService()
	)
}

#Preview("Selected Post") {
	let router = AppRouter()
	router.selectedPostID = "post-0"
	return PatreonScreen(
		viewModel: previewPatreonViewModel(postCount: 5),
		router: router,
		connectivityService: ConnectivityService()
	)
}

#Preview("Selected Member") {
	let router = AppRouter()
	router.selectedMemberID = "member-0"
	return PatreonScreen(
		viewModel: previewPatreonViewModel(memberCount: 5),
		router: router,
		connectivityService: ConnectivityService()
	)
}
#endif

// MARK: - AttributedString HTML Extension

extension AttributedString {
    init(htmlString: String, lineLimit: Int? = nil) {
        guard let data = htmlString.data(using: .utf8),
              let nsAttributedString = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            self.init(htmlString)
            return
        }
        self.init(nsAttributedString)
    }
}
