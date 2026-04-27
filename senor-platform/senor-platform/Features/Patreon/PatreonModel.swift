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

// MARK: - Patreon Model

@MainActor
public final class PatreonModel: ObservableObject {
    // Data states
    @Published public private(set) var identity: PatreonIdentityResponse?
    @Published public private(set) var campaign: PatreonCampaign?
    @Published public private(set) var posts: [PatreonPost] = []
    @Published public private(set) var members: [PatreonMember] = []

    // Granular loading states
    @Published public private(set) var isLoadingProfile = false
    @Published public private(set) var isLoadingPosts = false
    @Published public private(set) var isLoadingMembers = false
    @Published public private(set) var isRefreshingToken = false

    // Granular errors per section
    @Published public private(set) var profileError: PatreonError?
    @Published public private(set) var postsError: PatreonError?
    @Published public private(set) var membersError: PatreonError?

    private let client: PatreonClient?
    private var settings: SettingsService.PatreonSettings?

    init(client: PatreonClient?, settings: SettingsService.PatreonSettings? = nil) {
        self.client = client
        self.settings = settings
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
        if settings.tokenExpiry != nil && settings.tokenExpiry! < Date() {
            return .expired
        }
        return .unauthenticated
    }

    public var hasAnyError: Bool {
        profileError != nil || postsError != nil || membersError != nil
    }

    public var isAnyLoading: Bool {
        isLoadingProfile || isLoadingPosts || isLoadingMembers || isRefreshingToken
    }

    // MARK: - Load Methods

    func load() async {
        await loadProfile()
        await loadPosts()
        await loadMembers()
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
            let campaigns = try await client.getCampaigns()
            campaign = campaigns.data.first
        } catch let error as AppError {
            profileError = mapAppError(error)
        } catch {
            profileError = .unknown(error.localizedDescription)
        }
    }

    func loadPosts() async {
        guard let client = client, client.isAuthenticated else {
            postsError = authState == .expired ? .authExpired : .unauthenticated
            return
        }

        guard let campaignId = campaign?.id ?? settings?.campaignId else {
            postsError = .unknown("No campaign selected")
            return
        }

        isLoadingPosts = true
        postsError = nil
        defer { isLoadingPosts = false }

        do {
            let response = try await client.getCampaignPosts(campaignId: campaignId)
            posts = response.data
        } catch let error as AppError {
            postsError = mapAppError(error)
        } catch {
            postsError = .unknown(error.localizedDescription)
        }
    }

    func loadMembers() async {
        guard let client = client, client.isAuthenticated else {
            membersError = authState == .expired ? .authExpired : .unauthenticated
            return
        }

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
        } catch let error as AppError {
            membersError = mapAppError(error)
        } catch {
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

    // MARK: - Private Helpers

    private func mapAppError(_ error: AppError) -> PatreonError {
        switch error {
        case .apiAuthenticationFailed:
            return .authExpired
        case .apiRequestFailed(_, let underlying):
            if let apiError = underlying as? HTTPClient.APIError {
                if apiError.isRateLimited {
                    return .rateLimited(retryAfter: 60)
                }
                if apiError.isUnauthorized {
                    return .authExpired
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
