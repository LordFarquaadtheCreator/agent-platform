import Foundation
import Combine

// MARK: - Error Types

@MainActor
public enum PatreonError: Error, Equatable {
    case notConfigured
    case unauthenticated
    case authExpired
    case networkFailure(String)
    case rateLimited(retryAfter: Int)
    case decodeError(String)
    case unknown(String)

    public var displayMessage: String {
        switch self {
        case .notConfigured:
            return "Patreon not configured. Add credentials in Settings."

        case .unauthenticated:
            return "Not connected to Patreon. Complete OAuth in Settings."

        case .authExpired:
            return "Session expired. Please reconnect your Patreon account."

        case .networkFailure(let detail):
            return "Connection failed: \(detail)"

        case .rateLimited(let seconds):
            return "Rate limited. Retry in \(seconds)s."

        case .decodeError(let detail):
            return "Data error: \(detail)"

        case .unknown(let detail):
            return "Error: \(detail)"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .networkFailure, .rateLimited, .unknown:
            return true

        case .notConfigured, .unauthenticated, .authExpired, .decodeError:
            return false
        }
    }
}

// MARK: - Auth State

@MainActor
public enum PatreonAuthState: Equatable {
    case notConfigured
    case unauthenticated
    case expired
    case authenticated

    public var displayName: String {
        switch self {
        case .notConfigured: return "Not Configured"
        case .unauthenticated: return "Not Connected"
        case .expired: return "Session Expired"
        case .authenticated: return "Connected"
        }
    }
}

// MARK: - Tier Model

public struct PatreonTier: Identifiable, Codable, Sendable {
    public let id: String
    public let type: String
    public let attributes: TierAttributes

    public struct TierAttributes: Codable, Sendable {
        public let title: String
        public let amountCents: Int?
        // NEW FIELDS
        public let description: String?
        public let discordRoleIds: [String]?
        public let editedAt: String?
        public let patronCount: Int?
        public let published: Bool?
        public let publishedAt: String?
        public let requiresShipping: Bool?
        public let url: String?
        public let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case title
            case amountCents = "amount_cents"
            // NEW
            case description
            case discordRoleIds = "discord_role_ids"
            case editedAt = "edited_at"
            case patronCount = "patron_count"
            case published
            case publishedAt = "published_at"
            case requiresShipping = "requires_shipping"
            case url
            case createdAt = "created_at"
        }
    }
}

// MARK: - Patreon ViewModel

@MainActor
public final class PatreonViewModel: ObservableObject {
    // Data states
    @Published public private(set) var identity: PatreonIdentityResponse?
    @Published public private(set) var campaign: PatreonCampaign?
    @Published public private(set) var posts: [PatreonPost] = []
    @Published public private(set) var members: [PatreonMember] = []
    @Published public private(set) var tiers: [PatreonTier] = []
    @Published public private(set) var selectedPost: PatreonPost?
    @Published public private(set) var selectedMemberDetail: PatreonMember?
    @Published public private(set) var webhooks: [PatreonWebhook] = []

    // Granular loading states
    @Published public private(set) var isLoadingProfile = false
    @Published public private(set) var isLoadingPosts = false
    @Published public private(set) var isLoadingMembers = false
    @Published public private(set) var isLoadingTiers = false
    @Published public private(set) var isRefreshingToken = false
    @Published public private(set) var isLoadingMemberDetail = false
    @Published public private(set) var isLoadingWebhooks = false

    // Granular errors per section
    @Published public private(set) var profileError: PatreonError?
    @Published public private(set) var postsError: PatreonError?
    @Published public private(set) var membersError: PatreonError?
    @Published public private(set) var tiersError: PatreonError?
    @Published public private(set) var memberDetailError: PatreonError?
    @Published public private(set) var webhooksError: PatreonError?

    private let client: PatreonClient?
    private var settings: SettingsService.PatreonSettings?
    private var hasLoaded = false

    init(client: PatreonClient?, settings: SettingsService.PatreonSettings? = nil) {
        self.client = client
        self.settings = settings
        #if DEBUG
        if client == nil {
            tiers = [
                PatreonTier(id: "tier-1", type: "tier", attributes: PatreonTier.TierAttributes(title: "Basic", amountCents: 500, description: nil, discordRoleIds: nil, editedAt: nil, patronCount: nil, published: nil, publishedAt: nil, requiresShipping: nil, url: nil, createdAt: nil)),
                PatreonTier(id: "tier-2", type: "tier", attributes: PatreonTier.TierAttributes(title: "Premium", amountCents: 1500, description: nil, discordRoleIds: nil, editedAt: nil, patronCount: nil, published: nil, publishedAt: nil, requiresShipping: nil, url: nil, createdAt: nil)),
                PatreonTier(id: "tier-3", type: "tier", attributes: PatreonTier.TierAttributes(title: "VIP", amountCents: 5000, description: nil, discordRoleIds: nil, editedAt: nil, patronCount: nil, published: nil, publishedAt: nil, requiresShipping: nil, url: nil, createdAt: nil))
            ]
        }
        #endif
    }

