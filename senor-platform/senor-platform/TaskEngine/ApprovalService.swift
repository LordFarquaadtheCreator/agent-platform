import Foundation

/// Service for managing content approval workflows
public final class ApprovalService: Sendable {
    private let approvalRepository: ApprovalQueueRepository
    private let contentRepository: GeneratedContentRepository
    private let publicationTargetRepository: PublicationTargetRepository
    private let logger = AppLogger.general

    public init(
        approvalRepository: ApprovalQueueRepository,
        contentRepository: GeneratedContentRepository,
        publicationTargetRepository: PublicationTargetRepository
    ) {
        self.approvalRepository = approvalRepository
        self.contentRepository = contentRepository
        self.publicationTargetRepository = publicationTargetRepository
    }

    // MARK: - Individual Approvals

    /// Approve a single content item
    public func approve(
        contentId: String,
        approvedBy: String = "user"
    ) async throws -> ApprovalQueueRecord {
        guard let queueEntry = try await approvalRepository.getByContent(contentId: contentId) else {
            throw AppError.approvalStateInvalid("Content not in approval queue: \(contentId)")
        }

        guard queueEntry.approvalStatus == "pending" else {
            throw AppError.approvalStateInvalid("Content is already \(queueEntry.approvalStatus)")
        }

        var updated = queueEntry
        updated.approvalStatus = "approved"
        updated.approvedBy = approvedBy
        updated.approvedAt = Date()
        updated.updatedAt = Date()

        let saved = try await approvalRepository.update(entry: updated)
        logger.info("Approved content: \(contentId)")

        return saved
    }

    /// Reject a single content item
    public func reject(
        contentId: String,
        reason: String? = nil,
        rejectedBy: String = "user"
    ) async throws -> ApprovalQueueRecord {
        guard let queueEntry = try await approvalRepository.getByContent(contentId: contentId) else {
            throw AppError.approvalStateInvalid("Content not in approval queue: \(contentId)")
        }

        guard queueEntry.approvalStatus == "pending" else {
            throw AppError.approvalStateInvalid("Content is already \(queueEntry.approvalStatus)")
        }

        var updated = queueEntry
        updated.approvalStatus = "rejected"
        updated.rejectedAt = Date()
        updated.rejectionReason = reason
        updated.updatedAt = Date()

        let saved = try await approvalRepository.update(entry: updated)
        logger.info("Rejected content: \(contentId)")

        return saved
    }

    /// Reset approval status (for re-review)
    public func reset(contentId: String) async throws -> ApprovalQueueRecord {
        guard let queueEntry = try await approvalRepository.getByContent(contentId: contentId) else {
            throw AppError.approvalStateInvalid("Content not in approval queue: \(contentId)")
        }

        var updated = queueEntry
        updated.approvalStatus = "pending"
        updated.approvedBy = nil
        updated.approvedAt = nil
        updated.rejectedAt = nil
        updated.rejectionReason = nil
        updated.batchToken = nil
        updated.updatedAt = Date()

        let saved = try await approvalRepository.update(entry: updated)
        logger.info("Reset approval status for content: \(contentId)")

        return saved
    }

    // MARK: - Batch Operations

    /// Approve multiple content items
    public func approveBatch(
        contentIds: [String],
        approvedBy: String = "user"
    ) async throws -> BatchResult {
        let batchToken = UUID().uuidString
        var results: [String: Result<ApprovalQueueRecord, Error>] = [:]
        var successCount = 0
        var failureCount = 0

        for contentId in contentIds {
            do {
                // First check if entry exists and update batch token
                if var entry = try await approvalRepository.getByContent(contentId: contentId) {
                    entry.batchToken = batchToken
                    _ = try await approvalRepository.update(entry: entry)
                }

                let result = try await approve(contentId: contentId, approvedBy: approvedBy)
                results[contentId] = .success(result)
                successCount += 1
            } catch {
                results[contentId] = .failure(error)
                failureCount += 1
            }
        }

        logger.info("Batch approval completed: \(successCount) succeeded, \(failureCount) failed")

        return BatchResult(
            batchToken: batchToken,
            totalCount: contentIds.count,
            successCount: successCount,
            failureCount: failureCount,
            results: results
        )
    }

