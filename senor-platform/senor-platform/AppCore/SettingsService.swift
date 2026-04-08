import Foundation

/// Service for managing application settings and integration configurations
@MainActor
public final class SettingsService: Sendable {
    private let defaults = UserDefaults.standard
    private let logger = AppLogger.general

    private enum Keys {
        static let deviantArtClientId = "deviantArt.clientId"
        static let deviantArtClientSecret = "deviantArt.clientSecret"
        static let deviantArtAccessToken = "deviantArt.accessToken"
        static let deviantArtRefreshToken = "deviantArt.refreshToken"
        static let deviantArtTokenExpiry = "deviantArt.tokenExpiry"

        static let patreonAccessToken = "patreon.accessToken"
        static let patreonCampaignId = "patreon.campaignId"
        static let patreonTokenExpiry = "patreon.tokenExpiry"

        static let comfyUIServerURL = "comfyUI.serverURL"
        static let comfyUITimeout = "comfyUI.timeout"

        static let launchAtLogin = "general.launchAtLogin"
        static let showNotifications = "general.showNotifications"
        static let logLevel = "general.logLevel"
    }

    public init() {}

    // MARK: - DeviantArt Settings

    public struct DeviantArtSettings: Codable, Sendable {
        public var clientId: String
        public var clientSecret: String
        public var accessToken: String?
        public var refreshToken: String?
        public var tokenExpiry: Date?

        public var isAuthenticated: Bool {
            accessToken != nil && tokenExpiry != nil && tokenExpiry! > Date()
        }
    }

    public func saveDeviantArtSettings(_ settings: DeviantArtSettings) {
        defaults.set(settings.clientId, forKey: Keys.deviantArtClientId)
        defaults.set(settings.clientSecret, forKey: Keys.deviantArtClientSecret)
        defaults.set(settings.accessToken, forKey: Keys.deviantArtAccessToken)
        defaults.set(settings.refreshToken, forKey: Keys.deviantArtRefreshToken)
        defaults.set(settings.tokenExpiry, forKey: Keys.deviantArtTokenExpiry)
        logger.info("Saved DeviantArt settings")
    }

    public func loadDeviantArtSettings() -> DeviantArtSettings {
        DeviantArtSettings(
            clientId: defaults.string(forKey: Keys.deviantArtClientId) ?? "",
            clientSecret: defaults.string(forKey: Keys.deviantArtClientSecret) ?? "",
            accessToken: defaults.string(forKey: Keys.deviantArtAccessToken),
            refreshToken: defaults.string(forKey: Keys.deviantArtRefreshToken),
            tokenExpiry: defaults.object(forKey: Keys.deviantArtTokenExpiry) as? Date
        )
    }

    // MARK: - Patreon Settings

    public struct PatreonSettings: Codable, Sendable {
        public var accessToken: String
        public var campaignId: String?
        public var tokenExpiry: Date?

        public var isAuthenticated: Bool {
            !accessToken.isEmpty && (tokenExpiry == nil || tokenExpiry! > Date())
        }
    }

    public func savePatreonSettings(_ settings: PatreonSettings) {
        defaults.set(settings.accessToken, forKey: Keys.patreonAccessToken)
        defaults.set(settings.campaignId, forKey: Keys.patreonCampaignId)
        defaults.set(settings.tokenExpiry, forKey: Keys.patreonTokenExpiry)
        logger.info("Saved Patreon settings")
    }

    public func loadPatreonSettings() -> PatreonSettings {
        PatreonSettings(
            accessToken: defaults.string(forKey: Keys.patreonAccessToken) ?? "",
            campaignId: defaults.string(forKey: Keys.patreonCampaignId),
            tokenExpiry: defaults.object(forKey: Keys.patreonTokenExpiry) as? Date
        )
    }

    // MARK: - ComfyUI Settings

    public struct ComfyUISettings: Codable, Sendable {
        public var serverURL: String
        public var timeout: Int

        public init(serverURL: String = "http://127.0.0.1:8188", timeout: Int = 300) {
            self.serverURL = serverURL
            self.timeout = timeout
        }
    }

    public func saveComfyUISettings(_ settings: ComfyUISettings) {
        defaults.set(settings.serverURL, forKey: Keys.comfyUIServerURL)
        defaults.set(settings.timeout, forKey: Keys.comfyUITimeout)
        logger.info("Saved ComfyUI settings")
    }

    public func loadComfyUISettings() -> ComfyUISettings {
        let timeout = defaults.integer(forKey: Keys.comfyUITimeout)
        return ComfyUISettings(
            serverURL: defaults.string(forKey: Keys.comfyUIServerURL) ?? "http://127.0.0.1:8188",
            timeout: timeout != 0 ? timeout : 300
        )
    }

    // MARK: - General Settings

    public struct GeneralSettings: Codable, Sendable {
        public var launchAtLogin: Bool
        public var showNotifications: Bool
        public var logLevel: String

        public init(launchAtLogin: Bool = false, showNotifications: Bool = true, logLevel: String = "info") {
            self.launchAtLogin = launchAtLogin
            self.showNotifications = showNotifications
            self.logLevel = logLevel
        }
    }

    public func saveGeneralSettings(_ settings: GeneralSettings) {
        defaults.set(settings.launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(settings.showNotifications, forKey: Keys.showNotifications)
        defaults.set(settings.logLevel, forKey: Keys.logLevel)
        logger.info("Saved general settings")
    }

    public func loadGeneralSettings() -> GeneralSettings {
        GeneralSettings(
            launchAtLogin: defaults.bool(forKey: Keys.launchAtLogin),
            showNotifications: defaults.object(forKey: Keys.showNotifications) as? Bool ?? true,
            logLevel: defaults.string(forKey: Keys.logLevel) ?? "info"
        )
    }

    // MARK: - Clear Settings

    public func clearAllSettings() {
        let keys = [
            Keys.deviantArtClientId, Keys.deviantArtClientSecret, Keys.deviantArtAccessToken,
            Keys.deviantArtRefreshToken, Keys.deviantArtTokenExpiry,
            Keys.patreonAccessToken, Keys.patreonCampaignId, Keys.patreonTokenExpiry,
            Keys.comfyUIServerURL, Keys.comfyUITimeout,
            Keys.launchAtLogin, Keys.showNotifications, Keys.logLevel
        ]

        for key in keys {
            defaults.removeObject(forKey: key)
        }

        logger.warning("All settings cleared")
    }
}