    // MARK: - Computed Properties

    public var authState: PatreonAuthState {
        guard let settings = settings, !settings.accessToken.isEmpty else {
            return .notConfigured
        }
        guard let client = client else {
            return .unauthenticated
        }
        if client.isAuthenticated {
            return .authenticated
        }
        if let expiry = settings.tokenExpiry, expiry < Date() {
            return .expired
        }
        return .unauthenticated
    }

    public var hasAnyError: Bool {
        profileError != nil || postsError != nil || membersError != nil || tiersError != nil
    }

    public var isAnyLoading: Bool {
        isLoadingProfile || isLoadingPosts || isLoadingMembers || isLoadingTiers || isRefreshingToken
    }

    public var isAuthenticated: Bool {
        authState == .authenticated
    }

    func reloadWithNewSettings() {
        // Trigger objectWillChange to refresh auth state
        objectWillChange.send()
    }

    // MARK: - Load Methods

    func load() async {
        guard !hasLoaded && !isLoadingProfile else {
            let skipMsg = "Skipping duplicate load - hasLoaded=\(hasLoaded), isLoadingProfile=\(isLoadingProfile)"
            AppLogger.api.debug(skipMsg)
            return
        }
        hasLoaded = true
        await loadProfile()
        // loadProfile now chains to loadPosts() and loadMembers() after campaign loads
    }

    func refresh() async {
        await loadProfile()
    }

    func loadProfile() async {
        guard let client = client else {
            profileError = .notConfigured
            return
        }

        guard client.isAuthenticated else {
            profileError = authState == .expired ? .authExpired : .unauthenticated
            return
        }

        isLoadingProfile = true
        profileError = nil
        defer { isLoadingProfile = false }

        do {
            identity = try await client.getIdentity()
            AppLogger.api.debug("Identity loaded, fetching campaigns...")
            let campaigns = try await client.getCampaigns()
            AppLogger.api.debug("Campaigns response: \(campaigns.data.count) campaigns")
            if let firstCampaign = campaigns.data.first {
                AppLogger.api.debug("First campaign ID: \(firstCampaign.id)")
                campaign = firstCampaign
                await loadPosts()
                await loadMembers()
                await loadTiers()
            } else {
                AppLogger.api.error("No campaigns found in response")
            }
        } catch let error as AppError {
            AppLogger.api.error("Profile load error: \(error)")
            if case .apiRequestFailed(_, let underlying) = error,
               let apiError = underlying as? HTTPClient.APIError,
               let body = apiError.responseBody,
               let bodyString = String(data: body, encoding: .utf8) {
                AppLogger.api.error("Response body: \(bodyString)")
            }
            profileError = mapAppError(error)
        } catch {
            AppLogger.api.error("Profile load unknown error: \(error)")
            profileError = .unknown(error.localizedDescription)
        }
    }

    func loadPosts() async {
        guard let client = client, client.isAuthenticated else {
            postsError = authState == .expired ? .authExpired : .unauthenticated
            return
        }

        let campaignID = campaign?.id ?? "nil"
        let settingsID = settings?.campaignId ?? "nil"
        let postsMsg = "Posts: campaign.id=\(campaignID), settings.campaignId=\(settingsID)"
        AppLogger.api.debug(postsMsg)
        guard let campaignId = campaign?.id ?? settings?.campaignId else {
            postsError = .unknown("No campaign selected")
            return
        }

        isLoadingPosts = true
        postsError = nil
        defer { isLoadingPosts = false }

        do {
            let response = try await client.getCampaignPosts(campaignId: campaignId)
            // Sort by published date (oldest first)
            let allPosts = response.data.sorted { post1, post2 in
                let date1 = ISO8601DateFormatter().date(from: post1.attributes.publishedAt ?? "") ?? Date.distantPast
                let date2 = ISO8601DateFormatter().date(from: post2.attributes.publishedAt ?? "") ?? Date.distantPast
                return date1 < date2
            }

            // Show first 10 immediately
            let firstBatch = allPosts.prefix(10)
            posts = Array(firstBatch)
            AppLogger.api.debug("Loaded first \(posts.count) posts")

            // Load rest in background after UI update
            if allPosts.count > 10 {
                Task {
                    let secondBatch = Array(allPosts.dropFirst(10))
                    await MainActor.run {
                        posts.append(contentsOf: secondBatch)
                        AppLogger.api.debug("Loaded remaining \(secondBatch.count) posts")
                    }
                }
            }
        } catch let error as AppError {
            AppLogger.api.error("Posts error: \(error)")
            if case .apiRequestFailed(_, let underlying) = error,
               let apiError = underlying as? HTTPClient.APIError,
               let body = apiError.responseBody,
               let bodyString = String(data: body, encoding: .utf8) {
                AppLogger.api.error("Posts response body: \(bodyString)")
            }
            postsError = mapAppError(error)
        } catch {
            AppLogger.api.error("Posts unknown error: \(error)")
            postsError = .unknown(error.localizedDescription)
        }
    }

