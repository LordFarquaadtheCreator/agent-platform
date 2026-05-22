import Foundation

/// Service for orchestrating publication to platforms
public final actor PublicationService {
    private let publicationRepository: PublicationTargetRepository
    private let contentRepository: GeneratedContentRepository
    private let cacheService: CacheService
    private let approvalQueueRepository: ApprovalQueueRepository
    private let settingsService: SettingsService
    private let deviantArtClient: DeviantArtServiceProtocol?
    private let patreonClient: PatreonServiceProtocol?
    private let logger = AppLogger.general
    public init(
        approvalQueueRepository: ApprovalQueueRepository,
        publicationRepository: PublicationTargetRepository,
        contentRepository: GeneratedContentRepository,
        cacheService: CacheService,
        settingsService: SettingsService,
        deviantArtClient: DeviantArtServiceProtocol? = nil,
        patreonClient: PatreonServiceProtocol? = nil
    ) {
        self.approvalQueueRepository = approvalQueueRepository
        self.publicationRepository = publicationRepository
        self.contentRepository = contentRepository
        self.cacheService = cacheService
        self.settingsService = settingsService
        self.deviantArtClient = deviantArtClient
        self.patreonClient = patreonClient
    }

    // MARK: - Publication Execution

    /// Publish approved content to DeviantArt (stash -> publish flow)
    public func publishToDeviantArt(
        contentId: String,
        title: String? = nil,
        category: String? = nil,
        isMature: Bool = false,
        tags: [String]? = nil
    ) async throws -> PublicationTargetRecord {
        guard let client = deviantArtClient else {
            throw AppError.publicationFailed("DeviantArt client not configured")
        }

        guard let content = try await contentRepository.getById(id: contentId) else {
            throw AppError.publicationFailed("Content not found: \(contentId)")
        }

        // Get or create publication target
        let targets = try await publicationRepository.listByContent(contentId: contentId)
        var target = targets.first { $0.platform == "deviantart" }

        if target == nil {
            target = try await publicationRepository.create(target: PublicationTargetRecord(
                generatedContentId: contentId,
                platform: "deviantart",
                state: .publishing
            ))
        }

        guard var mutableTarget = target else {
            throw AppError.publicationFailed("Failed to create publication target")
        }

        do {
            // Step 1: Submit to stash (simplified - assumes file content available)
            // In practice, the generated content would include file paths
            let stashTitle = title ?? content.title
            // PublicationService does not yet handle file content for DeviantArt image uploads
            let stashItem = try await client.stashSubmit(
                filename: "\(contentId).png",
                fileData: nil,
                title: stashTitle,
                artistComments: nil,
                tags: tags,
                originalUrl: nil
            )

            // Step 2: Publish from stash
            let publishResult = try await client.stashPublish(
                itemId: stashItem.itemid,
                title: stashTitle,
                category: category,
                isMature: isMature,
                matureLevel: nil,
                allowsComments: true,
                galleryIds: nil,
                licenseOptions: nil
            )

            // Update target with success
            mutableTarget.state = .published
            mutableTarget.remotePostId = publishResult.deviationid
            mutableTarget.remoteUrl = publishResult.url

            let saved = try await publicationRepository.update(target: mutableTarget)

            // Invalidate cache
            if let deviationId = publishResult.deviationid {
                try? await cacheService.invalidate(
                    platform: "deviantart",
                    cacheKey: CacheKey.deviation(id: deviationId).stringValue
                )
            }

            logger.info("Published to DeviantArt: \(contentId) -> \(publishResult.url ?? "unknown")")

            return saved
        } catch {
            // Update target with failure
            mutableTarget.state = .failed
            mutableTarget.errorMessage = error.localizedDescription
            _ = try? await publicationRepository.update(target: mutableTarget)

            throw AppError.publicationFailed("DeviantArt publish failed: \(error.localizedDescription)")
        }
    }

    /// Schedule a publication for later
    public func schedulePublication(
        contentId: String,
        platform: String,
        publishAt: Date
    ) async throws -> PublicationTargetRecord {
        let target = PublicationTargetRecord(
            generatedContentId: contentId,
            platform: platform,
            state: .scheduled,
            scheduledAt: publishAt
        )

        let saved = try await publicationRepository.create(target: target)
        logger.info("Scheduled publication: \(contentId) -> \(platform) at \(publishAt)")

        return saved
    }

    /// Execute scheduled publications that are due
    public func executeScheduledPublications() async throws {
        let dueTargets = try await publicationRepository.listPending(limit: 100)
        let now = Date()

        for target in dueTargets {
            guard let scheduledAt = target.scheduledAt,
                  scheduledAt <= now else {
                continue
            }

            do {
                switch target.platform {
                case "deviantart":
                    _ = try await publishToDeviantArt(contentId: target.generatedContentId)

                default:
                    break
                }
            } catch {
                logger.error("Failed scheduled publish: \(target.id) - \(error)")
            }
        }
    }

    /// Sync publication status with remote platform
    public func syncPublicationStatus(targetId: String) async throws -> PublicationTargetRecord {
        guard let target = try await publicationRepository.getById(id: targetId) else {
            throw AppError.publicationFailed("Target not found: \(targetId)")
        }

        guard let remoteId = target.remotePostId else {
            return target
        }

        var mutableTarget = target

        do {
            switch target.platform {
            case "deviantart":
                if let client = deviantArtClient {
                    let deviation = try await client.getDeviation(deviationId: remoteId)
                    // Update URL if changed
                    mutableTarget.remoteUrl = deviation.url
                }

            case "patreon":
                if let client = patreonClient {
                    let post = try await client.getPost(
                        postId: remoteId,
                        includeFields: ["title", "content", "is_paid", "is_public", "published_at", "url"]
                    )
                    mutableTarget.remoteUrl = post.attributes.url
                }

            default:
                break
            }

            return try await publicationRepository.update(target: mutableTarget)
        } catch {
            logger.error("Failed to sync status: \(targetId) - \(error)")
            return target
        }
    }

    // MARK: - Queries

    /// List publications for content
    public func listPublications(contentId: String) async throws -> [PublicationTargetRecord] {
        try await publicationRepository.listByContent(contentId: contentId)
    }

    /// Get publication statistics
    public func getStatistics() async throws -> PublicationStats {
        let allTargets = try await publicationRepository.listByPlatform(platform: "deviantart", limit: 1000)
        let patreonTargets = try await publicationRepository.listByPlatform(platform: "patreon", limit: 1000)

        let all = allTargets + patreonTargets

        return PublicationStats(
            total: all.count,
            published: all.filter { $0.state == .published }.count,
            scheduled: all.filter { $0.state == .scheduled }.count,
            pending: all.filter { $0.state == .pending }.count,
            failed: all.filter { $0.state == .failed }.count
        )
    }

    // MARK: - Private Methods

    private func extractDescription(from json: String) -> String {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }

        // Try to extract text content from various possible fields
        if let description = dict["description"] as? String {
            return description
        }
        if let text = dict["text"] as? String {
            return text
        }
        if let content = dict["content"] as? String {
            return content
        }

        // Return full JSON as fallback
        return json
    }
}

// MARK: - Statistics

public struct PublicationStats: Sendable {
    public let total: Int
    public let published: Int
    public let scheduled: Int
    public let pending: Int
    public let failed: Int

    public var successRate: Double {
        guard total > 0 else { return 0 }
        return Double(published) / Double(total)
    }
}
