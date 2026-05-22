import Foundation

// MARK: - Webhook Trigger Constants

public enum PatreonWebhookTrigger: String, CaseIterable, Sendable {
    case membersCreate = "members:create"
    case membersUpdate = "members:update"
    case membersDelete = "members:delete"
    case membersPledgeCreate = "members:pledge:create"
    case membersPledgeUpdate = "members:pledge:update"
    case membersPledgeDelete = "members:pledge:delete"
    case postsPublish = "posts:publish"
    case postsUpdate = "posts:update"
    case postsDelete = "posts:delete"
}

// MARK: - Response Types (defined outside class to avoid main actor isolation issues)

public struct PatreonCampaign: Codable, Identifiable {
    public let id: String
    public let type: String
    public let attributes: PatreonCampaignAttributes

    public struct PatreonCampaignAttributes: Codable, Sendable {
        // Existing
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
        // NEW FIELDS
        public let isMonthly: Bool?
        public let isChargedImmediately: Bool?
        public let isNsfw: Bool?
        public let mainVideoEmbed: String?
        public let mainVideoUrl: String?
        public let oneLiner: String?
        public let pledgeUrl: String?
        public let thanksEmbed: String?
        public let hasRss: Bool?
        public let rssFeedTitle: String?
        public let rssArtworkUrl: String?
        public let googleAnalyticsId: String?
        public let discordServerId: String?
        public let createdAt: String?

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
            // NEW
            case isMonthly = "is_monthly"
            case isChargedImmediately = "is_charged_immediately"
            case isNsfw = "is_nsfw"
            case mainVideoEmbed = "main_video_embed"
            case mainVideoUrl = "main_video_url"
            case oneLiner = "one_liner"
            case pledgeUrl = "pledge_url"
            case thanksEmbed = "thanks_embed"
            case hasRss = "has_rss"
            case rssFeedTitle = "rss_feed_title"
            case rssArtworkUrl = "rss_artwork_url"
            case googleAnalyticsId = "google_analytics_id"
            case discordServerId = "discord_server_id"
            case createdAt = "created_at"
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
        public let lastChargeDate: String?
        public let pledgeRelationshipStart: String?
        public let note: String?
        public let campaignLifetimeSupportCents: Int?
        public let willPayAmountCents: Int?
        public let nextChargeDate: String?
        public let pledgeCadence: Int?
        public let isFreeTrial: Bool?
        public let isGifted: Bool?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
            case email
            case patronStatus = "patron_status"
            case lastChargeStatus = "last_charge_status"
            case lifetimeSupportCents = "lifetime_support_cents"
            case currentlyEntitledAmountCents = "currently_entitled_amount_cents"
            case lastChargeDate = "last_charge_date"
            case pledgeRelationshipStart = "pledge_relationship_start"
            case note
            case campaignLifetimeSupportCents = "campaign_lifetime_support_cents"
            case willPayAmountCents = "will_pay_amount_cents"
            case nextChargeDate = "next_charge_date"
            case pledgeCadence = "pledge_cadence"
            case isFreeTrial = "is_free_trial"
            case isGifted = "is_gifted"
        }
    }

    public struct PatreonMemberRelationships: Codable, Sendable {
        public let currentlyEntitledTiers: [PatreonTierData]?
        public let pledgeHistory: [PatreonPledgeEvent]?

        enum CodingKeys: String, CodingKey {
            case currentlyEntitledTiers = "currently_entitled_tiers"
            case pledgeHistory = "pledge_history"
        }
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
    public let addressee: String?
    public let line1: String?
    public let line2: String?
    public let city: String?
    public let state: String?
    public let postalCode: String?
    public let country: String?
    public let phoneNumber: String?
    public let description: String?
    public let discordRoleIds: [String]?
    public let editedAt: String?
    public let patronCount: Int?
    public let published: Bool?
    public let publishedAt: String?
    public let requiresShipping: Bool?
    public let createdAt: String?
    public let email: String?
    public let fullName: String?
    public let firstName: String?
    public let lastName: String?
    public let imageUrl: String?
    public let thumbUrl: String?
    public let vanity: String?
    public let about: String?
    public let created: String?
    // Pledge event fields
    public let type: String?
    public let date: String?
    public let paymentStatus: String?
    public let currency: String?
    public let tierId: String?

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case amountCents = "amount_cents"
        case addressee
        case line1 = "line_1"
        case line2 = "line_2"
        case city
        case state
        case postalCode = "postal_code"
        case country
        case phoneNumber = "phone_number"
        case description
        case discordRoleIds = "discord_role_ids"
        case editedAt = "edited_at"
        case patronCount = "patron_count"
        case published
        case publishedAt = "published_at"
        case requiresShipping = "requires_shipping"
        case createdAt = "created_at"
        case email
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case imageUrl = "image_url"
        case thumbUrl = "thumb_url"
        case vanity
        case about
        case created
        case type
        case date
        case paymentStatus = "payment_status"
        case currency
        case tierId = "tier_id"
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
            // NEW FIELDS
            public let about: String?
            public let created: String?
            public let lastName: String?
            public let socialConnections: SocialConnections?

            enum CodingKeys: String, CodingKey {
                case email
                case firstName = "first_name"
                case fullName = "full_name"
                case imageUrl = "image_url"
                case thumbUrl = "thumb_url"
                case url
                case vanity
                case about
                case created
                case lastName = "last_name"
                case socialConnections = "social_connections"
            }
        }
    }
}

