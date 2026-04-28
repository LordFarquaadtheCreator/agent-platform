import Foundation
import Combine
import CryptoKit

@MainActor
public final class DeviantArtViewModel: ObservableObject {
    @Published public private(set) var profile: DeviantArtClient.UserProfile?
    @Published public private(set) var deviations: [DeviantArtClient.Deviation] = []
    @Published public private(set) var stashStacks: [DeviantArtClient.StashStack] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var isConnecting = false
    @Published public private(set) var lastUpdated: Date?
    @Published public var deviationMetadata: [String: DeviantArtClient.DeviationMetadata] = [:]

    private let client: DeviantArtClient?
    private let settingsService: SettingsService
    private let cacheService: CacheService?
    private var pendingCodeVerifier: String?
    private var pendingState: String?

    // 3-hour cache TTL for DeviantArt
    private static let cacheTTL: TimeInterval = 3 * 3600

    private enum PendingKeys {
        static let codeVerifier = "deviantArt.pendingCodeVerifier"
        static let state = "deviantArt.pendingState"
    }

    init(client: DeviantArtClient?, settingsService: SettingsService, cacheService: CacheService? = nil) {
        self.client = client
        self.settingsService = settingsService
        self.cacheService = cacheService
        self.isAuthenticated = client?.isAuthenticated ?? settingsService.loadDeviantArtSettings().isAuthenticated
    }

    func load() async {
        await load(forceRefresh: false)
    }

    func refresh() async {
        await load(forceRefresh: true)
    }

    private func load(forceRefresh: Bool) async {
        let settings = settingsService.loadDeviantArtSettings()

        guard settings.isAuthenticated else {
            isAuthenticated = false
            return
        }
        guard let client, client.isAuthenticated else {
            isAuthenticated = false
            errorMessage = "Token expired. Please reconnect DeviantArt."
            return
        }

        // Show loading state for initial load, refreshing state for background refresh
        if profile == nil && deviations.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }
        defer {
            isLoading = false
            isRefreshing = false
        }

        // Try cache first if not forcing refresh
        if !forceRefresh {
            await loadFromCache()
        }

