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

        enum CodingKeys: String, CodingKey {
            case title
            case amountCents = "amount_cents"
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

    // Granular loading states
    @Published public private(set) var isLoadingProfile = false
    @Published public private(set) var isLoadingPosts = false
    @Published public private(set) var isLoadingMembers = false
    @Published public private(set) var isLoadingTiers = false
    @Published public private(set) var isRefreshingToken = false

    // Granular errors per section
    @Published public private(set) var profileError: PatreonError?
    @Published public private(set) var postsError: PatreonError?
    @Published public private(set) var membersError: PatreonError?
    @Published public private(set) var tiersError: PatreonError?

    private let client: PatreonClient?
    private var settings: SettingsService.PatreonSettings?
    private var hasLoaded = false

    init(client: PatreonClient?, settings: SettingsService.PatreonSettings? = nil) {
        self.client = client
        self.settings = settings
        #if DEBUG
        if client == nil {
            tiers = [
                PatreonTier(id: "tier-1", type: "tier", attributes: .init(title: "Basic", amountCents: 500)),
                PatreonTier(id: "tier-2", type: "tier", attributes: .init(title: "Premium", amountCents: 1500)),
                PatreonTier(id: "tier-3", type: "tier", attributes: .init(title: "VIP", amountCents: 5000))
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

#if DEBUG
extension PatreonViewModel {
    static var preview: PatreonViewModel {
        let vm = PatreonViewModel(client: nil, settings: nil)
        return vm
    }
}
#endif
