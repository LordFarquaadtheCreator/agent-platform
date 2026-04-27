import Foundation

// MARK: - Service Protocols for Testability

/// Protocol for agent naming operations - enables mocking in tests
public protocol AgentNamingServiceProtocol: Sendable {
    func generateUniqueName() async throws -> AgentNamingService.GeneratedName
    func names(from category: NameCategory) -> [String]
}

/// Protocol for cache operations - enables mocking in tests
public protocol CacheServiceProtocol: Sendable {
    func get<T: Codable & Sendable>(platform: String, cacheKey: String, as type: T.Type) async throws -> T?
    func cache<T: Codable & Sendable>(platform: String, cacheKey: String, data: T, category: CacheCategory) async throws
    func invalidate(platform: String, cacheKey: String) async throws
    func invalidateAll(platform: String) async throws
    func cleanupExpired() async throws
}

/// Protocol for content versioning operations - enables mocking in tests
public protocol ContentVersioningServiceProtocol: Sendable {
    func editContent(contentId: String, newContentJson: String, changeReason: String?, editedBy: String) async throws -> GeneratedContentRecord
    func restoreVersion(contentId: String, targetVersion: Int, changeReason: String?) async throws -> GeneratedContentRecord
}

/// Protocol for approval operations - enables mocking in tests
public protocol ApprovalServiceProtocol: Sendable {
    func approve(contentId: String, approvedBy: String) async throws -> ApprovalQueueRecord
    func reject(contentId: String, reason: String?, rejectedBy: String) async throws -> ApprovalQueueRecord
}

/// Protocol for settings operations - enables mocking in tests
public protocol SettingsServiceProtocol: Sendable {
    // DeviantArt
    func saveDeviantArtSettings(_ settings: SettingsService.DeviantArtSettings) throws
    func loadDeviantArtSettings() -> SettingsService.DeviantArtSettings

    // Patreon
    func savePatreonSettings(_ settings: SettingsService.PatreonSettings) throws
    func loadPatreonSettings() -> SettingsService.PatreonSettings

    // ComfyUI
    func saveComfyUISettings(_ settings: SettingsService.ComfyUISettings)
    func loadComfyUISettings() -> SettingsService.ComfyUISettings

    // Task Settings
    func taskScriptPath() -> String
    func setTaskScriptPath(_ path: String?)

    // General
    func saveGeneralSettings(_ settings: SettingsService.GeneralSettings)
    func loadGeneralSettings() -> SettingsService.GeneralSettings

    // Clear all
    func clearAllSettings() async throws
}

// MARK: - Protocol Conformance Extensions

extension AgentNamingService: AgentNamingServiceProtocol {}
extension CacheService: CacheServiceProtocol {}
extension ContentVersioningService: ContentVersioningServiceProtocol {}
extension ApprovalService: ApprovalServiceProtocol {}
extension SettingsService: SettingsServiceProtocol {}