    func loadMembers() async {
        guard let client = client, client.isAuthenticated else {
            membersError = authState == .expired ? .authExpired : .unauthenticated
            return
        }

        let campaignID = campaign?.id ?? "nil"
        let settingsID = settings?.campaignId ?? "nil"
        let membersMsg = "Members: campaign.id=\(campaignID), settings.campaignId=\(settingsID)"
        AppLogger.api.debug(membersMsg)
        guard let campaignId = campaign?.id ?? settings?.campaignId else {
            membersError = .unknown("No campaign selected")
            return
        }

        isLoadingMembers = true
        membersError = nil
        defer { isLoadingMembers = false }

        do {
            let response = try await client.getCampaignMembers(campaignId: campaignId)
            members = response.data
            AppLogger.api.debug("Loaded \(members.count) members")
            for member in members {
                AppLogger.api.debug("Member: id=\(member.id), name=\(member.attributes?.fullName ?? "nil")")
            }
        } catch let error as AppError {
            AppLogger.api.error("Members error: \(error)")
            membersError = mapAppError(error)
        } catch {
            AppLogger.api.error("Members unknown error: \(error)")
            membersError = .unknown(error.localizedDescription)
        }
    }

    // MARK: - Retry Methods

    func retryProfile() async {
        await loadProfile()
    }

    func retryPosts() async {
        await loadPosts()
    }

    func retryMembers() async {
        await loadMembers()
    }

    func loadTiers() async {
        guard let client = client, client.isAuthenticated else {
            tiersError = authState == .expired ? .authExpired : .unauthenticated
            return
        }

        guard let campaignId = campaign?.id ?? settings?.campaignId else {
            tiersError = .unknown("No campaign selected")
            return
        }

        isLoadingTiers = true
        tiersError = nil
        defer { isLoadingTiers = false }

        do {
            let response = try await client.getCampaignTiers(campaignId: campaignId)
            tiers = response
            AppLogger.api.debug("Loaded \(tiers.count) tiers")
        } catch let error as AppError {
            AppLogger.api.error("Tiers error: \(error)")
            tiersError = mapAppError(error)
        } catch {
            AppLogger.api.error("Tiers unknown error: \(error)")
            tiersError = .unknown(error.localizedDescription)
        }
    }

    func retryTiers() async {
        await loadTiers()
    }

    // MARK: - Webhook Operations

    func loadWebhooks() async {
        guard let client = client, client.isAuthenticated else {
            webhooksError = authState == .expired ? .authExpired : .unauthenticated
            return
        }

        isLoadingWebhooks = true
        webhooksError = nil
        defer { isLoadingWebhooks = false }

        do {
            let response = try await client.getWebhooks()
            webhooks = response
            AppLogger.api.debug("Loaded \(webhooks.count) webhooks")
        } catch let error as AppError {
            AppLogger.api.error("Webhooks error: \(error)")
            webhooksError = mapAppError(error)
        } catch {
            AppLogger.api.error("Webhooks unknown error: \(error)")
            webhooksError = .unknown(error.localizedDescription)
        }
    }

    func retryWebhooks() async {
        await loadWebhooks()
    }

    // MARK: - Member Detail Operations

    func loadMemberDetail(memberId: String) async {
        guard let client = client, client.isAuthenticated else {
            memberDetailError = authState == .expired ? .authExpired : .unauthenticated
            return
        }

        isLoadingMemberDetail = true
        memberDetailError = nil
        defer { isLoadingMemberDetail = false }

        do {
            selectedMemberDetail = try await client.getMember(memberId: memberId)
            AppLogger.api.debug("Loaded member detail for \(memberId)")
        } catch let error as AppError {
            AppLogger.api.error("Member detail error: \(error)")
            memberDetailError = mapAppError(error)
        } catch {
            AppLogger.api.error("Member detail unknown error: \(error)")
            memberDetailError = .unknown(error.localizedDescription)
        }
    }

