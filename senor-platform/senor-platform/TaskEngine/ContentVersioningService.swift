import Foundation

/// Service for managing content versioning and history
public final class ContentVersioningService {
    private let contentRepository: GeneratedContentRepository
    private let logger = AppLogger.general

    public init(contentRepository: GeneratedContentRepository) {
        self.contentRepository = contentRepository
    }

    /// Edit content and create new version (full snapshot)
    public func editContent(
        contentId: String,
        newContentJson: String,
        changeReason: String? = nil,
        editedBy: String = "user"
    ) async throws -> GeneratedContentRecord {
        // Validate JSON
        guard let data = newContentJson.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw AppError.invalidJSON("Invalid JSON content")
        }

        // Load current content
        guard let content = try await contentRepository.getById(id: contentId) else {
            throw AppError.invalidTaskConfiguration("Content not found: \(contentId)")
        }

        // Create new version snapshot
        let newVersionNumber = content.currentVersion + 1
        let version = GeneratedContentVersionRecord(
            generatedContentId: contentId,
            version: newVersionNumber,
            contentSnapshotJson: newContentJson,
            changeReason: changeReason,
            editedBy: editedBy
        )
        _ = try await contentRepository.createVersion(version: version)

        // Update content with new version
        var updatedContent = content
        updatedContent.generatedContentJson = newContentJson
        updatedContent.currentVersion = newVersionNumber
        updatedContent.updatedAt = Date()

        let saved = try await contentRepository.update(content: updatedContent)

        logger.info("Created content version \(newVersionNumber) for \(contentId)")

        return saved
    }

    /// Restore a previous version (creates new version with old content)
    public func restoreVersion(
        contentId: String,
        targetVersion: Int,
        changeReason: String? = nil
    ) async throws -> GeneratedContentRecord {
        // Load target version
        guard let target = try await contentRepository.getVersion(
            contentId: contentId,
            version: targetVersion
        ) else {
            throw AppError.contentVersioningFailed("Version \(targetVersion) not found")
        }

        // Create new version with restored content
        let reason = changeReason ?? "Restored from version \(targetVersion)"
        return try await editContent(
            contentId: contentId,
            newContentJson: target.contentSnapshotJson,
            changeReason: reason,
            editedBy: "restore"
        )
    }

    /// Preview a version without restoring
    public func previewVersion(
        contentId: String,
        version: Int
    ) async throws -> String {
        guard let versionRecord = try await contentRepository.getVersion(
            contentId: contentId,
            version: version
        ) else {
            throw AppError.contentVersioningFailed("Version \(version) not found")
        }

        return versionRecord.contentSnapshotJson
    }

    /// Get full version history
    public func getVersionHistory(contentId: String) async throws -> [VersionInfo] {
        let versions = try await contentRepository.listVersions(contentId: contentId)

        return versions.map { version in
            VersionInfo(
                version: version.version,
                createdAt: version.createdAt,
                editedBy: version.editedBy ?? "unknown",
                changeReason: version.changeReason,
                preview: String(version.contentSnapshotJson.prefix(100)) + "..."
            )
        }
    }

    /// Compare two versions
    public func compareVersions(
        contentId: String,
        versionA: Int,
        versionB: Int
    ) async throws -> VersionDiff {
        guard let recordA = try await contentRepository.getVersion(contentId: contentId, version: versionA),
              let recordB = try await contentRepository.getVersion(contentId: contentId, version: versionB) else {
            throw AppError.contentVersioningFailed("One or both versions not found")
        }

        return VersionDiff(
            fromVersion: versionA,
            toVersion: versionB,
            fromContent: recordA.contentSnapshotJson,
            toContent: recordB.contentSnapshotJson
        )
    }

    /// Get current version info
    public func getCurrentVersion(contentId: String) async throws -> VersionInfo? {
        guard let content = try await contentRepository.getById(id: contentId) else {
            return nil
        }

        guard let version = try await contentRepository.getVersion(
            contentId: contentId,
            version: content.currentVersion
        ) else {
            return nil
        }

        return VersionInfo(
            version: version.version,
            createdAt: version.createdAt,
            editedBy: version.editedBy ?? "unknown",
            changeReason: version.changeReason,
            preview: String(version.contentSnapshotJson.prefix(100)) + "..."
        )
    }
}

// MARK: - Result Types

public struct VersionInfo: Hashable, Identifiable, Sendable {
    public var id: Int { version }
    public let version: Int
    public let createdAt: Date
    public let editedBy: String
    public let changeReason: String?
    public let preview: String

    public var description: String {
        let dateStr = ISO8601DateFormatter().string(from: createdAt)
        if let reason = changeReason {
            return "v\(version) by \(editedBy) on \(dateStr) - \(reason)"
        }
        return "v\(version) by \(editedBy) on \(dateStr)"
    }
}

public struct VersionDiff: Sendable {
    public let fromVersion: Int
    public let toVersion: Int
    public let fromContent: String
    public let toContent: String

    public var hasChanges: Bool {
        fromContent != toContent
    }
}
