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
        static func deviation(deviationId: String) -> String { "\(base)/deviation/\(deviationId)" }
        static let deviations = "\(base)/deviations"
        static let galleryAll = "\(base)/gallery/all"
        static let userProfile = "\(base)/user/profile"
        static func deviationContent(deviationId: String) -> String { "\(base)/deviation/content?deviationid=\(deviationId)" }
        static func deviationMetadata(deviationId: String) -> String { "\(base)/deviation/metadata?deviationids[] =\(deviationId)" }
    }
    
    // MARK: - DTOs
    
    public struct StashItem: Codable, Identifiable {
        public let itemid: String
        public let stackid: String?
        public let title: String
        public let path: String?
        public let size: Int?
        public let fileSize: Int?
        public let status: String
        
        enum CodingKeys: String, CodingKey {
            case itemid, stackid, title, path, size, status
            case fileSize = "filesize"
        }
        
        public var id: String { itemid }
    }
    
    public struct StashPublishResponse: Codable {
        public let status: String
        public let deviationid: String?
        public let url: String?
    }
    
    public struct Deviation: Codable, Identifiable {
        public let deviationid: String
        public let url: String
        public let title: String
        public let category: String?
        public let author: User?
        public let stats: Stats?
        public let publishedTime: String?
        public let allowsComments: Bool?
        public let isFavourited: Bool?
        public let isDeleted: Bool?
        
        enum CodingKeys: String, CodingKey {
            case deviationid, url, title, category, author, stats
            case publishedTime = "published_time"
            case allowsComments = "allows_comments"
            case isFavourited = "is_favourited"
            case isDeleted = "is_deleted"
        }
        
        public var id: String { deviationid }
        
        public struct User: Codable {
            public let userid: String
            public let username: String
            public let usericon: String?
        }
        
        public struct Stats: Codable {
            public let views: Int?
            public let favourites: Int?
            public let comments: Int?
            public let downloads: Int?
        }
    }
    
    public struct DeviationContent: Codable {
        public let html: String?
        public let css: String?
        public let body: String?
    }
    
    public struct DeviationMetadata: Codable {
        public let deviationid: String
        public let type: String?
        public let tags: [Tag]?
        public let description: String?
        public let license: String?
        public let allowsComments: Bool?
        public let isFavouritable: Bool?
        public let isFavourited: Bool?
        public let isDeleted: Bool?
        
        enum CodingKeys: String, CodingKey {
            case deviationid, type, tags, description, license
            case allowsComments = "allows_comments"
            case isFavouritable = "is_favouritable"
            case isFavourited = "is_favourited"
            case isDeleted = "is_deleted"
        }
        
        public struct Tag: Codable {
            public let tagName: String
        }
    }
    
    public struct GalleryResponse: Codable {
        public let results: [Deviation]
        public let hasMore: Bool
        public let nextOffset: Int?
        
        enum CodingKeys: String, CodingKey {
            case results
            case hasMore = "has_more"
            case nextOffset = "next_offset"
        }
    }
    
    public struct UserProfile: Codable {
        public let user: UserInfo
        public let stats: UserStats?
        
        public struct UserInfo: Codable {
            public let userid: String
            public let username: String
            public let usericon: String?
            public let type: String?
        }
        
        public struct UserStats: Codable {
            public let watchers: Int?
            public let friends: Int?
            public let deviations: Int?
        }
    }
    
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
    public func authorizationURL(scopes: [String] = ["browse", "publish", "stash"], state: String = UUID().uuidString) throws -> URL {
        try oauthHelper.authorizationURL(scopes: scopes, state: state)
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