    func clearSelectedMemberDetail() {
        selectedMemberDetail = nil
        memberDetailError = nil
    }

    // MARK: - Selected Post Details

    @Published public private(set) var isLoadingSelectedPost = false
    @Published public private(set) var selectedPostError: PatreonError?

    /// Load full details for a selected post (refreshes from API)
    func loadSelectedPost(postId: String) async {
        guard let client = client, client.isAuthenticated else {
            selectedPostError = authState == .expired ? .authExpired : .unauthenticated
            return
        }

        // Check if we already have this post locally
        if let localPost = posts.first(where: { $0.id == postId }) {
            selectedPost = localPost
        }

        isLoadingSelectedPost = true
        selectedPostError = nil
        defer { isLoadingSelectedPost = false }

        do {
            // Fetch fresh data from API to get any updates
            let freshPost = try await client.getPost(postId: postId)
            selectedPost = freshPost

            // Also update in posts array if present
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index] = freshPost
            }

            AppLogger.api.debug("Loaded fresh details for post \(postId)")
        } catch let error as AppError {
            AppLogger.api.error("Selected post load error: \(error)")
            selectedPostError = mapAppError(error)
        } catch {
            AppLogger.api.error("Selected post unknown error: \(error)")
            selectedPostError = .unknown(error.localizedDescription)
        }
    }

    func clearSelectedPost() {
        selectedPost = nil
        selectedPostError = nil
    }

    // MARK: - Create & Update Posts

    /// Create a new Patreon post
    func createPost(
        title: String,
        content: String,
        isPaid: Bool = true,
        isPublic: Bool = false,
        tiers: [String]? = nil
    ) async throws {
        guard let client = client else {
            throw PatreonError.notConfigured
        }

        guard client.isAuthenticated else {
            throw PatreonError.unauthenticated
        }

        guard let campaignId = campaign?.id ?? settings?.campaignId else {
            throw PatreonError.unknown("No campaign selected")
        }

        let newPost = try await client.createPost(
            campaignId: campaignId,
            title: title,
            content: content,
            isPaid: isPaid,
            isPublic: isPublic,
            tiers: tiers,
            publishAt: nil
        )

        // Add to local posts for immediate UI feedback
        posts.insert(newPost, at: 0)
    }

    /// Update an existing Patreon post
    func updatePost(
        postId: String,
        title: String? = nil,
        content: String? = nil,
        isPaid: Bool? = nil,
        isPublic: Bool? = nil
    ) async throws {
        guard let client = client else {
            throw PatreonError.notConfigured
        }

        guard client.isAuthenticated else {
            throw PatreonError.unauthenticated
        }

        let updatedPost = try await client.updatePost(
            postId: postId,
            title: title,
            content: content,
            isPaid: isPaid,
            isPublic: isPublic
        )

        // Update local posts array
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index] = updatedPost
        }
    }

    // MARK: - Private Helpers

    private func mapAppError(_ error: AppError) -> PatreonError {
        switch error {
        case .apiAuthenticationFailed:
            return .authExpired

        case .apiResourceNotFound(let resource):
            return .networkFailure("Not found: \(resource)")

        case .apiRequestFailed(_, let underlying):
            if let apiError = underlying as? HTTPClient.APIError {
                if apiError.isRateLimited {
                    return .rateLimited(retryAfter: 60)
                }
                if apiError.isUnauthorized {
                    return .authExpired
                }
                if apiError.isNotFound {
                    return .networkFailure("Resource not found (404)")
                }
                return .networkFailure(apiError.message)
            }
            return .networkFailure(underlying.localizedDescription)

        case .decodingFailed(let message):
            return .decodeError(message)

        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Preview Factories

#if DEBUG
extension PatreonViewModel {
    static var preview: PatreonViewModel {
        .previewNotConfigured
    }

    static var previewNotConfigured: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: nil)
        return vm
    }

    static var previewUnauthenticated: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: .previewUnauthenticated)
        return vm
    }

    static var previewSessionExpired: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: .previewExpired)
        return vm
    }

    static var previewLoadingInitial: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.isLoadingProfile = true
        return vm
    }

    static var previewRefreshing: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign.preview
        vm.posts = [PatreonPost.previewPaid, PatreonPost.previewPublic]
        vm.members = [PatreonMember.previewActive]
        vm.isRefreshingToken = true
        return vm
    }

    static var previewProfileError: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.profileError = PatreonError.networkFailure("Connection timeout")
        return vm
    }

    static var previewPostsError: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign.preview
        vm.postsError = PatreonError.decodeError("Invalid JSON response")
        return vm
    }

    static var previewMembersError: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign.preview
        vm.posts = [PatreonPost.previewPaid]
        vm.membersError = PatreonError.unknown("Internal server error")
        return vm
    }

    static var previewEmptyPosts: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign.preview
        vm.posts = []
        vm.members = [PatreonMember.previewActive, PatreonMember.previewDeclined]
        return vm
    }

    static var previewEmptyMembers: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign.preview
        vm.posts = [PatreonPost.previewPaid, PatreonPost.previewPublic, PatreonPost.previewLongContent]
        vm.members = []
        return vm
    }

    static var previewSinglePost: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign.preview
        vm.posts = [PatreonPost.previewPaid]
        vm.members = [PatreonMember.previewActive]
        return vm
    }

    static var previewManyPosts: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign.preview
        vm.posts = (1...15).map { idx in
            PatreonPost(
                id: "post-\(idx)",
                type: "post",
                attributes: PatreonPost.PatreonPostAttributes(
                    title: "Post Title #\(idx) with some extra length to test truncation",
                    content: idx % 3 == 0 ? nil : "<p>Content for post \(idx)</p>",
                    url: "https://patreon.com/posts/\(idx)",
                    isPaid: idx % 2 == 0,
                    isPublic: idx % 3 == 0,
                    publishedAt: "2026-04-\(String(format: "%02d", idx))T10:00:00.000Z"
                ),
                relationships: nil
            )
        }
        vm.members = (1...8).map { idx in
            PatreonMember(
                id: "member-\(idx)",
                type: "member",
                attributes: PatreonMember.PatreonMemberAttributes(
                    fullName: "Patron Name \(idx)",
                    email: "patron\(idx)@example.com",
                    patronStatus: idx % 4 == 0 ? "declined_patron" : "active_patron",
                    lastChargeStatus: idx % 4 == 0 ? "Declined" : "Paid",
                    lifetimeSupportCents: idx * 1000,
                    currentlyEntitledAmountCents: idx % 3 == 0 ? nil : idx * 100,
                    isFollower: true,
                    lastChargeDate: nil,
                    pledgeRelationshipStart: nil,
                    note: nil
                ),
                relationships: nil
            )
        }
        return vm
    }

    static var previewWithSelection: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign.preview
        vm.posts = [
            PatreonPost.previewPaid,
            PatreonPost.previewPublic,
            PatreonPost(
                id: "preview-post-1",
                type: "post",
                attributes: PatreonPost.PatreonPostAttributes(
                    title: "Selected Post",
                    content: "<p>This post is selected</p>",
                    url: "https://patreon.com/posts/selected",
                    isPaid: true,
                    isPublic: false,
                    publishedAt: "2026-04-26T10:00:00.000Z"
                ),
                relationships: nil
            )
        ]
        vm.members = [
            PatreonMember(
                id: "preview-member-1",
                type: "member",
                attributes: PatreonMember.PatreonMemberAttributes(
                    fullName: "Selected Patron",
                    email: "selected@example.com",
                    patronStatus: "active_patron",
                    lastChargeStatus: "Paid",
                    lifetimeSupportCents: 25000,
                    currentlyEntitledAmountCents: 500,
                    isFollower: true,
                    lastChargeDate: nil,
                    pledgeRelationshipStart: nil,
                    note: nil
                ),
                relationships: nil
            )
        ]
        return vm
    }

    static var previewRateLimited: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.postsError = PatreonError.rateLimited(retryAfter: 60)
        return vm
    }

    static var previewNetworkFailure: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.profileError = PatreonError.networkFailure("Unable to reach Patreon servers")
        return vm
    }

    static var previewLongCampaignName: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign(
            id: "campaign-1",
            type: "campaign",
            attributes: PatreonCampaign.PatreonCampaignAttributes(
                summary: "This is an extremely long campaign name that might cause layout issues",
                creationName: "A Very Long Campaign Name That Tests Truncation and Layout Behavior",
                payPerName: nil,
                thanksMsg: nil,
                thanksVideoUrl: nil,
                imageUrl: nil,
                url: "https://patreon.com/campaign",
                publishedAt: "2024-01-01T00:00:00.000Z",
                patronCount: 150,
                pledgeSum: 50000,
                pledgeSumCurrency: "USD",
                isMonthly: true,
                isChargedImmediately: false,
                isNsfw: false,
                mainVideoEmbed: nil,
                mainVideoUrl: nil,
                oneLiner: nil,
                pledgeUrl: nil,
                thanksEmbed: nil,
                hasRss: false,
                rssFeedTitle: nil,
                rssArtworkUrl: nil,
                googleAnalyticsId: nil,
                discordServerId: nil,
                createdAt: nil
            )
        )
        vm.posts = [PatreonPost.previewPaid]
        vm.members = [PatreonMember.previewActive]
        return vm
    }

    static var previewNoCampaignSummary: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign(
            id: "campaign-1",
            type: "campaign",
            attributes: PatreonCampaign.PatreonCampaignAttributes(
                summary: nil,
                creationName: "Campaign Without Summary",
                payPerName: nil,
                thanksMsg: nil,
                thanksVideoUrl: nil,
                imageUrl: nil,
                url: "https://patreon.com/campaign",
                publishedAt: "2024-01-01T00:00:00.000Z",
                patronCount: 100,
                pledgeSum: 25000,
                pledgeSumCurrency: "USD",
                isMonthly: true,
                isChargedImmediately: false,
                isNsfw: false,
                mainVideoEmbed: nil,
                mainVideoUrl: nil,
                oneLiner: nil,
                pledgeUrl: nil,
                thanksEmbed: nil,
                hasRss: false,
                rssFeedTitle: nil,
                rssArtworkUrl: nil,
                googleAnalyticsId: nil,
                discordServerId: nil,
                createdAt: nil
            )
        )
        return vm
    }

    static var previewZeroPatrons: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign(
            id: "campaign-1",
            type: "campaign",
            attributes: PatreonCampaign.PatreonCampaignAttributes(
                summary: "New campaign just starting out",
                creationName: "Fresh Campaign",
                payPerName: nil,
                thanksMsg: nil,
                thanksVideoUrl: nil,
                imageUrl: nil,
                url: "https://patreon.com/fresh",
                publishedAt: "2026-04-01T00:00:00.000Z",
                patronCount: 0,
                pledgeSum: 0,
                pledgeSumCurrency: "USD",
                isMonthly: true,
                isChargedImmediately: false,
                isNsfw: false,
                mainVideoEmbed: nil,
                mainVideoUrl: nil,
                oneLiner: nil,
                pledgeUrl: nil,
                thanksEmbed: nil,
                hasRss: false,
                rssFeedTitle: nil,
                rssArtworkUrl: nil,
                googleAnalyticsId: nil,
                discordServerId: nil,
                createdAt: nil
            )
        )
        vm.posts = [PatreonPost.previewPublic]
        vm.members = []
        return vm
    }

    static var previewHighEarnings: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign(
            id: "campaign-1",
            type: "campaign",
            attributes: PatreonCampaign.PatreonCampaignAttributes(
                summary: "Very successful campaign",
                creationName: "Top Creator",
                payPerName: nil,
                thanksMsg: nil,
                thanksVideoUrl: nil,
                imageUrl: nil,
                url: "https://patreon.com/top",
                publishedAt: "2020-01-01T00:00:00.000Z",
                patronCount: 50000,
                pledgeSum: 99999999,
                pledgeSumCurrency: "USD",
                isMonthly: true,
                isChargedImmediately: false,
                isNsfw: false,
                mainVideoEmbed: nil,
                mainVideoUrl: nil,
                oneLiner: nil,
                pledgeUrl: nil,
                thanksEmbed: nil,
                hasRss: false,
                rssFeedTitle: nil,
                rssArtworkUrl: nil,
                googleAnalyticsId: nil,
                discordServerId: nil,
                createdAt: nil
            )
        )
        vm.posts = (1...50).map { _ in PatreonPost.previewPaid }
        return vm
    }

    static var previewMixedVisibility: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: SettingsService.PatreonSettings.previewAuthenticated)
        vm.identity = PatreonIdentityResponse.preview
        vm.campaign = PatreonCampaign.preview
        vm.posts = [
            PatreonPost.previewPaid,
            PatreonPost.previewPublic,
            PatreonPost.previewFree,
            PatreonPost(
                id: "post-draft",
                type: "post",
                attributes: PatreonPost.PatreonPostAttributes(
                    title: "Draft Post",
                    content: "<p>Unpublished draft content</p>",
                    url: nil,
                    isPaid: nil,
                    isPublic: nil,
                    publishedAt: nil
                ),
                relationships: nil
            )
        ]
        return vm
    }

    // ComposeView previews
    static var previewWithTiers: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: nil)
        vm.tiers = [
            PatreonTier(id: "tier-1", type: "tier", attributes: PatreonTier.TierAttributes(title: "Basic", amountCents: 500, description: nil, discordRoleIds: nil, editedAt: nil, patronCount: nil, published: nil, publishedAt: nil, requiresShipping: nil, url: nil, createdAt: nil)),
            PatreonTier(id: "tier-2", type: "tier", attributes: PatreonTier.TierAttributes(title: "Premium", amountCents: 1500, description: nil, discordRoleIds: nil, editedAt: nil, patronCount: nil, published: nil, publishedAt: nil, requiresShipping: nil, url: nil, createdAt: nil)),
            PatreonTier(id: "tier-3", type: "tier", attributes: PatreonTier.TierAttributes(title: "VIP", amountCents: 5000, description: nil, discordRoleIds: nil, editedAt: nil, patronCount: nil, published: nil, publishedAt: nil, requiresShipping: nil, url: nil, createdAt: nil))
        ]
        return vm
    }

    static var previewNoTiers: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: nil)
        vm.tiers = []
        return vm
    }

    static var previewManyTiers: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: nil)
        vm.tiers = (1...10).map { idx in
            PatreonTier(
                id: "tier-\(idx)",
                type: "tier",
                attributes: PatreonTier.TierAttributes(
                    title: "Tier Level \(idx) with Long Name",
                    amountCents: idx * 500,
                    description: nil,
                    discordRoleIds: nil,
                    editedAt: nil,
                    patronCount: nil,
                    published: nil,
                    publishedAt: nil,
                    requiresShipping: nil,
                    url: nil,
                    createdAt: nil
                )
            )
        }
        return vm
    }
}