        // Fetch fresh data in background
        do {
            async let profileTask = client.getUserProfile()
            async let galleryTask = client.getGalleryAll(limit: 24)

            let (profileResult, galleryResult) = try await (profileTask, galleryTask)

            profile = profileResult
            deviations = galleryResult.results
            lastUpdated = Date()

            // Cache the fresh data
            await cacheData(profile: profileResult, deviations: galleryResult.results)

            // Stash fetch is non-fatal (endpoint may not exist)
            do {
                let stashResult = try await client.getStashContents(limit: 24)
                stashStacks = stashResult.results
            } catch {
                stashStacks = []
            }

            errorMessage = nil
        } catch {
            // Only show error if we don't have cached data
            if profile == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadFromCache() async {
        // Caching disabled due to Swift 6 concurrency issues with generic Sendable constraints
        // swiftlint:disable:next todo
        // TODO: Re-enable once Swift 6 concurrency issues are resolved
    }

    private func cacheData(profile: DeviantArtClient.UserProfile, deviations: [DeviantArtClient.Deviation]) async {
        // Caching disabled due to Swift 6 concurrency issues with generic Sendable constraints
        // swiftlint:disable:next todo
        // TODO: Re-enable once Swift 6 concurrency issues are resolved
    }

    /// Load metadata for a specific deviation (tags, description, license)
    func loadMetadata(for deviationId: String) async {
        guard let client else { return }

        // Check if already loaded
        if deviationMetadata[deviationId] != nil { return }

        // Fetch from API (caching disabled due to Swift 6 concurrency issues)
        do {
            let metadata = try await client.getDeviationMetadata(deviationId: deviationId)
            if let first = metadata.first {
                deviationMetadata[deviationId] = first
            }
        } catch {
            // Silently fail - metadata is non-critical
        }
    }

    // MARK: - OAuth Flow

    /// Start the OAuth connection flow
    func startConnection() async -> URL? {
        let settings = settingsService.loadDeviantArtSettings()
        guard !settings.clientId.isEmpty, !settings.clientSecret.isEmpty else {
            errorMessage = "Client ID and Client Secret required in Settings"
            return nil
        }

        isConnecting = true
        defer { isConnecting = false }

        let pkce = generatePKCE()
        let state = UUID().uuidString

        // Persist to UserDefaults in case app restarts during OAuth
        UserDefaults.standard.set(pkce.verifier, forKey: PendingKeys.codeVerifier)
        UserDefaults.standard.set(state, forKey: PendingKeys.state)
        pendingCodeVerifier = pkce.verifier
        pendingState = state

        guard let authURL = buildAuthURL(settings: settings, state: state, codeChallenge: pkce.challenge) else {
            errorMessage = "Failed to build authorization URL"
            clearPendingState()
            return nil
        }

        return authURL
    }

    private func clearPendingState() {
        UserDefaults.standard.removeObject(forKey: PendingKeys.codeVerifier)
        UserDefaults.standard.removeObject(forKey: PendingKeys.state)
        pendingCodeVerifier = nil
        pendingState = nil
    }

    /// Handle the OAuth callback URL
    func handleCallback(url: URL) async {
        // Restore from UserDefaults if memory was cleared
        let storedVerifier = UserDefaults.standard.string(forKey: PendingKeys.codeVerifier)
        let storedState = UserDefaults.standard.string(forKey: PendingKeys.state)

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            errorMessage = "Invalid callback URL"
            clearPendingState()
            return
        }

        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })

        if let error = params["error"] {
            errorMessage = "OAuth error: \(error)"
            clearPendingState()
            return
        }

        guard let code = params["code"],
              let state = params["state"],
              state == pendingState || state == storedState else {
            errorMessage = "State mismatch - possible CSRF attack or session expired"
            clearPendingState()
            return
        }

        let codeVerifier = pendingCodeVerifier ?? storedVerifier
        guard let verifier = codeVerifier else {
            errorMessage = "PKCE verifier not found. Please try connecting again."
            clearPendingState()
            return
        }

        await exchangeCodeForToken(code: code, codeVerifier: verifier)
        clearPendingState()
    }

    /// Disconnect and clear stored tokens
    func disconnect() throws {
        var settings = settingsService.loadDeviantArtSettings()
        settings.accessToken = nil
        settings.refreshToken = nil
        settings.tokenExpiry = nil
        try settingsService.saveDeviantArtSettings(settings)
        client?.clearAuthToken()
        isAuthenticated = false
        profile = nil
        deviations = []
        stashStacks = []
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Upload & Publish

    /// Upload a file to Sta.sh
    func uploadToStash(
        fileURL: URL,
        title: String,
        tags: [String]? = nil,
        artistComments: String? = nil
    ) async throws {
        guard let client else {
            throw AppError.apiAuthenticationFailed("DeviantArt client not configured")
        }

        guard client.isAuthenticated else {
            throw AppError.apiAuthenticationFailed("Not authenticated with DeviantArt")
        }

        let stashItem = try await client.stashSubmit(
            filename: fileURL.lastPathComponent,
            title: title,
            artistComments: artistComments,
            tags: tags
        )

        // Add to local stash stacks for immediate UI feedback
        let newStack = DeviantArtClient.StashStack(
            stackid: stashItem.itemid,
            title: title,
            items: [stashItem]
        )
        stashStacks.insert(newStack, at: 0)
    }

    /// Publish a stash item as a deviation
    func publishFromStash(
        stashId: String,
        title: String,
        category: String? = nil,
        isMature: Bool = false,
        matureLevel: String? = nil,
        allowsComments: Bool = true
    ) async throws {
        guard let client else {
            throw AppError.apiAuthenticationFailed("DeviantArt client not configured")
        }

        guard client.isAuthenticated else {
            throw AppError.apiAuthenticationFailed("Not authenticated with DeviantArt")
        }

        _ = try await client.stashPublish(
            stashId: stashId,
            title: title,
            category: category,
            isMature: isMature,
            matureLevel: matureLevel,
            allowsComments: allowsComments
        )

        // Refresh gallery to show the new deviation
        await refresh()
    }

    // MARK: - Private OAuth Helpers

    private struct PKCE {
        let verifier: String
        let challenge: String
    }

    private func generatePKCE() -> PKCE {
        let uuid1 = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let uuid2 = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let verifier = String((uuid1 + uuid2).prefix(128))

        guard let data = verifier.data(using: .utf8) else {
            return PKCE(verifier: verifier, challenge: "")
        }
        let hash = SHA256.hash(data: data)
        let hashData = Data(hash)
        let challenge = hashData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return PKCE(verifier: verifier, challenge: challenge)
    }

    private func buildAuthURL(
        settings: SettingsService.DeviantArtSettings,
        state: String,
        codeChallenge: String
    ) -> URL? {
        var components = URLComponents(string: "https://www.deviantart.com/oauth2/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: settings.clientId),
            URLQueryItem(name: "redirect_uri", value: settings.redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: "browse stash"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components?.url
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) async {
        let settings = settingsService.loadDeviantArtSettings()

        guard let tokenURL = URL(string: "https://www.deviantart.com/oauth2/token") else {
            errorMessage = "Invalid token URL"
            return
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "client_id": settings.clientId,
            "client_secret": settings.clientSecret,
            "code": code,
            "redirect_uri": settings.redirectURI,
            "code_verifier": codeVerifier
        ]

        let bodyString = body.map { key, value in
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
            return "\(key)=\(encoded)"
        }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            try await saveTokenResponse(data: data)
        } catch let urlError as URLError {
            errorMessage = "Network error (\(urlError.code.rawValue)): \(urlError.localizedDescription)"
        } catch {
            errorMessage = "Token exchange failed: \(error.localizedDescription)"
        }
    }

    private func saveTokenResponse(data: Data) async throws {
        struct TokenResponse: Decodable {
            let accessToken: String
            let refreshToken: String?
            let expiresIn: Int?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case expiresIn = "expires_in"
            }
        }

        do {
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)

            var settings = settingsService.loadDeviantArtSettings()
            settings.accessToken = response.accessToken
            settings.refreshToken = response.refreshToken
            if let expiresIn = response.expiresIn {
                settings.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            }
            try settingsService.saveDeviantArtSettings(settings)

            let token = HTTPClient.AuthToken(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresAt: settings.tokenExpiry,
                tokenType: "Bearer"
            )
            client?.setAuthToken(token)
            isAuthenticated = true
            await load()
        } catch let decodingError as DecodingError {
            throw decodingError
        } catch {
            throw error
        }
    }
}

