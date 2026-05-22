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
        static func stashPublish() -> String { "\(base)/stash/publish" }
        static let stashContents = "\(base)/stash"
        static func deviation(deviationId: String) -> String { "\(base)/deviation/\(deviationId)" }
        static let deviations = "\(base)/deviations"
        static let galleryAll = "\(base)/gallery/all"
        static let userWhoami = "\(base)/user/whoami"
        static func userProfile(username: String) -> String { "\(base)/user/profile/\(username)" }
        static func deviationContent(deviationId: String) -> String {
            "\(base)/deviation/content?deviationid=\(deviationId)"
        }
        static func deviationMetadata(deviationId: String) -> String {
            "\(base)/deviation/metadata?deviationids[]=\(deviationId)"
        }
        static func deviationEdit(deviationId: String) -> String { "\(base)/deviation/edit/\(deviationId)" }
        static let deviationJournal = "\(base)/deviation/journal"
        static func deviationJournalUpdate(deviationId: String) -> String { "\(base)/deviation/journal/update/\(deviationId)" }
        static let deviationLiterature = "\(base)/deviation/literature"
        static func deviationLiteratureUpdate(deviationId: String) -> String { "\(base)/deviation/literature/update/\(deviationId)" }
        static func userWatchers(username: String) -> String { "\(base)/user/watchers/\(username)" }
        static func userFriends(username: String) -> String { "\(base)/user/friends/\(username)" }
        static func userFriendsWatching(username: String) -> String { "\(base)/user/friends/watching/\(username)" }
        static func userFriendsWatch(username: String) -> String { "\(base)/user/friends/watch/\(username)" }
        static func userFriendsUnwatch(username: String) -> String { "\(base)/user/friends/unwatch/\(username)" }
        static let galleryFolders = "\(base)/gallery/folders"
        static func galleryFolder(folderid: String) -> String { "\(base)/gallery/\(folderid)" }
        static func galleryFolderRemove(folderid: String) -> String { "\(base)/gallery/folders/remove/\(folderid)" }
        static let galleryFoldersCreate = "\(base)/gallery/folders/create"
        static let galleryFoldersUpdate = "\(base)/gallery/folders/update"
    }

    // MARK: - DTOs (from DeviantArtDTOs)

    public typealias StashStack = senor_platform.StashStack
    public typealias StashItem = senor_platform.StashItem
    public typealias StashContentsResponse = senor_platform.StashContentsResponse
    public typealias StashPublishResponse = senor_platform.StashPublishResponse
    public typealias Deviation = senor_platform.Deviation
    public typealias DeviationContent = senor_platform.DeviationContent
    public typealias DeviationMetadata = senor_platform.DeviationMetadata
    public typealias GalleryResponse = senor_platform.GalleryResponse
    public typealias UserProfile = senor_platform.UserProfile
    public typealias PublishResponse = senor_platform.PublishResponse
    public typealias WatchersResponse = senor_platform.WatchersResponse
    public typealias Watcher = senor_platform.Watcher
    public typealias FriendsResponse = senor_platform.FriendsResponse
    public typealias Friend = senor_platform.Friend
    public typealias GalleryFoldersResponse = senor_platform.GalleryFoldersResponse
    public typealias GalleryFolder = senor_platform.GalleryFolder
    public typealias DeviationEditResponse = senor_platform.DeviationEditResponse

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
    public func authorizationURL(
        scopes: [String] = ["browse", "publish", "stash"],
        state: String = UUID().uuidString
    ) async throws -> URL {
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
    /// Sends multipart/form-data with file and metadata
    public func stashSubmit(
        filename: String,
        fileData: Data? = nil,
        title: String? = nil,
        artistComments: String? = nil,
        tags: [String]? = nil,
        originalUrl: String? = nil
    ) async throws -> StashItem {
        try ensureAuthenticated()

        var parts: [HTTPClient.MultipartPart] = []

        if let fileData = fileData {
            let mimeType = mimeTypeFor(filename: filename)
            parts.append(.file(name: "file", filename: filename, data: fileData, mimeType: mimeType))
        }

        parts.append(.text(name: "title", value: title ?? filename))

        if let artistComments = artistComments {
            parts.append(.text(name: "artist_comments", value: artistComments))
        }
        if let tags = tags {
            for tag in tags {
                parts.append(.text(name: "tags[]", value: tag))
            }
        }
        if let originalUrl = originalUrl {
            parts.append(.text(name: "original_url", value: originalUrl))
        }

        let response = try await httpClient.requestMultipart(
            method: .post,
            path: Endpoints.stashSubmit(),
            parts: parts,
            authToken: authToken,
            decodeAs: StashItem.self
        )

        logger.info("Created stash item: \(response.data.itemid)")
        return response.data
    }

    private func mimeTypeFor(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        default: return "application/octet-stream"
        }
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
    /// itemid is sent in form body, not path
    public func stashPublish(
        itemId: String,
        title: String,
        category: String? = nil,
        isMature: Bool = false,
        matureLevel: String? = nil,
        allowsComments: Bool = true,
        galleryIds: [String]? = nil,
        licenseOptions: [String: String]? = nil
    ) async throws -> StashPublishResponse {
        try ensureAuthenticated()

        var body: [String: String] = [
            "itemid": itemId,
            "title": title,
            "is_mature": isMature ? "true" : "false",
            "allow_comments": allowsComments ? "true" : "false"
        ]

        if let category = category {
            body["catpath"] = category
        }
        if let matureLevel = matureLevel {
            body["mature_level"] = matureLevel
        }
        if let galleryIds = galleryIds {
            for (index, id) in galleryIds.enumerated() {
                body["galleryids[\(index)]"] = id
            }
        }
        if let licenseOptions = licenseOptions {
            for (key, value) in licenseOptions {
                body[key] = value
            }
        }

        guard let bodyData = HTTPClient.formURLEncodedBody(from: body) else {
            throw DeviantArtError.publishFailed("Failed to encode publish body")
        }

        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.stashPublish(),
            bodyData: bodyData,
            contentType: "application/x-www-form-urlencoded",
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
        return StashContentsResponse(results: [], hasMore: false, nextOffset: Int?(nil))
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

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.deviationMetadata(deviationId: deviationId),
            authToken: authToken,
            decodeAs: MetadataResponse.self
        )

        return response.data.metadata
    }

    private struct MetadataResponse: Codable, Sendable {
        let metadata: [DeviationMetadata]
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

    /// Get current authenticated user identity
    public func getWhoami() async throws -> UserProfile {
        try ensureAuthenticated()

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.userWhoami,
            authToken: authToken,
            decodeAs: UserProfile.self
        )

        return response.data
    }

    /// Get public profile for any user by username
    public func getUserProfile(username: String) async throws -> UserProfile {
        try ensureAuthenticated()

        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.userProfile(username: username),
            authToken: authToken,
            decodeAs: UserProfile.self
        )

        return response.data
    }

    // MARK: - Watchers / Friends

    public func getWatchers(username: String, offset: Int = 0, limit: Int = 50) async throws -> WatchersResponse {
        try ensureAuthenticated()
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.userWatchers(username: username),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: WatchersResponse.self
        )
        return response.data
    }

    public func getFriends(username: String, offset: Int = 0, limit: Int = 50) async throws -> FriendsResponse {
        try ensureAuthenticated()
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.userFriends(username: username),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: FriendsResponse.self
        )
        return response.data
    }

    public func isWatching(username: String) async throws -> Bool {
        try ensureAuthenticated()
        let response = try await httpClient.request(
            method: .get,
            path: Endpoints.userFriendsWatching(username: username),
            authToken: authToken,
            decodeAs: [String: Bool].self
        )
        return response.data["is_watching"] ?? false
    }

    public func watchUser(username: String) async throws {
        try ensureAuthenticated()
        _ = try await httpClient.request(
            method: .post,
            path: Endpoints.userFriendsWatch(username: username),
            authToken: authToken,
            decodeAs: EmptyResponse.self
        )
    }

    public func unwatchUser(username: String) async throws {
        try ensureAuthenticated()
        _ = try await httpClient.request(
            method: .get,
            path: Endpoints.userFriendsUnwatch(username: username),
            authToken: authToken,
            decodeAs: EmptyResponse.self
        )
    }

    // MARK: - Gallery Folder Operations

    public func getGalleryFolders(username: String? = nil, offset: Int = 0, limit: Int = 50) async throws -> GalleryFoldersResponse {
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
            path: Endpoints.galleryFolders,
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: GalleryFoldersResponse.self
        )
        return response.data
    }

    public func getGalleryFolderContents(folderid: String, username: String? = nil, offset: Int = 0, limit: Int = 24) async throws -> GalleryResponse {
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
            path: Endpoints.galleryFolder(folderid: folderid),
            queryItems: queryItems,
            authToken: authToken,
            decodeAs: GalleryResponse.self
        )
        return response.data
    }

    public func createGalleryFolder(name: String, parentId: String? = nil) async throws -> GalleryFolder {
        try ensureAuthenticated()
        var body: [String: String] = ["folder": name]
        if let parentId = parentId {
            body["parent"] = parentId
        }
        guard let bodyData = HTTPClient.formURLEncodedBody(from: body) else {
            throw DeviantArtError.uploadFailed("Failed to encode folder body")
        }
        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.galleryFoldersCreate,
            bodyData: bodyData,
            contentType: "application/x-www-form-urlencoded",
            authToken: authToken,
            decodeAs: GalleryFolder.self
        )
        return response.data
    }

    public func deleteGalleryFolder(folderid: String) async throws {
        try ensureAuthenticated()
        _ = try await httpClient.request(
            method: .post,
            path: Endpoints.galleryFolderRemove(folderid: folderid),
            authToken: authToken,
            decodeAs: EmptyResponse.self
        )
    }

    // MARK: - Deviation Edit / Journal / Literature

    public func editDeviation(deviationId: String, title: String, tags: [String]? = nil, description: String? = nil, isMature: Bool? = nil) async throws -> DeviationEditResponse {
        try ensureAuthenticated()
        var body: [String: String] = ["title": title]
        if let tags = tags {
            body["tags"] = tags.joined(separator: ",")
        }
        if let description = description {
            body["description"] = description
        }
        if let isMature = isMature {
            body["is_mature"] = isMature ? "true" : "false"
        }
        guard let bodyData = HTTPClient.formURLEncodedBody(from: body) else {
            throw DeviantArtError.uploadFailed("Failed to encode edit body")
        }
        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.deviationEdit(deviationId: deviationId),
            bodyData: bodyData,
            contentType: "application/x-www-form-urlencoded",
            authToken: authToken,
            decodeAs: DeviationEditResponse.self
        )
        return response.data
    }

    public func createJournal(title: String, body: String, tags: [String]? = nil, isMature: Bool = false) async throws -> DeviationEditResponse {
        try ensureAuthenticated()
        var formBody: [String: String] = [
            "title": title,
            "body": body,
            "is_mature": isMature ? "true" : "false"
        ]
        if let tags = tags {
            formBody["tags"] = tags.joined(separator: ",")
        }
        guard let bodyData = HTTPClient.formURLEncodedBody(from: formBody) else {
            throw DeviantArtError.uploadFailed("Failed to encode journal body")
        }
        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.deviationJournal,
            bodyData: bodyData,
            contentType: "application/x-www-form-urlencoded",
            authToken: authToken,
            decodeAs: DeviationEditResponse.self
        )
        return response.data
    }

    public func updateJournal(deviationId: String, title: String? = nil, body: String? = nil, tags: [String]? = nil) async throws -> DeviationEditResponse {
        try ensureAuthenticated()
        var formBody: [String: String] = [:]
        if let title = title { formBody["title"] = title }
        if let body = body { formBody["body"] = body }
        if let tags = tags { formBody["tags"] = tags.joined(separator: ",") }
        guard let bodyData = HTTPClient.formURLEncodedBody(from: formBody) else {
            throw DeviantArtError.uploadFailed("Failed to encode journal update body")
        }
        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.deviationJournalUpdate(deviationId: deviationId),
            bodyData: bodyData,
            contentType: "application/x-www-form-urlencoded",
            authToken: authToken,
            decodeAs: DeviationEditResponse.self
        )
        return response.data
    }

    public func createLiterature(title: String, body: String, tags: [String]? = nil, isMature: Bool = false) async throws -> DeviationEditResponse {
        try ensureAuthenticated()
        var formBody: [String: String] = [
            "title": title,
            "body": body,
            "is_mature": isMature ? "true" : "false"
        ]
        if let tags = tags {
            formBody["tags"] = tags.joined(separator: ",")
        }
        guard let bodyData = HTTPClient.formURLEncodedBody(from: formBody) else {
            throw DeviantArtError.uploadFailed("Failed to encode literature body")
        }
        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.deviationLiterature,
            bodyData: bodyData,
            contentType: "application/x-www-form-urlencoded",
            authToken: authToken,
            decodeAs: DeviationEditResponse.self
        )
        return response.data
    }

    public func updateLiterature(deviationId: String, title: String? = nil, body: String? = nil, tags: [String]? = nil) async throws -> DeviationEditResponse {
        try ensureAuthenticated()
        var formBody: [String: String] = [:]
        if let title = title { formBody["title"] = title }
        if let body = body { formBody["body"] = body }
        if let tags = tags { formBody["tags"] = tags.joined(separator: ",") }
        guard let bodyData = HTTPClient.formURLEncodedBody(from: formBody) else {
            throw DeviantArtError.uploadFailed("Failed to encode literature update body")
        }
        let response = try await httpClient.request(
            method: .post,
            path: Endpoints.deviationLiteratureUpdate(deviationId: deviationId),
            bodyData: bodyData,
            contentType: "application/x-www-form-urlencoded",
            authToken: authToken,
            decodeAs: DeviationEditResponse.self
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

    // MARK: - Empty Response Helper
    private struct EmptyResponse: Codable {}

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