// Preview data for SettingsService.PatreonSettings
extension SettingsService.PatreonSettings {
    static var previewUnauthenticated: SettingsService.PatreonSettings {
        SettingsService.PatreonSettings(
            accessToken: "",
            refreshToken: nil,
            campaignId: nil,
            tokenExpiry: nil
        )
    }

    static var previewExpired: SettingsService.PatreonSettings {
        SettingsService.PatreonSettings(
            accessToken: "expired_token",
            refreshToken: "refresh_token",
            campaignId: "campaign-1",
            tokenExpiry: Date().addingTimeInterval(-3600)
        )
    }

    static var previewAuthenticated: SettingsService.PatreonSettings {
        SettingsService.PatreonSettings(
            accessToken: "valid_token",
            refreshToken: "refresh_token",
            campaignId: "campaign-1",
            tokenExpiry: Date().addingTimeInterval(3600)
        )
    }
}

// Preview data for PatreonIdentityResponse
extension PatreonIdentityResponse {
    static var preview: PatreonIdentityResponse {
        PatreonIdentityResponse(
            data: PatreonUser(
                id: "user-1",
                type: "user",
                attributes: .init(
                    email: "creator@example.com",
                    firstName: "Jane",
                    fullName: "Jane Creator",
                    imageUrl: "https://example.com/avatar.jpg",
                    thumbUrl: "https://example.com/thumb.jpg",
                    url: "https://patreon.com/janecreator",
                    vanity: "janecreator",
                    about: "Digital artist and creator",
                    created: "2020-01-01T00:00:00.000Z",
                    lastName: "Creator",
                    socialConnections: nil
                )
            )
        )
    }
}