private extension CharacterSet {
    static var urlQueryValueAllowed: CharacterSet {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        return allowed
    }
}

// MARK: - Preview Factories

#if DEBUG
extension DeviantArtViewModel {
    static var preview: DeviantArtViewModel {
        .previewManyDeviations
    }

    static var previewNotAuthenticated: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = false
        return viewModel
    }

    static var previewLoading: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.isLoading = true
        return viewModel
    }

    static var previewEmpty: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = .preview
        viewModel.deviations = []
        viewModel.stashStacks = []
        viewModel.lastUpdated = Date()
        return viewModel
    }

    static var previewError: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.errorMessage = "Failed to connect to DeviantArt API"
        return viewModel
    }

    static var previewSingleDeviation: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = .preview
        viewModel.deviations = [.preview]
        viewModel.stashStacks = []
        viewModel.lastUpdated = Date()
        return viewModel
    }

    static var previewManyDeviations: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = .preview
        let categories = ["Digital Art", "Photography", "Traditional", "3D", "Animation"]
        viewModel.deviations = (1...20).map { idx in
            let category: String? = idx % 5 == 0 ? nil : categories[idx % 5]
            let downloads: Int? = idx % 3 == 0 ? nil : idx * 2
            let isFavourited: Bool? = idx % 2 == 0 ? true : nil
            return DeviantArtClient.Deviation(
                deviationid: "\(idx)",
                url: "https://deviantart.com/art/sample-\(idx)",
                title: "Artwork Title #\(idx) with some extra text for testing",
                category: category,
                author: nil,
                stats: DeviantArtClient.Deviation.Stats(
                    views: idx * 100,
                    favourites: idx * 10,
                    comments: idx,
                    downloads: downloads
                ),
                publishedTime: "1700000000",
                allowsComments: idx % 3 != 0,
                isFavourited: isFavourited,
                isDeleted: nil,
                thumbs: nil,
                content: nil
            )
        }
        viewModel.lastUpdated = Date()
        return viewModel
    }

    static var previewWithStash: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = .preview
        viewModel.deviations = [.preview]
        viewModel.stashStacks = [
            DeviantArtClient.StashStack(
                stackid: "stack-1",
                title: "WIP Folder",
                items: [
                    DeviantArtClient.StashItem(
                        itemid: "item-1",
                        stackid: "stack-1",
                        title: "Draft Art",
                        path: nil,
                        size: nil,
                        fileSize: 2048000,
                        status: "draft",
                        thumb: nil,
                        position: 1
                    ),
                    DeviantArtClient.StashItem(
                        itemid: "item-2",
                        stackid: "stack-1",
                        title: "Another Draft",
                        path: nil,
                        size: nil,
                        fileSize: 1024000,
                        status: "published",
                        thumb: nil,
                        position: 2
                    )
                ]
            ),
            DeviantArtClient.StashStack(
                stackid: "stack-2",
                title: "Published Works",
                items: [
                    DeviantArtClient.StashItem(
                        itemid: "item-3",
                        stackid: "stack-2",
                        title: "Final Piece",
                        path: nil,
                        size: nil,
                        fileSize: 4096000,
                        status: "published",
                        thumb: nil,
                        position: 1
                    )
                ]
            )
        ]
        viewModel.lastUpdated = Date()
        return viewModel
    }

    static var previewEmptyStash: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = .preview
        viewModel.deviations = [.preview]
        viewModel.stashStacks = []
        viewModel.lastUpdated = Date()
        return viewModel
    }

    static var previewWithSelection: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = .preview
        viewModel.deviations = [
            .preview,
            DeviantArtClient.Deviation(
                deviationid: "preview-dev-1",
                url: "https://deviantart.com/art/selected",
                title: "Selected Deviation",
                category: "Digital Art",
                author: nil,
                stats: DeviantArtClient.Deviation.Stats(
                    views: 9999,
                    favourites: 888,
                    comments: 77,
                    downloads: 66
                ),
                publishedTime: "1700000000",
                allowsComments: true,
                isFavourited: nil,
                isDeleted: nil,
                thumbs: nil,
                content: nil
            )
        ]
        viewModel.lastUpdated = Date()
        return viewModel
    }

    static var previewRefreshing: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = .preview
        viewModel.deviations = [.preview]
        viewModel.isRefreshing = true
        viewModel.lastUpdated = Date().addingTimeInterval(-300)
        return viewModel
    }

    static var previewWithTimestamp: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = .preview
        viewModel.deviations = [.preview]
        viewModel.lastUpdated = Date().addingTimeInterval(-3600)
        return viewModel
    }

    static var previewNoStats: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = .preview
        viewModel.deviations = [
            DeviantArtClient.Deviation(
                deviationid: "no-stats",
                url: "https://deviantart.com/art/no-stats",
                title: "Deviation Without Stats",
                category: nil,
                author: nil,
                stats: nil,
                publishedTime: nil,
                allowsComments: nil,
                isFavourited: nil,
                isDeleted: nil,
                thumbs: nil,
                content: nil
            )
        ]
        viewModel.lastUpdated = Date()
        return viewModel
    }

    static var previewLongUsername: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = DeviantArtClient.UserProfile(
            user: DeviantArtClient.UserProfile.UserInfo(
                userid: "123",
                username: "VeryLongUsernameThatTestsLayoutHandling",
                usericon: "https://a.deviantart.net/avatars/default.png",
                type: nil
            ),
            stats: DeviantArtClient.UserProfile.UserStats(
                watchers: 1000,
                friends: 50,
                deviations: 200
            )
        )
        viewModel.deviations = [.preview]
        viewModel.lastUpdated = Date()
        return viewModel
    }

    static var previewNoProfileStats: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = DeviantArtClient.UserProfile(
            user: DeviantArtClient.UserProfile.UserInfo(
                userid: "456",
                username: "newartist",
                usericon: nil,
                type: nil
            ),
            stats: nil
        )
        viewModel.deviations = [.preview]
        viewModel.lastUpdated = Date()
        return viewModel
    }
}

