import Foundation

// MARK: - Response Types (defined outside class to avoid main actor isolation issues)

public struct PatreonCampaign: Codable, Identifiable {
    public let id: String
    public let type: String
    public let attributes: PatreonCampaignAttributes

    public struct PatreonCampaignAttributes: Codable, Sendable {
        public let summary: String?
        public let creationName: String?
        public let payPerName: String?
        public let thanksMsg: String?
        public let thanksVideoUrl: String?
        public let imageUrl: String?
        public let url: String?
        public let publishedAt: String?
        public let patronCount: Int?
        public let pledgeSum: Int?
        public let pledgeSumCurrency: String?

        enum CodingKeys: String, CodingKey {
            case summary
            case creationName = "creation_name"
            case payPerName = "pay_per_name"
            case thanksMsg = "thanks_msg"
            case thanksVideoUrl = "thanks_video_url"
            case imageUrl = "image_url"
            case url
            case publishedAt = "published_at"
            case patronCount = "patron_count"
            case pledgeSum = "pledge_sum"
            case pledgeSumCurrency = "pledge_sum_currency"
        }
    }
}

public struct PatreonCampaignsResponse: Codable {
    public let data: [PatreonCampaign]
    public let included: [PatreonIncludedResource]?
    public let meta: PatreonPaginationMeta?
}

public struct PatreonPost: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let attributes: PatreonPostAttributes
    public let relationships: PatreonPostRelationships?

    public struct PatreonPostAttributes: Codable, Sendable {
        public let title: String?
        public let content: String?
        public let url: String?
        public let isPaid: Bool?
        public let isPublic: Bool?
        public let publishedAt: String?

        enum CodingKeys: String, CodingKey {
            case title
            case content
            case url
            case isPaid = "is_paid"
            case isPublic = "is_public"
            case publishedAt = "published_at"
        }
    }

    public struct PatreonPostRelationships: Codable, Sendable {
        public let campaign: PatreonRelationship?
        public let tiers: PatreonTiersRelationship?

        public struct PatreonRelationship: Codable, Sendable {
            public let data: PatreonRelationshipData?
        }

        public struct PatreonTiersRelationship: Codable, Sendable {
            public let data: [PatreonRelationshipData]?
        }

        public struct PatreonRelationshipData: Codable, Sendable {
            public let id: String
            public let type: String
        }
    }
}

public struct PatreonPostsResponse: Codable {
    public let data: [PatreonPost]
    public let included: [PatreonIncludedResource]?
    public let meta: PatreonPaginationMeta?
}

public struct PatreonMember: Codable, Identifiable {
    public let id: String
    public let type: String
    public let attributes: PatreonMemberAttributes?
    public let relationships: PatreonMemberRelationships?

    public struct PatreonMemberAttributes: Codable, Sendable {
        public let fullName: String?
        public let email: String?
        public let patronStatus: String?
        public let lastChargeStatus: String?
        public let lifetimeSupportCents: Int?
        public let currentlyEntitledAmountCents: Int?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
            case email
            case patronStatus = "patron_status"
            case lastChargeStatus = "last_charge_status"
            case lifetimeSupportCents = "lifetime_support_cents"
            case currentlyEntitledAmountCents = "currently_entitled_amount_cents"
        }
    }

    public struct PatreonMemberRelationships: Codable, Sendable {
        public let currentlyEntitledTiers: [PatreonTierData]?
    }

    public struct PatreonTierData: Codable, Sendable {
        public let id: String
        public let type: String
    }
}

public struct PatreonMembersResponse: Codable {
    public let data: [PatreonMember]
    public let included: [PatreonIncludedResource]?
    public let meta: PatreonPaginationMeta?
}

public struct PatreonTiersResponse: Codable {
    public let data: [PatreonTier]
    public let meta: PatreonPaginationMeta?
}

public struct PatreonCampaignResponse: Codable {
    public let data: PatreonCampaign
    public let included: [PatreonIncludedResource]?
}

public struct PatreonIncludedResource: Codable {
    public let id: String
    public let type: String
    public let attributes: PatreonIncludedAttributes?
}

public struct PatreonIncludedAttributes: Codable {
    public let title: String?
    public let url: String?
    public let amountCents: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case amountCents = "amount_cents"
    }
}

