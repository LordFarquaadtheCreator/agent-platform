import Foundation

/// Service for managing application settings and integration configurations
@MainActor
public final class SettingsService: Sendable {
    private let defaults = UserDefaults.standard
    private let logger = AppLogger.general

    private enum Keys {
        // UserDefaults keys for non-sensitive data
        static let deviantArtTokenExpiry = "deviantArt.tokenExpiry"
        static let patreonCampaignId = "patreon.campaignId"
        static let patreonTokenExpiry = "patreon.tokenExpiry"
        static let comfyUIServerURL = "comfyUI.serverURL"
        static let comfyUITimeout = "comfyUI.timeout"
        static let taskScriptPath = "task.scriptPath"
        static let launchAtLogin = "general.launchAtLogin"
        static let showNotifications = "general.showNotifications"
        static let logLevel = "general.logLevel"
    }

    // MARK: - Task Settings

    /// Get the configured task script path, or return the default
    public func taskScriptPath() -> String {
        // First check UserDefaults for custom path
        if let customPath = defaults.string(forKey: Keys.taskScriptPath), !customPath.isEmpty {
            return customPath
        }
        // Fall back to bundle resource or system path
        return Bundle.main.path(forResource: "senor-task", ofType: nil)
            ?? "/usr/local/bin/senor-task"
    }

    /// Set a custom task script path (nil to reset to default)
    public func setTaskScriptPath(_ path: String?) {
        if let path = path, !path.isEmpty {
            defaults.set(path, forKey: Keys.taskScriptPath)
            logger.info("Set custom task script path: \(path)")
        } else {
            defaults.removeObject(forKey: Keys.taskScriptPath)
            logger.info("Reset task script path to default")
        }
    }

    // Keychain keys for sensitive credentials
    private enum KeychainKeys: String {
        case deviantArtClientId = "deviantart_client_id"
        case deviantArtClientSecret = "deviantart_client_secret"
        case patreonAccessToken = "patreon_access_token"
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

    public func saveDeviantArtSettings(_ settings: DeviantArtSettings) throws {
        // Store ALL credentials in Keychain for security, not UserDefaults
        let keychain = Keychain()
        try keychain.save(string: settings.clientId, account: KeychainKeys.deviantArtClientId.rawValue)
        try keychain.save(string: settings.clientSecret, account: KeychainKeys.deviantArtClientSecret.rawValue)
        if let accessToken = settings.accessToken {
            try keychain.save(string: accessToken, key: .deviantArtAccessToken)
        }
        if let refreshToken = settings.refreshToken {
            try keychain.save(string: refreshToken, key: .deviantArtRefreshToken)
        }
        defaults.set(settings.tokenExpiry, forKey: Keys.deviantArtTokenExpiry)
        logger.info("Saved DeviantArt settings to Keychain")
    }

    public func loadDeviantArtSettings() -> DeviantArtSettings {
        let keychain = Keychain()
        return DeviantArtSettings(
            clientId: keychain.retrieveString(account: KeychainKeys.deviantArtClientId.rawValue) ?? "",
            clientSecret: keychain.retrieveString(account: KeychainKeys.deviantArtClientSecret.rawValue) ?? "",
            accessToken: keychain.retrieveString(key: .deviantArtAccessToken),
            refreshToken: keychain.retrieveString(key: .deviantArtRefreshToken),
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

    public func savePatreonSettings(_ settings: PatreonSettings) throws {
        // Store sensitive token in Keychain, not UserDefaults
        let keychain = Keychain()
        if !settings.accessToken.isEmpty {
            try keychain.save(string: settings.accessToken, account: KeychainKeys.patreonAccessToken.rawValue)
        }
        defaults.set(settings.campaignId, forKey: Keys.patreonCampaignId)
        defaults.set(settings.tokenExpiry, forKey: Keys.patreonTokenExpiry)
        logger.info("Saved Patreon settings to Keychain")
    }

    public func loadPatreonSettings() -> PatreonSettings {
        let keychain = Keychain()
        let accessToken = keychain.retrieveString(account: KeychainKeys.patreonAccessToken.rawValue) ?? ""
        return PatreonSettings(
            accessToken: accessToken,
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

    public func clearAllSettings() async throws {
        let keys = [
            Keys.deviantArtTokenExpiry,
            Keys.patreonCampaignId, Keys.patreonTokenExpiry,
            Keys.comfyUIServerURL, Keys.comfyUITimeout,
            Keys.launchAtLogin, Keys.showNotifications, Keys.logLevel
        ]

        for key in keys {
            defaults.removeObject(forKey: key)
        }

        // Also clear sensitive credentials from Keychain
        let keychain = Keychain()
        try keychain.delete(account: KeychainKeys.deviantArtClientId.rawValue)
        try keychain.delete(account: KeychainKeys.deviantArtClientSecret.rawValue)
        try keychain.delete(key: Keychain.Key.deviantArtAccessToken)
        try keychain.delete(key: Keychain.Key.deviantArtRefreshToken)
        try keychain.delete(account: KeychainKeys.patreonAccessToken.rawValue)
        try keychain.delete(key: Keychain.Key.patreonCreatorToken)

        logger.warning("All settings cleared (including Keychain credentials)")
    }
}