// NEW: Social connections struct
public struct SocialConnections: Codable, Sendable {
    public let discord: SocialConnection?
    public let twitter: SocialConnection?
    public let youtube: SocialConnection?
    public let spotify: SocialConnection?

    public struct SocialConnection: Codable, Sendable {
        public let userId: String?
        public let url: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case url
        }
    }
}

// MARK: - Address Model

public struct PatreonAddress: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let attributes: AddressAttributes

    public struct AddressAttributes: Codable, Sendable {
        public let addressee: String?
        public let line1: String?
        public let line2: String?
        public let city: String?
        public let state: String?
        public let postalCode: String?
        public let country: String?
        public let phoneNumber: String?
        public let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case addressee
            case line1 = "line_1"
            case line2 = "line_2"
            case city
            case state
            case postalCode = "postal_code"
            case country
            case phoneNumber = "phone_number"
            case createdAt = "created_at"
        }
    }
}

// MARK: - Pledge Event Model

public struct PatreonPledgeEvent: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let attributes: PledgeEventAttributes

    public struct PledgeEventAttributes: Codable, Sendable {
        public let type: String?
        public let date: String?
        public let paymentStatus: String?
        public let amountCents: Int?
        public let currency: String?
        public let tierId: String?

        enum CodingKeys: String, CodingKey {
            case type
            case date
            case paymentStatus = "payment_status"
            case amountCents = "amount_cents"
            case currency
            case tierId = "tier_id"
        }
    }
}

// MARK: - Webhook Models

public struct PatreonWebhook: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let attributes: WebhookAttributes

    public struct WebhookAttributes: Codable, Sendable {
        public let lastAttemptedAt: String?
        public let numConsecutiveTimesFailed: Int?
        public let paused: Bool?
        public let secret: String?
        public let triggers: [String]?
        public let uri: String?

        enum CodingKeys: String, CodingKey {
            case lastAttemptedAt = "last_attempted_at"
            case numConsecutiveTimesFailed = "num_consecutive_times_failed"
            case paused
            case secret
            case triggers
            case uri
        }
    }
}