    /// Reject multiple content items
    public func rejectBatch(
        contentIds: [String],
        reason: String? = nil,
        rejectedBy: String = "user"
    ) async throws -> BatchResult {
        let batchToken = UUID().uuidString
        var results: [String: Result<ApprovalQueueRecord, Error>] = [:]
        var successCount = 0
        var failureCount = 0

        for contentId in contentIds {
            do {
                if var entry = try await approvalRepository.getByContent(contentId: contentId) {
                    entry.batchToken = batchToken
                    _ = try await approvalRepository.update(entry: entry)
                }

                let result = try await reject(contentId: contentId, reason: reason, rejectedBy: rejectedBy)
                results[contentId] = .success(result)
                successCount += 1
            } catch {
                results[contentId] = .failure(error)
                failureCount += 1
            }
        }

        logger.info("Batch rejection completed: \(successCount) succeeded, \(failureCount) failed")

        return BatchResult(
            batchToken: batchToken,
            totalCount: contentIds.count,
            successCount: successCount,
            failureCount: failureCount,
            results: results
        )
    }

    // MARK: - Publication Queue

    /// Queue approved content for publication to a platform
    public func queueForPublication(
        contentId: String,
        platform: String, // "deviantart" or "patreon"
        scheduledPublishAt: Date? = nil
    ) async throws -> PublicationTargetRecord {
        // Verify content is approved
        guard let queueEntry = try await approvalRepository.getByContent(contentId: contentId),
              queueEntry.approvalStatus == "approved" else {
            throw AppError.approvalStateInvalid("Content must be approved before publication")
        }

        // Create publication target
        let state: PublicationState = scheduledPublishAt == nil ? .pending : .scheduled
        let target = PublicationTargetRecord(
            generatedContentId: contentId,
            platform: platform,
            state: state,
            scheduledAt: scheduledPublishAt
        )

        let saved = try await publicationTargetRepository.create(target: target)
        logger.info("Queued for publication: \(contentId) -> \(platform)")

        return saved
    }

    /// Queue batch of approved content for publication
    public func queueBatchForPublication(
        contentIds: [String],
        platform: String,
        scheduledPublishAt: Date? = nil
    ) async throws -> [PublicationTargetRecord] {
        var results: [PublicationTargetRecord] = []

        for contentId in contentIds {
            do {
                let target = try await queueForPublication(
                    contentId: contentId,
                    platform: platform,
                    scheduledPublishAt: scheduledPublishAt
                )
                results.append(target)
            } catch {
                logger.error("Failed to queue \(contentId): \(error)")
            }
        }

        return results
    }

    // MARK: - Queries

    /// List pending approvals
    public func listPending(limit: Int = 50) async throws -> [ApprovalItem] {
        let entries = try await approvalRepository.listPending(limit: limit)

        var items: [ApprovalItem] = []
        for entry in entries {
            if let content = try? await contentRepository.getById(id: entry.generatedContentId) {
                items.append(ApprovalItem(
                    queueEntry: entry,
                    content: content
                ))
            }
        }

        return items
    }

    /// Get approval status for content
    public func getStatus(contentId: String) async throws -> ApprovalStatusInfo? {
        guard let entry = try await approvalRepository.getByContent(contentId: contentId) else {
            return nil
        }

        return ApprovalStatusInfo(
            status: entry.approvalStatus,
            approvedBy: entry.approvedBy,
            approvedAt: entry.approvedAt,
            rejectedAt: entry.rejectedAt,
            rejectionReason: entry.rejectionReason
        )
    }
}

// MARK: - Result Types

public struct BatchResult: Sendable {
    public let batchToken: String
    public let totalCount: Int
    public let successCount: Int
    public let failureCount: Int
    public let results: [String: Result<ApprovalQueueRecord, Error>]

    public var isCompleteSuccess: Bool { failureCount == 0 }
    public var isCompleteFailure: Bool { successCount == 0 }
}

public struct ApprovalItem: Sendable {
    public let queueEntry: ApprovalQueueRecord
    public let content: GeneratedContentRecord

    public var contentId: String { content.id }
    public var title: String { content.title }
    public var status: String { queueEntry.approvalStatus }
}

public struct ApprovalStatusInfo: Sendable {
    public let status: String
    public let approvedBy: String?
    public let approvedAt: Date?
    public let rejectedAt: Date?
    public let rejectionReason: String?

    public var isPending: Bool { status == "pending" }
    public var isApproved: Bool { status == "approved" }
    public var isRejected: Bool { status == "rejected" }
}