// Preview data for PatreonCampaign
extension PatreonCampaign {
    static var preview: PatreonCampaign {
        PatreonCampaign(
            id: "campaign-1",
            type: "campaign",
            attributes: .init(
                summary: "Creating amazing digital art and tutorials",
                creationName: "Digital Art Studio",
                payPerName: nil,
                thanksMsg: "Thank you for your support!",
                thanksVideoUrl: nil,
                imageUrl: "https://example.com/campaign.jpg",
                url: "https://patreon.com/digitalartstudio",
                publishedAt: "2020-06-15T00:00:00.000Z",
                patronCount: 250,
                pledgeSum: 125000,
                pledgeSumCurrency: "USD",
                isMonthly: true,
                isChargedImmediately: false,
                isNsfw: false,
                mainVideoEmbed: nil,
                mainVideoUrl: nil,
                oneLiner: "Art for everyone",
                pledgeUrl: nil,
                thanksEmbed: nil,
                hasRss: true,
                rssFeedTitle: "Digital Art Studio Feed",
                rssArtworkUrl: nil,
                googleAnalyticsId: nil,
                discordServerId: nil,
                createdAt: "2020-06-01T00:00:00.000Z"
            )
        )
    }
}

// Preview data for PatreonPost
extension PatreonPost {
    static var previewPaid: PatreonPost {
        PatreonPost(
            id: "preview-post-paid",
            type: "post",
            attributes: .init(
                title: "Exclusive Tutorial: Advanced Shading",
                content: "<p>In this exclusive tutorial, we'll explore advanced shading techniques...</p>",
                url: "https://patreon.com/posts/tutorial-123",
                isPaid: true,
                isPublic: false,
                publishedAt: "2026-04-26T10:00:00.000Z"
            ),
            relationships: nil
        )
    }