public struct PatreonWebhooksResponse: Codable {
    public let data: [PatreonWebhook]
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
        static func member(memberId: String) -> String { "\(base)/members/\(memberId)" }
        static let webhooks = "\(base)/webhooks"
        static func webhook(webhookId: String) -> String { "\(base)/webhooks/\(webhookId)" }
    }

    // MARK: - Type Aliases for Response Types
    public typealias IdentityResponse = PatreonIdentityResponse
    public typealias Campaign = PatreonCampaign
    public typealias CampaignsResponse = PatreonCampaignsResponse
    public typealias Post = PatreonPost
    public typealias PostsResponse = PatreonPostsResponse
    public typealias Member = PatreonMember
    public typealias MembersResponse = PatreonMembersResponse
    public typealias Webhook = PatreonWebhook
    public typealias WebhooksResponse = PatreonWebhooksResponse

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
        scopes: [String] = [
            "identity",
            "identity[email]",
            "identity.memberships",
            "campaigns",
            "campaigns.members",
            "campaigns.members.address",
            "w:campaigns.webhook"
        ],
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
        fields: [String] = [
            "about", "created", "email", "first_name", "full_name",
            "image_url", "last_name", "social_connections",
            "thumb_url", "url", "vanity"
        ],
        include: [String] = ["memberships", "campaign"]
    ) async throws -> IdentityResponse {
        try ensureAuthenticated()

        let fieldsParam = fields.joined(separator: ",")
        let includeParam = include.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[user]", value: fieldsParam),
            URLQueryItem(name: "include", value: includeParam)
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
        includeFields: [String] = [
            "created_at", "creation_name", "discord_server_id",
            "google_analytics_id", "has_rss", "has_sent_rss_notify",
            "image_small_url", "image_url", "is_charged_immediately",
            "is_monthly", "is_nsfw", "main_video_embed", "main_video_url",
            "one_liner", "patron_count", "pay_per_name", "pledge_url",
            "published_at", "summary", "thanks_embed", "thanks_msg",
            "thanks_video_url", "rss_feed_title", "rss_artwork_url"
        ],
        include: [String] = ["tiers", "creator", "benefits", "goals"]
    ) async throws -> CampaignsResponse {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        let includeParam = include.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[campaign]", value: fieldsParam),
            URLQueryItem(name: "include", value: includeParam)
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
        includeFields: [String] = [
            "created_at", "creation_name", "discord_server_id",
            "google_analytics_id", "has_rss", "has_sent_rss_notify",
            "image_small_url", "image_url", "is_charged_immediately",
            "is_monthly", "is_nsfw", "main_video_embed", "main_video_url",
            "one_liner", "patron_count", "pay_per_name", "pledge_url",
            "published_at", "summary", "thanks_embed", "thanks_msg",
            "thanks_video_url", "rss_feed_title", "rss_artwork_url"
        ],
        include: [String] = ["tiers", "creator", "benefits", "goals"]
    ) async throws -> Campaign {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        let includeParam = include.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[campaign]", value: fieldsParam),
            URLQueryItem(name: "include", value: includeParam)
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
        includeFields: [String] = [
            "amount_cents", "created_at", "description",
            "discord_role_ids", "edited_at", "patron_count",
            "published", "published_at", "requires_shipping",
            "title", "url"
        ]
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
                    amountCents: resource.attributes?.amountCents,
                    description: resource.attributes?.description,
                    discordRoleIds: resource.attributes?.discordRoleIds,
                    editedAt: resource.attributes?.editedAt,
                    patronCount: resource.attributes?.patronCount,
                    published: resource.attributes?.published,
                    publishedAt: resource.attributes?.publishedAt,
                    requiresShipping: resource.attributes?.requiresShipping,
                    url: resource.attributes?.url,
                    createdAt: resource.attributes?.createdAt
                )
            )
        } ?? []
    }

    // MARK: - Post Operations

    /// Get all posts for a campaign
    public func getCampaignPosts(
        campaignId: String,
        includeFields: [String] = ["title", "content", "is_paid", "is_public", "published_at", "url"],
        cursor: String? = nil,
        pageCount: Int = 25
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
        queryItems.append(URLQueryItem(name: "page[count]", value: String(pageCount)))

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


    // MARK: - Member Operations

    /// Get members for a campaign
    public func getCampaignMembers(
        campaignId: String,
        includeFields: [String] = [
            "full_name", "email", "patron_status",
            "last_charge_status", "lifetime_support_cents",
            "currently_entitled_amount_cents",
            "last_charge_date", "pledge_relationship_start",
            "note", "currently_entitled_tiers",
            "pledge_cadence", "will_pay_amount_cents",
            "campaign_lifetime_support_cents",
            "next_charge_date", "is_free_trial", "is_gifted"
        ],
        include: [String] = [
            "currently_entitled_tiers", "address", "user", "pledge_history"
        ],
        cursor: String? = nil,
        pageCount: Int = 100
    ) async throws -> MembersResponse {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        let includeParam = include.joined(separator: ",")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[member]", value: fieldsParam),
            URLQueryItem(name: "include", value: includeParam)
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "page[cursor]", value: cursor))
        }
        queryItems.append(URLQueryItem(name: "page[count]", value: String(pageCount)))

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.campaignMembers(campaignId: campaignId),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: MembersResponse.self
        )

        return response.data
    }

    /// Get pledge history for a specific member
    public func getPledgeHistory(
        memberId: String,
        includeFields: [String] = [
            "type", "date", "payment_status", "amount_cents", "currency", "tier_id"
        ]
    ) async throws -> [PatreonPledgeEvent] {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[pledge-event]", value: fieldsParam),
            URLQueryItem(name: "include", value: "pledge_history")
        ]

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.member(memberId: memberId),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: MembersResponse.self
        )

        return response.data.included?.filter { $0.type == "pledge-event" }.map { resource in
            PatreonPledgeEvent(
                id: resource.id,
                type: resource.type,
                attributes: .init(
                    type: resource.attributes?.type,
                    date: resource.attributes?.date,
                    paymentStatus: resource.attributes?.paymentStatus,
                    amountCents: resource.attributes?.amountCents,
                    currency: resource.attributes?.currency,
                    tierId: resource.attributes?.tierId
                )
            )
        } ?? []
    }

    /// Get a specific member by ID
    public func getMember(
        memberId: String,
        includeFields: [String] = [
            "full_name", "email", "patron_status",
            "last_charge_status", "lifetime_support_cents",
            "currently_entitled_amount_cents",
            "last_charge_date", "pledge_relationship_start",
            "note", "pledge_cadence", "will_pay_amount_cents",
            "campaign_lifetime_support_cents",
            "next_charge_date", "is_free_trial", "is_gifted"
        ],
        include: [String] = [
            "currently_entitled_tiers", "address", "user", "pledge_history"
        ]
    ) async throws -> Member {
        try ensureAuthenticated()

        let fieldsParam = includeFields.joined(separator: ",")
        let includeParam = include.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[member]", value: fieldsParam),
            URLQueryItem(name: "include", value: includeParam)
        ]

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.member(memberId: memberId),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: Member.self
        )

        return response.data
    }

    /// Get paginated iterator for campaign members
    public func membersIterator(campaignId: String) -> PaginatedIterator<Member> {
        PaginatedIterator { [weak self] cursor in
            guard let self = self else {
                throw AppError.apiRequestFailed("members", NSError(domain: "PatreonClient", code: -1))
            }

            let response = try await self.getCampaignMembers(campaignId: campaignId, cursor: cursor)

            return HTTPClient.APIResponse<PaginatedIterator<Member>.PaginatedPage<Member>>(
                data: PaginatedIterator<Member>.PaginatedPage(
                    items: response.data,
                    nextCursor: response.meta?.pagination?.cursors?.next,
                    hasMore: response.meta?.pagination?.cursors?.next != nil
                ),
                statusCode: 200,
                headers: [:]
            )
        }
    }

    // MARK: - Webhook Operations

    /// Get all webhooks for the current user
    public func getWebhooks(
        fields: [String] = [
            "last_attempted_at", "num_consecutive_times_failed",
            "paused", "secret", "triggers", "uri"
        ]
    ) async throws -> [Webhook] {
        try ensureAuthenticated()

        let fieldsParam = fields.joined(separator: ",")
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[webhook]", value: fieldsParam)
        ]

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.webhooks,
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: WebhooksResponse.self
        )

        return response.data.data
    }

    /// Create a new webhook
    public func createWebhook(
        campaignId: String,
        uri: String,
        triggers: [PatreonWebhookTrigger],
        secret: String? = nil
    ) async throws -> Webhook {
        try ensureAuthenticated()

        let body: [String: Any] = [
            "data": [
                "type": "webhook",
                "attributes": [
                    "uri": uri,
                    "triggers": triggers.map { $0.rawValue },
                    "secret": secret as Any
                ] as [String: Any],
                "relationships": [
                    "campaign": [
                        "data": [
                            "type": "campaign",
                            "id": campaignId
                        ]
                    ]
                ]
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.webhooks,
            bodyData: bodyData,
            contentType: "application/vnd.api+json",
            authToken: authToken,
            decodeAs: Webhook.self
        )

        return response.data
    }

    /// Update an existing webhook
    public func updateWebhook(
        webhookId: String,
        uri: String? = nil,
        triggers: [PatreonWebhookTrigger]? = nil,
        paused: Bool? = nil,
        secret: String? = nil
    ) async throws -> Webhook {
        try ensureAuthenticated()

        var attributes: [String: Any] = [:]

        if let uri = uri {
            attributes["uri"] = uri
        }
        if let triggers = triggers {
            attributes["triggers"] = triggers.map { $0.rawValue }
        }
        if let paused = paused {
            attributes["paused"] = paused
        }
        if let secret = secret {
            attributes["secret"] = secret
        }

        let body: [String: Any] = [
            "data": [
                "type": "webhook",
                "id": webhookId,
                "attributes": attributes
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response = try await httpClient.request(
            method: .patch,
            path: Endpoints.webhook(webhookId: webhookId),
            bodyData: bodyData,
            contentType: "application/vnd.api+json",
            authToken: authToken,
            decodeAs: Webhook.self
        )

        return response.data
    }

    /// Delete a webhook
    public func deleteWebhook(webhookId: String) async throws {
        try ensureAuthenticated()

        _ = try await httpClient.request(
            method: .delete,
            path: Endpoints.webhook(webhookId: webhookId),
            authToken: authToken,
            decodeAs: EmptyResponse.self
        )
    }

    // MARK: - Empty Response Helper
    private struct EmptyResponse: Codable {}

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