extension DeviantArtClient.UserProfile {
    static var preview: DeviantArtClient.UserProfile {
        DeviantArtClient.UserProfile(
            user: DeviantArtClient.UserProfile.UserInfo(
                userid: "123",
                username: "artcreator",
                usericon: "https://a.deviantart.net/avatars/default.png",
                type: "regular"
            ),
            stats: DeviantArtClient.UserProfile.UserStats(
                watchers: 150,
                friends: 23,
                deviations: 42
            )
        )
    }
}

extension DeviantArtClient.Deviation {
    static var preview: DeviantArtClient.Deviation {
        DeviantArtClient.Deviation(
            deviationid: "1",
            url: "https://deviantart.com/art/sample-1",
            title: "Sample Artwork",
            category: "Digital Art",
            author: DeviantArtClient.Deviation.User(
                userid: "123",
                username: "artcreator",
                usericon: "https://a.deviantart.net/avatars/default.png"
            ),
            stats: DeviantArtClient.Deviation.Stats(
                views: 1200,
                favourites: 150,
                comments: 25,
                downloads: 45
            ),
            publishedTime: "1700000000",
            allowsComments: true,
            isFavourited: false,
            isDeleted: false,
            thumbs: [
                DeviantArtClient.Deviation.Thumb(
                    src: "https://example.com/thumb.jpg",
                    width: 400,
                    height: 300
                )
            ],
            content: DeviantArtClient.Deviation.ContentInfo(
                src: "https://example.com/full.jpg",
                width: 1920,
                height: 1080,
                filesize: 2048000
            )
        )
    }
}
#endif