    static var previewPublic: PatreonPost {
        PatreonPost(
            id: "preview-post-public",
            type: "post",
            attributes: .init(
                title: "Free Art Pack Available",
                content: "<p>Everyone can download this free art pack!</p>",
                url: "https://patreon.com/posts/free-pack-456",
                isPaid: false,
                isPublic: true,
                publishedAt: "2026-04-25T14:30:00.000Z"
            ),
            relationships: nil
        )
    }

    static var previewFree: PatreonPost {
        PatreonPost(
            id: "preview-post-free",
            type: "post",
            attributes: .init(
                title: "Free for All Patrons",
                content: "<p>This post is free for all patrons, not just paid ones.</p>",
                url: "https://patreon.com/posts/free-patron-789",
                isPaid: false,
                isPublic: false,
                publishedAt: "2026-04-24T09:00:00.000Z"
            ),
            relationships: nil
        )
    }

    static var previewLongContent: PatreonPost {
        PatreonPost(
            id: "preview-post-long",
            type: "post",
            attributes: .init(
                title: "Very Long Post Title That Tests Layout and Truncation Behavior in the UI",
                content: """
                <p>This is a very long content section that contains multiple paragraphs.</p>
                <p>Second paragraph with <strong>bold text</strong> and <em>italic text</em>.</p>
                <p>Third paragraph with a <a href="https://example.com">link</a>.</p>
                <ul>
                    <li>List item one</li>
                    <li>List item two</li>
                    <li>List item three with more text</li>
                </ul>
                """,
                url: "https://patreon.com/posts/long-post",
                isPaid: true,
                isPublic: false,
                publishedAt: "2026-04-20T08:00:00.000Z"
            ),
            relationships: nil
        )
    }
}

