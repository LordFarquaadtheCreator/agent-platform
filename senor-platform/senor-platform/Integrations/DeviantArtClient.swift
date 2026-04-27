import Foundation

/// Comprehensive DeviantArt API client
/// API Docs: https://www.deviantart.com/developers/http/v1/20240701
public final class DeviantArtClient {
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
        static let base = "https://www.deviantart.com/api/v1/oauth2"
        static let auth = "https://www.deviantart.com/oauth2/authorize"
        static let token = "https://www.deviantart.com/oauth2/token"

        static func stashSubmit() -> String { "\(base)/stash/submit" }
        static func stashContent(stashId: String) -> String { "\(base)/stash/\(stashId)" }
        static func stashPublish(stashId: String) -> String { "\(base)/stash/publish/\(stashId)" }
        static let stashContents = "\(base)/stash"
        static func deviation(deviationId: String) -> String { "\(base)/deviation/\(deviationId)" }
        static let deviations = "\(base)/deviations"
        static let galleryAll = "\(base)/gallery/all"
        static let userProfile = "\(base)/user/profile"
        static func deviationContent(deviationId: String) -> String { "\(base)/deviation/content?deviationid=\(deviationId)" }
        static func deviationMetadata(deviationId: String) -> String { "\(base)/deviation/metadata?deviationids[]=\(deviationId)" }
    }

    // MARK: - DTOs (from DeviantArtDTOs)

    public typealias StashStack = DeviantArtDTOs.StashStack
    public typealias StashItem = DeviantArtDTOs.StashItem
    public typealias StashContentsResponse = DeviantArtDTOs.StashContentsResponse
    public typealias StashPublishResponse = DeviantArtDTOs.StashPublishResponse
    public typealias Deviation = DeviantArtDTOs.Deviation
    public typealias DeviationContent = DeviantArtDTOs.DeviationContent
    public typealias DeviationMetadata = DeviantArtDTOs.DeviationMetadata
    public typealias GalleryResponse = DeviantArtDTOs.GalleryResponse
    public typealias UserProfile = DeviantArtDTOs.UserProfile
    public typealias PublishResponse = DeviantArtDTOs.PublishResponse

    // MARK: - Initialization

    private let oauthHelper: OAuthHelper
    private var authToken: HTTPClient.AuthToken?

    public init(configuration: Configuration, httpClient: HTTPClient) async throws {
        self.httpClient = httpClient

        guard let authURL = URL(string: Endpoints.auth),
              let tokenURL = URL(string: Endpoints.token) else {
            throw AppError.invalidConfiguration("Invalid DeviantArt OAuth URLs")
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
    public func authorizationURL(scopes: [String] = ["browse", "publish", "stash"], state: String = UUID().uuidString) async throws -> URL {
        try await oauthHelper.authorizationURL(scopes: scopes, state: state)
    }

    /// Exchange authorization code for access token
    public func exchangeCodeForToken(code: String) async throws {
        authToken = try await oauthHelper.exchangeCodeForToken(code: code)
        logger.info("Successfully authenticated with DeviantArt")
    }

    /// Refresh the access token
    public func refreshToken() async throws {
        guard let currentToken = authToken, let refreshToken = currentToken.refreshToken else {
            throw AppError.apiAuthenticationFailed("DeviantArt: No refresh token available")
        }
        authToken = try await oauthHelper.refreshToken(refreshToken: refreshToken)
        logger.debug("DeviantArt token refreshed")
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

    /// Clear auth token on disconnect
    public func clearAuthToken() {
        authToken = nil
    }

    // MARK: - Stash Operations

    /// Submit a file to stash (step 1: create stash item)
    /// This is a simplified version - actual implementation needs file upload
    public func stashSubmit(
        filename: String,
        title: String? = nil,
        artistComments: String? = nil,
        tags: [String]? = nil,
        originalUrl: String? = nil
    ) async throws -> StashItem {
        try ensureAuthenticated()

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "filename", value: filename)
        ]

        if let title = title {
            queryItems.append(URLQueryItem(name: "title", value: title))
        }
        if let artistComments = artistComments {
            queryItems.append(URLQueryItem(name: "artist_comments", value: artistComments))
        }
        if let tags = tags {
            queryItems.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
        }
        if let originalUrl = originalUrl {
            queryItems.append(URLQueryItem(name: "original_url", value: originalUrl))
        }

        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.stashSubmit(),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: StashItem.self
        )

        logger.info("Created stash item: \(response.data.itemid)")
        return response.data
    }

    /// Get stash item details and status
    public func getStashItem(itemId: String) async throws -> StashItem {
        try ensureAuthenticated()

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.stashContent(stashId: itemId),
            authToken: authToken,
            decodeAs: StashItem.self
        )

        return response.data
    }

    /// Publish a stash item as a deviation (step 2: publish)
    public func stashPublish(
        stashId: String,
        title: String,
        category: String? = nil,
        isMature: Bool = false,
        matureLevel: String? = nil,
        allowsComments: Bool = true,
        galleryIds: [String]? = nil,
        licenseOptions: [String: String]? = nil
    ) async throws -> StashPublishResponse {
        try ensureAuthenticated()

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "is_mature", value: isMature ? "true" : "false"),
            URLQueryItem(name: "allows_comments", value: allowsComments ? "true" : "false")
        ]

        if let category = category {
            queryItems.append(URLQueryItem(name: "category_path", value: category))
        }
        if let matureLevel = matureLevel {
            queryItems.append(URLQueryItem(name: "mature_level", value: matureLevel))
        }
        if let galleryIds = galleryIds {
            for id in galleryIds {
                queryItems.append(URLQueryItem(name: "galleryids[]", value: id))
            }
        }
        if let licenseOptions = licenseOptions {
            for (key, value) in licenseOptions {
                queryItems.append(URLQueryItem(name: "\(key)", value: value))
            }
        }

        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.stashPublish(stashId: stashId),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: StashPublishResponse.self
        )

        if let url = response.data.url {
            logger.info("Published deviation: \(url)")
        }

        return response.data
    }

    /// Get sta.sh contents (unpublished items)
    /// NOTE: Endpoint is currently stubbed - DeviantArt API documentation unclear on correct endpoint
    public func getStashContents(
        stackId: String? = nil,
        offset: Int = 0,
        limit: Int = 24
    ) async throws -> StashContentsResponse {
        try ensureAuthenticated()

        // Stub: DeviantArt stash listing endpoint unclear in API docs
        // Previous attempts returned 404 - returning empty for now
        return StashContentsResponse(results: [], hasMore: false, nextOffset: nil)
    }

    // MARK: - Deviation Operations

    /// Get a single deviation by ID
    public func getDeviation(deviationId: String) async throws -> Deviation {
        try ensureAuthenticated()

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.deviation(deviationId: deviationId),
            authToken: authToken,
            decodeAs: Deviation.self
        )

        return response.data
    }

    /// Get deviation content (HTML/description)
    public func getDeviationContent(deviationId: String) async throws -> DeviationContent {
        try ensureAuthenticated()

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.deviationContent(deviationId: deviationId),
            authToken: authToken,
            decodeAs: DeviationContent.self
        )

        return response.data
    }

    /// Get deviation metadata (tags, description, license)
    public func getDeviationMetadata(deviationId: String) async throws -> [DeviationMetadata] {
        try ensureAuthenticated()

        struct Response: Codable {
            let metadata: [DeviationMetadata]
        }

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.deviationMetadata(deviationId: deviationId),
            authToken: authToken,
            decodeAs: Response.self
        )

        return response.data.metadata
    }

    // MARK: - Gallery/List Operations

    /// Get user's gallery (all deviations)
    public func getGalleryAll(
        username: String? = nil,
        offset: Int = 0,
        limit: Int = 24
    ) async throws -> GalleryResponse {
        try ensureAuthenticated()

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let username = username {
            queryItems.append(URLQueryItem(name: "username", value: username))
        }

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.galleryAll,
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: GalleryResponse.self
        )

        return response.data
    }

    /// Get paginated iterator for gallery
    public func galleryIterator(username: String? = nil, limit: Int = 24) -> PaginatedIterator<Deviation> {
        PaginatedIterator { [weak self] cursor in
            guard let self = self else {
                throw AppError.apiRequestFailed("gallery", NSError(domain: "DeviantArtClient", code: -1))
            }

            let offset = cursor.flatMap(Int.init) ?? 0
            let response = try await self.getGalleryAll(username: username, offset: offset, limit: limit)

            return HTTPClient.APIResponse<PaginatedIterator<Deviation>.PaginatedPage<Deviation>>(
                data: PaginatedIterator.PaginatedPage(
                    items: response.results,
                    nextCursor: response.hasMore ? String(offset + limit) : nil,
                    hasMore: response.hasMore
                ),
                statusCode: 200,
                headers: [:]
            )
        }
    }

    // MARK: - User Operations

    /// Get user profile information
    public func getUserProfile(username: String? = nil) async throws -> UserProfile {
        try ensureAuthenticated()

        var queryItems: [URLQueryItem] = []
        if let username = username {
            queryItems.append(URLQueryItem(name: "username", value: username))
        }

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.userProfile,
            queryItems: queryItems.isEmpty ? nil : queryItems,
            authToken: authToken,
            decodeAs: UserProfile.self
        )

        return response.data
    }

    // MARK: - Utility Methods

    /// Get public URL for a deviation
    public func getPublicURL(for deviationId: String) async throws -> String {
        let deviation = try await getDeviation(deviationId: deviationId)
        return deviation.url
    }

    /// Check if token needs refresh and refresh if necessary
    public func ensureValidToken() async throws {
        guard let token = authToken else {
            throw AppError.apiAuthenticationFailed("DeviantArt: Not authenticated")
        }

        if token.isExpired {
            try await refreshToken()
        }
    }

    // MARK: - Private Methods

    private func ensureAuthenticated() throws {
        guard isAuthenticated else {
            throw AppError.apiAuthenticationFailed("DeviantArt: Not authenticated. Call exchangeCodeForToken() first.")
        }
    }
}

// MARK: - Error Handling Extension

extension DeviantArtClient {
    /// Custom error types for DeviantArt API
    public enum DeviantArtError: Error, Sendable {
        case notAuthenticated
        case invalidResponse
        case uploadFailed(String)
        case publishFailed(String)
        case deviationNotFound(String)
        case rateLimited(Int)
    }
}
