import Foundation
import Combine
import CryptoKit

@MainActor
public final class DeviantArtModel: ObservableObject {
    @Published public private(set) var profile: DeviantArtClient.UserProfile?
    @Published public private(set) var deviations: [DeviantArtClient.Deviation] = []
    @Published public private(set) var stashStacks: [DeviantArtClient.StashStack] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var isConnecting = false

    private let client: DeviantArtClient?
    private let settingsService: SettingsService
    private var pendingCodeVerifier: String?
    private var pendingState: String?

    private enum PendingKeys {
        static let codeVerifier = "deviantArt.pendingCodeVerifier"
        static let state = "deviantArt.pendingState"
    }

    init(client: DeviantArtClient?, settingsService: SettingsService) {
        self.client = client
        self.settingsService = settingsService
        self.isAuthenticated = client?.isAuthenticated ?? settingsService.loadDeviantArtSettings().isAuthenticated
    }

    func load() async {
        print("[DeviantArt] load() starting...")
        let settings = settingsService.loadDeviantArtSettings()
        print("[DeviantArt] Settings loaded - hasAccessToken: \(settings.accessToken != nil), hasRefreshToken: \(settings.refreshToken != nil)")

        guard settings.isAuthenticated else {
            isAuthenticated = false
            print("[DeviantArt] Not authenticated in settings")
            return
        }
        guard let client, client.isAuthenticated else {
            isAuthenticated = false
            errorMessage = "Token expired. Please reconnect DeviantArt."
            print("[DeviantArt] Client not authenticated")
            return
        }
        print("[DeviantArt] Client authenticated, fetching data...")
        isLoading = true
        defer { isLoading = false }
        do {
            async let profileTask = client.getUserProfile()
            async let galleryTask = client.getGalleryAll(limit: 24)

            let (profileResult, galleryResult) = try await (profileTask, galleryTask)

            profile = profileResult
            deviations = galleryResult.results

            // Stash fetch is non-fatal (endpoint may not exist)
            do {
                let stashResult = try await client.getStashContents(limit: 24)
                stashStacks = stashResult.results
                print("[DeviantArt] Stash loaded: \(stashResult.results.count) stacks")
            } catch {
                print("[DeviantArt] Stash fetch skipped (endpoint unavailable): \(error.localizedDescription)")
                stashStacks = []
            }

            errorMessage = nil
            print("[DeviantArt] Load successful - profile: \(profileResult.user.username), deviations: \(galleryResult.results.count)")
        } catch {
            errorMessage = error.localizedDescription
            print("[DeviantArt] Load failed: \(error)")
        }
    }

    // MARK: - OAuth Flow