public struct PatreonPaginationMeta: Codable {
    public let pagination: PatreonPaginationCursors?
}

public struct PatreonPaginationCursors: Codable {
    public let cursors: PatreonCursors?
}

public struct PatreonCursors: Codable {
    public let next: String?
}

public struct PatreonIdentityResponse: Codable {
    public let data: PatreonUser

    public struct PatreonUser: Codable, Sendable, Identifiable {
        public let id: String
        public let type: String
        public let attributes: PatreonUserAttributes

        public struct PatreonUserAttributes: Codable, Sendable {
            public let email: String?
            public let firstName: String?
            public let fullName: String?
            public let imageUrl: String?
            public let thumbUrl: String?
            public let url: String?
            public let vanity: String?
        }
    }
}

// MARK: - Patreon Client

/// Comprehensive Patreon API client
/// API Docs: https://docs.patreon.com/
public final class PatreonClient {
    private let httpClient: HTTPClient
    private let logger = AppLogger.api

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let clientId: String
        public let clientSecret: String
        public let redirectURI: String

        public init(clientId: String, clientSecret: String, redirectURI: String) {
            self.clientId = clientId
            self.clientSecret = clientSecret
            self.redirectURI = redirectURI
        }
    }

    // MARK: - API Endpoints

    private enum Endpoints {
        static let base = "https://www.patreon.com/api/oauth2/v2"
        static let auth = "https://www.patreon.com/oauth2/authorize"
        static let token = "https://www.patreon.com/api/oauth2/token"

        static let identity = "\(base)/identity"
        static let campaigns = "\(base)/campaigns"
        static func campaign(campaignId: String) -> String { "\(base)/campaigns/\(campaignId)" }
        static func campaignMembers(campaignId: String) -> String { "\(base)/campaigns/\(campaignId)/members" }
        static func campaignPosts(campaignId: String) -> String { "\(base)/campaigns/\(campaignId)/posts" }
        static func campaignTiers(campaignId: String) -> String { "\(base)/campaigns/\(campaignId)/tiers" }
        static func post(postId: String) -> String { "\(base)/posts/\(postId)" }
        static let posts = "\(base)/posts"
    }

    // MARK: - Type Aliases for Response Types
    public typealias IdentityResponse = PatreonIdentityResponse
    public typealias Campaign = PatreonCampaign
    public typealias CampaignsResponse = PatreonCampaignsResponse
    public typealias Post = PatreonPost
    public typealias PostsResponse = PatreonPostsResponse
    public typealias Member = PatreonMember
    public typealias MembersResponse = PatreonMembersResponse

    // MARK: - Initialization

    private let oauthHelper: OAuthHelper
    private var authToken: HTTPClient.AuthToken?

    public init(configuration: Configuration, httpClient: HTTPClient) async {
        self.httpClient = httpClient
        // URLs are hardcoded valid strings; use nil-coalescing with force unwrap for fallback
        guard let authURL = URL(string: Endpoints.auth) ?? URL(string: "https://www.patreon.com/oauth2/authorize"),
              let tokenURL = URL(string: Endpoints.token) ?? URL(string: "https://www.patreon.com/api/oauth2/token")
        else {
            fatalError("Invalid Patreon OAuth URLs")
        }
        let helper = OAuthHelper(
            clientId: configuration.clientId,
            clientSecret: configuration.clientSecret,
            redirectURI: configuration.redirectURI,
            authURL: authURL,
            tokenURL: tokenURL,
            httpClient: httpClient
        )
        self.oauthHelper = helper
    }

    // MARK: - OAuth

    /// Generate authorization URL for OAuth flow
    public func authorizationURL(
        scopes: [String] = ["identity", "identity.memberships", "campaigns", "w:campaigns.post"],
        state: String = UUID().uuidString
    ) async throws -> URL {
        try await oauthHelper.authorizationURL(scopes: scopes, state: state)
    }

    /// Exchange authorization code for access token
    public func exchangeCodeForToken(code: String) async throws {
        authToken = try await oauthHelper.exchangeCodeForToken(code: code)
        logger.info("Successfully authenticated with Patreon")
    }

    /// Refresh the access token
    public func refreshToken() async throws {
        guard let currentToken = authToken, let refreshToken = currentToken.refreshToken else {
            throw AppError.apiAuthenticationFailed("Patreon: No refresh token available")
        }
        authToken = try await oauthHelper.refreshToken(refreshToken: refreshToken)
        logger.debug("Patreon token refreshed")
    }

    /// Check if we have a valid auth token
    public var isAuthenticated: Bool {
        guard let token = authToken else { return false }
        return !token.isExpired
    }

    /// Inject an existing auth token (e.g., loaded from Keychain on startup)
    public func setAuthToken(_ token: HTTPClient.AuthToken) {
        authToken = token
    }

    // MARK: - Identity/User Operations

    /// Get current user's identity
    public func getIdentity(
        fields: [String] = ["email", "first_name", "full_name", "image_url", "url", "vanity"]
    ) async throws -> IdentityResponse {
        try ensureAuthenticated()

        let fieldsParam = fields.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[user]", value: fieldsParam)
        ]

        if URL(string: Endpoints.identity) != nil {
            let response = try await httpClient.request(
                method: .get,
                path: Endpoints.identity,
                queryItems: queryItems,
                authToken: authToken,
                decodeAs: IdentityResponse.self
            )
            return response.data
        } else {
            throw AppError.invalidConfiguration("Invalid Patreon identity endpoint")
        }
    }

    // MARK: - Campaign Operations

    /// Get all campaigns for the current user
    public func getCampaigns(
        includeFields: [String] = ["creation_name", "patron_count"]
    ) async throws -> CampaignsResponse {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[campaign]", value: fieldsParam)
        ]

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.campaigns,
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: CampaignsResponse.self
        )

        logger.debug("Campaigns data count: \(response.data.data.count)")
        for campaign in response.data.data {
            logger.debug("Campaign ID: \(campaign.id), attributes: \(campaign.attributes)")
        }

        return response.data
    }

    /// Get a specific campaign by ID
    public func getCampaign(
        campaignId: String,
        includeFields: [String] = ["summary", "creation_name", "image_url", "url", "published_at"]
    ) async throws -> Campaign {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[campaign]", value: fieldsParam)
        ]

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.campaign(campaignId: campaignId),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: Campaign.self
        )

        return response.data
    }

    /// Get tiers for a campaign
    public func getCampaignTiers(
        campaignId: String,
        includeFields: [String] = ["title", "amount_cents"]
    ) async throws -> [PatreonTier] {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "include", value: "tiers"),
            URLQueryItem(name: "fields[tier]", value: fieldsParam)
        ]

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.campaign(campaignId: campaignId),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: PatreonCampaignResponse.self
        )

        return response.data.included?.filter { $0.type == "tier" }.map { resource in
            PatreonTier(
                id: resource.id,
                type: resource.type,
                attributes: .init(
                    title: resource.attributes?.title ?? "Untitled",
                    amountCents: resource.attributes?.amountCents
                )
            )
        } ?? []
    }

    // MARK: - Post Operations

    /// Get all posts for a campaign
    public func getCampaignPosts(
        campaignId: String,
        includeFields: [String] = ["title", "content", "is_paid", "is_public", "published_at", "url"],
        cursor: String? = nil
    ) async throws -> PostsResponse {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[post]", value: fieldsParam),
            URLQueryItem(name: "fields[campaign]", value: "url")
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "page[cursor]", value: cursor))
        }

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.campaignPosts(campaignId: campaignId),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: PostsResponse.self
        )

        return response.data
    }

    /// Get a specific post by ID
    public func getPost(
        postId: String,
        includeFields: [String] = ["title", "content", "is_paid", "is_public", "published_at", "url"]
    ) async throws -> Post {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[post]", value: fieldsParam)
        ]

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.post(postId: postId),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: Post.self
        )

        return response.data
    }

    /// Create a new post
    public func createPost(
        campaignId: String,
        title: String,
        content: String,
        isPaid: Bool? = nil,
        isPublic: Bool? = nil,
        tiers: [String]? = nil,
        publishAt: Date? = nil
    ) async throws -> Post {
        try ensureAuthenticated()

        var attributes: [String: Any] = [
            "title": title,
            "content": content
        ]

        if let isPaid = isPaid {
            attributes["is_paid"] = isPaid
        }
        if let isPublic = isPublic {
            attributes["is_public"] = isPublic
        }

        var relationships: [String: Any] = [
            "campaign": [
                "data": [
                    "id": campaignId,
                    "type": "campaign"
                ]
            ]
        ]

        if let tiers = tiers, !tiers.isEmpty {
            relationships["tiers"] = [
                "data": tiers.map { ["id": $0, "type": "tier"] }
            ]
        }

        let body: [String: Any] = [
            "data": [
                "type": "post",
                "attributes": attributes,
                "relationships": relationships
            ]
        ]

        // Convert body to Data for JSON:API request
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        // Use injected HTTPClient for consistency and retry support
        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.posts,
            bodyData: bodyData,
            contentType: "application/vnd.api+json",
            authToken: authToken,
            decodeAs: Post.self
        )

        return response.data
    }

    /// Update an existing post
    public func updatePost(
        postId: String,
        title: String? = nil,
        content: String? = nil,
        isPaid: Bool? = nil,
        isPublic: Bool? = nil
    ) async throws -> Post {
        try ensureAuthenticated()

        var attributes: [String: Any] = [:]

        if let title = title {
            attributes["title"] = title
        }
        if let content = content {
            attributes["content"] = content
        }
        if let isPaid = isPaid {
            attributes["is_paid"] = isPaid
        }
        if let isPublic = isPublic {
            attributes["is_public"] = isPublic
        }

        let body: [String: Any] = [
            "data": [
                "type": "post",
                "id": postId,
                "attributes": attributes
            ]
        ]

        // Convert body to Data for JSON:API request
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        // Use injected HTTPClient for consistency and retry support
        let response = try await httpClient.request(
            method: .patch,
            path: Endpoints.post(postId: postId),
            bodyData: bodyData,
            contentType: "application/vnd.api+json",
            authToken: authToken,
            decodeAs: Post.self
        )

        return response.data
    }

    // MARK: - Member Operations

    /// Get members for a campaign
    public func getCampaignMembers(
        campaignId: String,
        includeFields: [String] = [
            "full_name", "email", "patron_status",
            "last_charge_status", "lifetime_support_cents",
            "currently_entitled_amount_cents"
        ],
        cursor: String? = nil
    ) async throws -> MembersResponse {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[member]", value: fieldsParam),
            URLQueryItem(name: "include", value: "currently_entitled_tiers")
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "page[cursor]", value: cursor))
        }

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.campaignMembers(campaignId: campaignId),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: MembersResponse.self
        )

        return response.data
    }

    /// Get paginated iterator for campaign posts
    public func postsIterator(campaignId: String) -> PaginatedIterator<Post> {
        PaginatedIterator { [weak self] cursor in
            guard let self = self else {
                throw AppError.apiRequestFailed("posts", NSError(domain: "PatreonClient", code: -1))
            }

            let response = try await self.getCampaignPosts(campaignId: campaignId, cursor: cursor)

            return HTTPClient.APIResponse<PaginatedIterator<Post>.PaginatedPage<Post>>(
                data: PaginatedIterator.PaginatedPage(
                    items: response.data,
                    nextCursor: response.meta?.pagination?.cursors?.next,
                    hasMore: response.meta?.pagination?.cursors?.next != nil
                ),
                statusCode: 200,
                headers: [:]
            )
        }
    }

    // MARK: - Utility Methods

    /// Get public URL for a post
    public func getPublicURL(for postId: String) async throws -> String {
        let post = try await getPost(postId: postId)
        return post.attributes.url ?? "https://www.patreon.com/posts/\(postId)"
    }

    /// Check if token needs refresh and refresh if necessary
    public func ensureValidToken() async throws {
        guard let token = authToken else {
            throw AppError.apiAuthenticationFailed("Patreon: Not authenticated")
        }

        if token.isExpired {
            try await refreshToken()
        }
    }

    // MARK: - Private Methods

    private func ensureAuthenticated() throws {
        guard isAuthenticated else {
            throw AppError.apiAuthenticationFailed("Patreon: Not authenticated. Call exchangeCodeForToken() first.")
        }
    }
}

// MARK: - Error Handling Extension

extension PatreonClient {
    /// Custom error types for Patreon API
    public enum PatreonError: Error, Sendable {
        case notAuthenticated
        case invalidResponse
        case campaignNotFound(String)
        case postNotFound(String)
        case memberNotFound(String)
        case rateLimited(Int)
    }
}
