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
    func editContent(
        contentId: String,
        newContentJson: String,
        changeReason: String?,
        editedBy: String
    ) async throws -> GeneratedContentRecord
    func restoreVersion(
        contentId: String,
        targetVersion: Int,
        changeReason: String?
    ) async throws -> GeneratedContentRecord
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

// MARK: - Integration Service Protocols

/// Protocol for DeviantArt operations - enables mocking in tests
public protocol DeviantArtServiceProtocol: Sendable {
    func stashSubmit(
        filename: String,
        title: String?,
        artistComments: String?,
        tags: [String]?,
        originalUrl: String?
    ) async throws -> DeviantArtClient.StashItem
    // swiftlint:disable:next function_parameter_count
    func stashPublish(
        stashId: String,
        title: String,
        category: String?,
        isMature: Bool,
        matureLevel: String?,
        allowsComments: Bool,
        galleryIds: [String]?,
        licenseOptions: [String: String]?
    ) async throws -> DeviantArtClient.StashPublishResponse
    func getDeviation(deviationId: String) async throws -> DeviantArtClient.Deviation
}

/// Protocol for Patreon operations - enables mocking in tests
public protocol PatreonServiceProtocol {
    func createPost(
        campaignId: String,
        title: String,
        content: String,
        isPaid: Bool?,
        isPublic: Bool?,
        tiers: [String]?,
        publishAt: Date?
    ) async throws -> PatreonClient.Post
    func getPublicURL(for postId: String) async throws -> String
    func getPost(postId: String, includeFields: [String]) async throws -> PatreonClient.Post
}

// MARK: - Protocol Conformance Extensions

extension AgentNamingService: AgentNamingServiceProtocol {}
extension CacheService: CacheServiceProtocol {}
extension ContentVersioningService: ContentVersioningServiceProtocol {}
extension ApprovalService: ApprovalServiceProtocol {}
extension SettingsService: SettingsServiceProtocol {}
extension DeviantArtClient: DeviantArtServiceProtocol {}
extension PatreonClient: PatreonServiceProtocol {}
