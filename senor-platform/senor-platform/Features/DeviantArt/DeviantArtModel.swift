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
        // TODO: Re-enable once Swift 6 concurrency issues are resolved
    }

    private func cacheData(profile: DeviantArtClient.UserProfile, deviations: [DeviantArtClient.Deviation]) async {
        // Caching disabled due to Swift 6 concurrency issues with generic Sendable constraints
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

    private func buildAuthURL(settings: SettingsService.DeviantArtSettings, state: String, codeChallenge: String) -> URL? {
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

        let bodyString = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }.joined(separator: "&")
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

// MARK: - Previews

extension DeviantArtViewModel {
    static var preview: DeviantArtViewModel {
        let viewModel = DeviantArtViewModel(
            client: nil,
            settingsService: SettingsService(),
            cacheService: nil
        )
        viewModel.isAuthenticated = true
        viewModel.profile = DeviantArtClient.UserProfile.preview
        viewModel.deviations = [
            DeviantArtClient.Deviation.preview,
            DeviantArtClient.Deviation(
                deviationid: "2",
                url: "https://deviantart.com/art/sample-2",
                title: "Sample Artwork 2",
                category: "Photography",
                author: nil,
                stats: DeviantArtClient.Deviation.Stats(
                    views: 500,
                    favourites: 50,
                    comments: 5,
                    downloads: 10
                ),
                publishedTime: nil,
                allowsComments: false,
                isFavourited: nil,
                isDeleted: nil,
                thumbs: nil,
                content: nil
            )
        ]
        viewModel.stashStacks = []
        viewModel.lastUpdated = Date()
        return viewModel
    }
}

extension DeviantArtClient.UserProfile {
    static var preview: DeviantArtClient.UserProfile {
        DeviantArtClient.UserProfile(
            user: DeviantArtClient.UserProfile.UserInfo(
                userid: "123",
                username: "preview_user",
                usericon: "https://a.deviantart.net/avatars/default.png",
                type: nil
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
            url: "https://mwi.westpoint.edu/wp-content/uploads/2016/04/3264149-42-iron-man-iron-man-hd-8-free-spot-free-download-1.jpg",
            title: "Sample Artwork",
            category: "Digital Art",
            author: nil,
            stats: DeviantArtClient.Deviation.Stats(
                views: 1200,
                favourites: 150,
                comments: 25,
                downloads: 45
            ),
            publishedTime: nil,
            allowsComments: true,
            isFavourited: nil,
            isDeleted: nil,
            thumbs: nil,
            content: nil
        )
    }
}