// Preview data for PatreonMember
extension PatreonMember {
    static var previewActive: PatreonMember {
        PatreonMember(
            id: "preview-member-active",
            type: "member",
            attributes: .init(
                fullName: "Alice Active",
                email: "alice@example.com",
                patronStatus: "active_patron",
                lastChargeStatus: "Paid",
                lifetimeSupportCents: 50000,
                currentlyEntitledAmountCents: 1000,
                isFollower: true,
                lastChargeDate: "2026-04-25T00:00:00.000Z",
                pledgeRelationshipStart: "2024-01-15T00:00:00.000Z",
                note: "Great supporter!"
            ),
            relationships: nil
        )
    }

    static var previewDeclined: PatreonMember {
        PatreonMember(
            id: "preview-member-declined",
            type: "member",
            attributes: .init(
                fullName: "Bob Declined",
                email: "bob@example.com",
                patronStatus: "declined_patron",
                lastChargeStatus: "Declined",
                lifetimeSupportCents: 15000,
                currentlyEntitledAmountCents: 500,
                isFollower: true,
                lastChargeDate: "2026-04-01T00:00:00.000Z",
                pledgeRelationshipStart: "2025-01-01T00:00:00.000Z",
                note: nil
            ),
            relationships: nil
        )
    }

    static var previewFormer: PatreonMember {
        PatreonMember(
            id: "preview-member-former",
            type: "member",
            attributes: .init(
                fullName: "Charlie Former",
                email: "charlie@example.com",
                patronStatus: "former_patron",
                lastChargeStatus: nil,
                lifetimeSupportCents: 25000,
                currentlyEntitledAmountCents: nil,
                isFollower: false,
                lastChargeDate: "2025-12-01T00:00:00.000Z",
                pledgeRelationshipStart: "2024-06-01T00:00:00.000Z",
                note: nil
            ),
            relationships: nil
        )
    }

    static var previewNoEmail: PatreonMember {
        PatreonMember(
            id: "preview-member-noemail",
            type: "member",
            attributes: .init(
                fullName: "Dana NoEmail",
                email: nil,
                patronStatus: "active_patron",
                lastChargeStatus: "Paid",
                lifetimeSupportCents: 10000,
                currentlyEntitledAmountCents: 500,
                isFollower: true,
                lastChargeDate: "2026-04-26T00:00:00.000Z",
                pledgeRelationshipStart: "2025-03-01T00:00:00.000Z",
                note: nil
            ),
            relationships: nil
        )
    }
}
#endif