    /// Start the OAuth connection flow
    func startConnection() async -> URL? {
        print("[OAuth] Starting connection...")
        let settings = settingsService.loadDeviantArtSettings()
        guard !settings.clientId.isEmpty, !settings.clientSecret.isEmpty else {
            errorMessage = "Client ID and Client Secret required in Settings"
            print("[OAuth] Error: Missing client ID or secret")
            return nil
        }

        isConnecting = true
        defer { isConnecting = false }

        let pkce = generatePKCE()
        let state = UUID().uuidString
        print("[OAuth] Generated state: \(state)")

        // Persist to UserDefaults in case app restarts during OAuth
        UserDefaults.standard.set(pkce.verifier, forKey: PendingKeys.codeVerifier)
        UserDefaults.standard.set(state, forKey: PendingKeys.state)
        pendingCodeVerifier = pkce.verifier
        pendingState = state
        print("[OAuth] State and verifier persisted to UserDefaults")

        guard let authURL = buildAuthURL(settings: settings, state: state, codeChallenge: pkce.challenge) else {
            errorMessage = "Failed to build authorization URL"
            print("[OAuth] Error: Failed to build auth URL")
            clearPendingState()
            return nil
        }

        print("[OAuth] Auth URL built: \(authURL)")
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
        print("[OAuth] Callback received: \(url)")

        // Restore from UserDefaults if memory was cleared
        let storedVerifier = UserDefaults.standard.string(forKey: PendingKeys.codeVerifier)
        let storedState = UserDefaults.standard.string(forKey: PendingKeys.state)
        print("[OAuth] Stored state: \(storedState ?? "nil"), pending state: \(pendingState ?? "nil")")
        print("[OAuth] Stored verifier exists: \(storedVerifier != nil), pending verifier exists: \(pendingCodeVerifier != nil)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            errorMessage = "Invalid callback URL"
            print("[OAuth] Error: Invalid callback URL - no query items")
            clearPendingState()
            return
        }

        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })
        print("[OAuth] Callback params: \(params.keys)")

        if let error = params["error"] {
            errorMessage = "OAuth error: \(error)"
            print("[OAuth] Error from DeviantArt: \(error)")
            clearPendingState()
            return
        }

        guard let code = params["code"],
              let state = params["state"],
              state == pendingState || state == storedState else {
            errorMessage = "State mismatch - possible CSRF attack or session expired"
            print("[OAuth] State mismatch. Received: \(params["state"] ?? "nil"), expected: \(pendingState ?? "nil") or \(storedState ?? "nil")")
            clearPendingState()
            return
        }

        let codeVerifier = pendingCodeVerifier ?? storedVerifier
        guard let verifier = codeVerifier else {
            errorMessage = "PKCE verifier not found. Please try connecting again."
            print("[OAuth] Error: No code verifier available")
            clearPendingState()
            return
        }

        print("[OAuth] State verified, exchanging code for token...")
        await exchangeCodeForToken(code: code, codeVerifier: verifier)
        print("[OAuth] exchangeCodeForToken returned, errorMessage is nil: \(errorMessage == nil)")
        clearPendingState()
        print("[OAuth] Callback handling complete")
    }

    /// Disconnect and clear stored tokens
    func disconnect() throws {
        print("[DeviantArt] Disconnecting...")
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
        print("[DeviantArt] Disconnected successfully")
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
        print("[OAuth] exchangeCodeForToken starting...")
        let settings = settingsService.loadDeviantArtSettings()
        print("[OAuth] Settings loaded for token exchange")
        print("[OAuth] clientId empty: \(settings.clientId.isEmpty), clientSecret empty: \(settings.clientSecret.isEmpty)")
        print("[OAuth] redirectURI: \(settings.redirectURI)")
        print("[OAuth] code prefix: \(code.prefix(10))...")
        print("[OAuth] codeVerifier prefix: \(codeVerifier.prefix(10))...")

        guard let tokenURL = URL(string: "https://www.deviantart.com/oauth2/token") else {
            print("[OAuth] ERROR: Failed to create token URL")
            errorMessage = "Invalid token URL"
            return
        }
        print("[OAuth] Token URL valid: \(tokenURL)")

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
        print("[OAuth] Body params: grant_type=\(body["grant_type"]!), client_id empty=\(body["client_id"]!.isEmpty)")

        let bodyString = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }.joined(separator: "&")
        print("[OAuth] Body string length: \(bodyString.count)")
        request.httpBody = bodyString.data(using: .utf8)

        print("[OAuth] Starting URLSession.data(for:)...")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("[OAuth] URLSession completed")
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[OAuth] ERROR: Response is not HTTPURLResponse, type: \(type(of: response))")
                throw URLError(.badServerResponse)
            }
            print("[OAuth] Token exchange response: \(httpResponse.statusCode)")
            if let responseBody = String(data: data, encoding: .utf8) {
                print("[OAuth] Response body: \(responseBody)")
            }
            guard httpResponse.statusCode == 200 else {
                print("[OAuth] ERROR: Non-200 status code")
                throw URLError(.badServerResponse)
            }
            print("[OAuth] Calling saveTokenResponse...")
            try await saveTokenResponse(data: data)
            print("[OAuth] Token saved successfully")
        } catch let urlError as URLError {
            print("[OAuth] URLError caught: \(urlError.code.rawValue) - \(urlError.localizedDescription)")
            print("[OAuth] URLError failingURL: \(urlError.failingURL?.absoluteString ?? "nil")")
            errorMessage = "Network error (\(urlError.code.rawValue)): \(urlError.localizedDescription)"
        } catch {
            print("[OAuth] Generic error caught: \(error)")
            print("[OAuth] Error type: \(type(of: error))")
            errorMessage = "Token exchange failed: \(error.localizedDescription)"
        }
        print("[OAuth] exchangeCodeForToken finished")
    }

    private func saveTokenResponse(data: Data) async throws {
        print("[OAuth] saveTokenResponse starting...")
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
            print("[OAuth] TokenResponse decoded - accessToken prefix: \(response.accessToken.prefix(10))...")

            var settings = settingsService.loadDeviantArtSettings()
            settings.accessToken = response.accessToken
            settings.refreshToken = response.refreshToken
            if let expiresIn = response.expiresIn {
                settings.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
                print("[OAuth] Token expiry set to: \(settings.tokenExpiry!)")
            }
            print("[OAuth] Saving settings...")
            try settingsService.saveDeviantArtSettings(settings)
            print("[OAuth] Settings saved")

            let token = HTTPClient.AuthToken(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresAt: settings.tokenExpiry,
                tokenType: "Bearer"
            )
            print("[OAuth] Setting auth token on client...")
            client?.setAuthToken(token)
            isAuthenticated = true
            print("[OAuth] Calling load()...")
            await load()
            print("[OAuth] load() completed")
        } catch let decodingError as DecodingError {
            print("[OAuth] Decoding error: \(decodingError)")
            throw decodingError
        } catch {
            print("[OAuth] saveTokenResponse error: \(error)")
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
