import Foundation
import Combine
import CryptoKit

@MainActor
public final class DeviantArtModel: ObservableObject {
    @Published public private(set) var profile: DeviantArtClient.UserProfile?
    @Published public private(set) var deviations: [DeviantArtClient.Deviation] = []
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
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try await client.getUserProfile()
            let gallery = try await client.getGalleryAll(limit: 24)
            deviations = gallery.results
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
        isAuthenticated = false
        profile = nil
        deviations = []
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
            URLQueryItem(name: "scope", value: "browse"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components?.url
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) async {
        let settings = settingsService.loadDeviantArtSettings()

        var request = URLRequest(url: URL(string: "https://www.deviantart.com/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = [
            "grant_type": "authorization_code",
            "client_id": settings.clientId,
            "client_secret": settings.clientSecret,
            "code": code,
            "redirect_uri": settings.redirectURI,
            "code_verifier": codeVerifier
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }.joined(separator: "&").data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            try await saveTokenResponse(data: data)
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
    }
}

private extension CharacterSet {
    static var urlQueryValueAllowed: CharacterSet {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        return allowed
    }
}
