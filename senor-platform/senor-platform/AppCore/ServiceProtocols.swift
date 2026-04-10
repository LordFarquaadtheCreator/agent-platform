import Foundation

// MARK: - Service Protocols for Testability

/// Protocol for agent naming operations - enables mocking in tests
public protocol AgentNamingServiceProtocol: Sendable {
    func generateUniqueName() async throws -> AgentNamingService.GeneratedName
    func names(from category: NameCategory) -> [String]
    func suggestNames(count: Int, category: NameCategory?) async throws -> [AgentNamingService.GeneratedName]
}

/// Protocol for cache operations - enables mocking in tests
public protocol CacheServiceProtocol: Sendable {
    func get(platform: String, cacheKey: String) async throws -> RemotePostCacheRecord?
    func set(platform: String, cacheKey: String, payload: Encodable, stats: Encodable?, ttl: TimeInterval) async throws
    func invalidate(platform: String, cacheKey: String) async throws
    func invalidateAll(platform: String) async throws
    func cleanupExpired() async throws
}

/// Protocol for content versioning operations - enables mocking in tests
public protocol ContentVersioningServiceProtocol: Sendable {
    func createVersion(contentId: String, contentJson: String, changeReason: String?, editedBy: String) async throws -> GeneratedContentVersionRecord
    func listVersions(contentId: String) async throws -> [GeneratedContentVersionRecord]
    func getVersion(contentId: String, version: Int) async throws -> GeneratedContentVersionRecord?
    func editContent(contentId: String, newContentJson: String, changeReason: String?, editedBy: String) async throws -> GeneratedContentRecord
    func revertToVersion(contentId: String, version: Int, changeReason: String?, editedBy: String) async throws -> GeneratedContentRecord
}

/// Protocol for approval operations - enables mocking in tests
public protocol ApprovalServiceProtocol: Sendable {
    func submitForApproval(contentId: String, batchToken: String?) async throws -> ApprovalQueueRecord
    func approve(contentId: String, approvedBy: String) async throws -> ApprovalQueueRecord
    func reject(contentId: String, reason: String?, rejectedBy: String) async throws -> ApprovalQueueRecord
    func getStatus(contentId: String) async throws -> ApprovalQueueRecord?
    func listPending(limit: Int) async throws -> [ApprovalQueueRecord]
    func batchApprove(contentIds: [String], approvedBy: String) async throws -> [ApprovalQueueRecord]
    func batchReject(contentIds: [String], reason: String?, rejectedBy: String) async throws -> [ApprovalQueueRecord]
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
