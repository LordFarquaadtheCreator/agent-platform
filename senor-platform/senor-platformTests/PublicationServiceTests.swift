import XCTest
@testable import senor_platform

// MARK: - Mock Service Implementations

actor MockDeviantArtService: DeviantArtServiceProtocol, AKDeviantArtClient {
    var stashItems: [String: DeviantArtClient.StashItem] = [:]
    var publishedItems: [String: DeviantArtClient.StashPublishResponse] = [:]
    var deviations: [String: DeviantArtClient.Deviation] = [:]

    var stashSubmitCallCount = 0
    var stashPublishCallCount = 0
    var getDeviationCallCount = 0

    var shouldFailStashSubmit = false
    var shouldFailStashPublish = false
    var shouldFailGetDeviation = false

    func setShouldFailStashSubmit(_ value: Bool) {
        shouldFailStashSubmit = value
    }

    func setShouldFailStashPublish(_ value: Bool) {
        shouldFailStashPublish = value
    }

    func stashSubmit(filename: String, fileData: Data?, title: String?, artistComments: String?, tags: [String]?, originalUrl: String?) async throws -> DeviantArtClient.StashItem {
        stashSubmitCallCount += 1

        if shouldFailStashSubmit {
            throw AppError.apiRequestFailed("stashSubmit", NSError(domain: "Mock", code: -1))
        }

        let item = DeviantArtClient.StashItem(
            itemid: "stash-\(filename)",
            stackid: nil,
            title: title ?? filename,
            path: "/stash/\(filename)",
            size: 1000,
            fileSize: 1024,
            status: "draft",
            thumb: nil,
            position: nil
        )
        stashItems[item.itemid] = item
        return item
    }

    func stashPublish(itemId: String, title: String, category: String?, isMature: Bool, matureLevel: String?, allowsComments: Bool, galleryIds: [String]?, licenseOptions: [String: String]?) async throws -> DeviantArtClient.StashPublishResponse {
        stashPublishCallCount += 1

        if shouldFailStashPublish {
            throw AppError.apiRequestFailed("stashPublish", NSError(domain: "Mock", code: -1))
        }

        let response = DeviantArtClient.StashPublishResponse(
            status: "published",
            deviationid: "dev-\(itemId)",
            url: "https://www.deviantart.com/test/art/\(title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "test")-123"
        )
        publishedItems[itemId] = response
        return response
    }

    func getDeviation(deviationId: String) async throws -> DeviantArtClient.Deviation {
        getDeviationCallCount += 1

        if shouldFailGetDeviation {
            throw AppError.apiRequestFailed("getDeviation", NSError(domain: "Mock", code: -1))
        }

        if let deviation = deviations[deviationId] {
            return deviation
        }

        return DeviantArtClient.Deviation(
            deviationid: deviationId,
            url: "https://www.deviantart.com/test/art/Test-123",
            title: "Test Deviation",
            category: "Digital Art",
            author: nil,
            stats: nil,
            publishedTime: nil,
            allowsComments: true,
            isFavourited: nil,
            isDeleted: false,
            thumbs: nil,
            content: nil
        )
    }

    // Test helpers
    func setStashItem(_ item: DeviantArtClient.StashItem, for id: String) {
        stashItems[id] = item
    }

    func setDeviation(_ deviation: DeviantArtClient.Deviation, for id: String) {
        deviations[id] = deviation
    }

    // MARK: - AKDeviantArtClient conformance

    func stashSubmit(filename: String, fileData: Data?, title: String, tags: [String]?) async throws -> AKStashItem {
        let item = try await stashSubmit(
            filename: filename,
            fileData: fileData,
            title: title,
            artistComments: nil,
            tags: tags,
            originalUrl: nil
        )
        return AKStashItem(itemid: item.itemid, title: item.title)
    }

    func stashPublish(itemId: String, title: String, category: String?, isMature: Bool) async throws -> AKPublishResult {
        let result = try await stashPublish(
            itemId: itemId,
            title: title,
            category: category,
            isMature: isMature,
            matureLevel: nil,
            allowsComments: true,
            galleryIds: nil,
            licenseOptions: nil
        )
        return AKPublishResult(deviationid: result.deviationid, url: result.url)
    }
}

actor MockPatreonService: PatreonServiceProtocol, AKPatreonClient {
    var posts: [String: PatreonClient.Post] = [:]
    var postURLs: [String: String] = [:]

    var getPublicURLCallCount = 0
    var getPostCallCount = 0

    var shouldFailGetPublicURL = false
    var shouldFailGetPost = false

    func setShouldFailGetPublicURL(_ value: Bool) {
        shouldFailGetPublicURL = value
    }

    func setShouldFailGetPost(_ value: Bool) {
        shouldFailGetPost = value
    }

    func getPublicURL(for postId: String) async throws -> String {
        getPublicURLCallCount += 1
        if shouldFailGetPublicURL {
            throw AppError.apiRequestFailed("getPublicURL", NSError(domain: "Mock", code: -1))
        }
        return postURLs[postId] ?? "https://www.patreon.com/posts/\(postId)"
    }

    func getPost(postId: String, includeFields: [String]) async throws -> PatreonClient.Post {
        getPostCallCount += 1
        if shouldFailGetPost {
            throw AppError.apiRequestFailed("getPost", NSError(domain: "Mock", code: -1))
        }
        return posts[postId] ?? PatreonClient.Post(
            id: postId,
            type: "post",
            attributes: PatreonClient.Post.PatreonPostAttributes(
                title: "Test Post",
                content: "Test content",
                url: "https://www.patreon.com/posts/\(postId)",
                isPaid: true,
                isPublic: false,
                publishedAt: nil
            ),
            relationships: nil
        )
    }

    func setPost(_ post: PatreonClient.Post, for id: String) {
        posts[id] = post
    }

    func setPublicURL(_ url: String, for postId: String) {
        postURLs[postId] = url
    }
}

actor MockPublicationTargetRepository: PublicationTargetRepository {
    var targets: [String: PublicationTargetRecord] = [:]
    var createdTargets: [PublicationTargetRecord] = []

    func create(target: PublicationTargetRecord) async throws -> PublicationTargetRecord {
        var newTarget = target
        newTarget.id = UUID().uuidString
        targets[newTarget.id] = newTarget
        createdTargets.append(newTarget)
        return newTarget
    }

    func update(target: PublicationTargetRecord) async throws -> PublicationTargetRecord {
        targets[target.id] = target
        return target
    }

    func getById(id: String) async throws -> PublicationTargetRecord? {
        targets[id]
    }

    func listByContent(contentId: String) async throws -> [PublicationTargetRecord] {
        targets.values.filter { $0.generatedContentId == contentId }
    }

    func listByPlatform(platform: String, limit: Int) async throws -> [PublicationTargetRecord] {
        Array(targets.values.filter { $0.platform == platform }.prefix(limit))
    }

    func listPending(limit: Int) async throws -> [PublicationTargetRecord] {
        Array(targets.values.filter { $0.state == .pending || $0.state == .scheduled }.prefix(limit))
    }
}

actor MockGeneratedContentRepository: GeneratedContentRepository {
    var content: [String: GeneratedContentRecord] = [:]
    var versions: [String: [GeneratedContentVersionRecord]] = [:]

    func create(content: GeneratedContentRecord) async throws -> GeneratedContentRecord {
        self.content[content.id] = content
        return content
    }

    func update(content: GeneratedContentRecord) async throws -> GeneratedContentRecord {
        self.content[content.id] = content
        return content
    }

    func getById(id: String) async throws -> GeneratedContentRecord? {
        content[id]
    }

    func getByTaskRun(taskRunId: String) async throws -> GeneratedContentRecord? {
        content.values.first { $0.taskRunId == taskRunId }
    }

    func listByAgent(agentId: String, limit: Int) async throws -> [GeneratedContentRecord] {
        Array(content.values.filter { $0.agentId == agentId }.prefix(limit))
    }

    func listRecent(limit: Int) async throws -> [GeneratedContentRecord] {
        Array(content.values.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    func createVersion(version: GeneratedContentVersionRecord) async throws -> GeneratedContentVersionRecord {
        versions[version.generatedContentId, default: []].append(version)
        return version
    }

    func listVersions(contentId: String) async throws -> [GeneratedContentVersionRecord] {
        versions[contentId] ?? []
    }

    func getVersion(contentId: String, version: Int) async throws -> GeneratedContentVersionRecord? {
        versions[contentId]?.first { $0.version == version }
    }
}

actor MockApprovalQueueRepository: ApprovalQueueRepository {
    var entries: [String: ApprovalQueueRecord] = [:]

    func create(entry: ApprovalQueueRecord) async throws -> ApprovalQueueRecord {
        entries[entry.id] = entry
        return entry
    }

    func update(entry: ApprovalQueueRecord) async throws -> ApprovalQueueRecord {
        entries[entry.id] = entry
        return entry
    }

    func getById(id: String) async throws -> ApprovalQueueRecord? {
        entries[id]
    }

    func getByContent(contentId: String) async throws -> ApprovalQueueRecord? {
        entries.values.first { $0.generatedContentId == contentId }
    }

    func listByStatus(status: String, limit: Int) async throws -> [ApprovalQueueRecord] {
        Array(entries.values.filter { $0.approvalStatus == status }.prefix(limit))
    }

    func listPending(limit: Int) async throws -> [ApprovalQueueRecord] {
        Array(entries.values.filter { $0.approvalStatus == "pending" }.prefix(limit))
    }

    func listByBatchToken(token: String) async throws -> [ApprovalQueueRecord] {
        entries.values.filter { $0.batchToken == token }
    }
}

actor MockRemotePostCacheRepository: RemotePostCacheRepository {
    var cache: [String: RemotePostCacheRecord] = [:]

    func create(entry: RemotePostCacheRecord) async throws -> RemotePostCacheRecord {
        cache[entry.cacheKey] = entry
        return entry
    }

    func update(entry: RemotePostCacheRecord) async throws -> RemotePostCacheRecord {
        cache[entry.cacheKey] = entry
        return entry
    }

    func get(platform: String, cacheKey: String) async throws -> RemotePostCacheRecord? {
        cache[cacheKey]
    }

    func listExpired(before: Date) async throws -> [RemotePostCacheRecord] {
        cache.values.filter { $0.expiresAt < before }
    }

    func deleteExpired(before: Date) async throws {
        cache = cache.filter { $0.value.expiresAt >= before }
    }

    func delete(platform: String, cacheKey: String) async throws {
        cache.removeValue(forKey: cacheKey)
    }
}

// MARK: - PublicationService Tests

@MainActor
final class PublicationServiceTests: XCTestCase {

    private var deviantArtService: MockDeviantArtService!
    private var patreonService: MockPatreonService!
    private var publicationRepository: MockPublicationTargetRepository!
    private var contentRepository: MockGeneratedContentRepository!
    private var approvalRepository: MockApprovalQueueRepository!
    private var cacheRepository: MockRemotePostCacheRepository!
    private var cacheService: CacheService!
    private var settingsService: SettingsService!
    private var publicationService: PublicationService!

    override func setUp() async throws {
        deviantArtService = MockDeviantArtService()
        patreonService = MockPatreonService()
        publicationRepository = MockPublicationTargetRepository()
        contentRepository = MockGeneratedContentRepository()
        approvalRepository = MockApprovalQueueRepository()
        cacheRepository = MockRemotePostCacheRepository()
        cacheService = CacheService(cacheRepository: cacheRepository)
        settingsService = SettingsService()

        publicationService = PublicationService(
            approvalQueueRepository: approvalRepository,
            publicationRepository: publicationRepository,
            contentRepository: contentRepository,
            cacheService: cacheService,
            settingsService: settingsService,
            deviantArtClient: deviantArtService,
            patreonClient: patreonService
        )
    }

    // MARK: - DeviantArt Tests

    func testPublishToDeviantArt_CreatesTargetAndPublishes() async throws {
        // Arrange
        let content = GeneratedContentRecord(
            taskRunId: "task-run-1",
            agentId: "agent-1",
            title: "Test Artwork",
            generatedContentJson: "{\"description\": \"A test artwork\"}"
        )
        _ = try await contentRepository.create(content: content)

        // Act
        let result = try await publicationService.publishToDeviantArt(
            contentId: content.id,
            title: "Published Artwork",
            category: "digitalart/paintings/other",
            isMature: false,
            tags: ["art", "digital"]
        )

        // Assert
        XCTAssertEqual(result.platform, "deviantart")
        XCTAssertEqual(result.state, .published)
        XCTAssertNotNil(result.remotePostId)
        XCTAssertNotNil(result.remoteUrl)

        let daCalls = await deviantArtService.stashSubmitCallCount
        XCTAssertEqual(daCalls, 1)

        let daPublishCalls = await deviantArtService.stashPublishCallCount
        XCTAssertEqual(daPublishCalls, 1)
    }

    func testPublishToDeviantArt_WithoutClient_ThrowsError() async throws {
        // Arrange - service without DeviantArt client
        let service = PublicationService(
            approvalQueueRepository: approvalRepository,
            publicationRepository: publicationRepository,
            contentRepository: contentRepository,
            cacheService: cacheService,
            settingsService: settingsService,
            deviantArtClient: nil,
            patreonClient: patreonService
        )

        let content = GeneratedContentRecord(
            taskRunId: "task-run-2",
            agentId: "agent-2",
            title: "Test Artwork",
            generatedContentJson: "{}"
        )
        _ = try await contentRepository.create(content: content)

        // Act & Assert
        do {
            _ = try await service.publishToDeviantArt(contentId: content.id)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("DeviantArt client not configured"))
        }
    }

    func testPublishToDeviantArt_StashSubmitFailure_MarksTargetFailed() async throws {
        // Arrange
        await deviantArtService.setShouldFailStashSubmit(true)

        let content = GeneratedContentRecord(
            taskRunId: "task-run-3",
            agentId: "agent-3",
            title: "Test Artwork",
            generatedContentJson: "{}"
        )
        _ = try await contentRepository.create(content: content)

        // Act & Assert
        do {
            _ = try await publicationService.publishToDeviantArt(contentId: content.id)
            XCTFail("Expected error to be thrown")
        } catch {
            // Verify target was created and marked as failed
            let targets = try await publicationRepository.listByContent(contentId: content.id)
            XCTAssertEqual(targets.count, 1)
            XCTAssertEqual(targets.first?.state, .failed)
        }
    }

    func testPublishToDeviantArt_ContentNotFound_ThrowsError() async {
        // Act & Assert
        do {
            _ = try await publicationService.publishToDeviantArt(contentId: "non-existent-id")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Content not found"))
        }
    }

    // MARK: - Statistics Tests

    func testGetStatistics_Empty() async throws {
        // Act
        let stats = try await publicationService.getStatistics()

        // Assert
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.published, 0)
        XCTAssertEqual(stats.successRate, 0)
    }

    func testGetStatistics_WithMixedStates() async throws {
        // Arrange
        let targets = [
            PublicationTargetRecord(generatedContentId: "c1", platform: "deviantart", state: .published),
            PublicationTargetRecord(generatedContentId: "c2", platform: "deviantart", state: .published),
            PublicationTargetRecord(generatedContentId: "c3", platform: "deviantart", state: .failed),
            PublicationTargetRecord(generatedContentId: "c4", platform: "patreon", state: .scheduled),
            PublicationTargetRecord(generatedContentId: "c5", platform: "patreon", state: .pending)
        ]

        for target in targets {
            _ = try await publicationRepository.create(target: target)
        }

        // Act
        let stats = try await publicationService.getStatistics()

        // Assert
        XCTAssertEqual(stats.total, 5)
        XCTAssertEqual(stats.published, 2)
        XCTAssertEqual(stats.failed, 1)
        XCTAssertEqual(stats.scheduled, 1)
        XCTAssertEqual(stats.pending, 1)
        XCTAssertEqual(stats.successRate, 0.4)
    }

    // MARK: - Schedule Tests

    func testSchedulePublication_CreatesScheduledTarget() async throws {
        // Arrange
        let contentId = "content-1"
        let publishAt = Date().addingTimeInterval(3600)

        // Act
        let result = try await publicationService.schedulePublication(
            contentId: contentId,
            platform: "deviantart",
            publishAt: publishAt
        )

        // Assert
        XCTAssertEqual(result.generatedContentId, contentId)
        XCTAssertEqual(result.platform, "deviantart")
        XCTAssertEqual(result.state, .scheduled)
        XCTAssertNotNil(result.scheduledAt)
        if let scheduledAt = result.scheduledAt {
            XCTAssertEqual(scheduledAt.timeIntervalSince1970, publishAt.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    // MARK: - List Publications Tests

    func testListPublications() async throws {
        // Arrange
        let contentId = "content-2"
        let target1 = PublicationTargetRecord(generatedContentId: contentId, platform: "deviantart", state: .published)
        let target2 = PublicationTargetRecord(generatedContentId: contentId, platform: "patreon", state: .pending)

        _ = try await publicationRepository.create(target: target1)
        _ = try await publicationRepository.create(target: target2)

        // Act
        let results = try await publicationService.listPublications(contentId: contentId)

        // Assert
        XCTAssertEqual(results.count, 2)
    }
}

// MARK: - DI Registration Tests

@MainActor
final class DependencyInjectionTests: XCTestCase {

    func testContainer_ResolvesDeviantArtServiceProtocol() async {
        // Arrange
        let mockService = MockDeviantArtService()
        await sharedContainer.register(DeviantArtServiceProtocol.self, instance: mockService)

        // Act
        let resolved: DeviantArtServiceProtocol? = await sharedContainer.resolveOptional(DeviantArtServiceProtocol.self)

        // Assert
        XCTAssertNotNil(resolved)
    }

    func testContainer_ResolvesPatreonServiceProtocol() async {
        // Arrange
        let mockService = MockPatreonService()
        await sharedContainer.register(PatreonServiceProtocol.self, instance: mockService)

        // Act
        let resolved: PatreonServiceProtocol? = await sharedContainer.resolveOptional(PatreonServiceProtocol.self)

        // Assert
        XCTAssertNotNil(resolved)
    }

    func testContainer_ResolvesAKDeviantArtClientFromServiceProtocol() async throws {
        // Arrange - register MockDeviantArtService which conforms to both protocols
        let mockService = MockDeviantArtService()
        await sharedContainer.register(DeviantArtServiceProtocol.self, instance: mockService)

        // Act - resolve as protocol then cast, matching production usage in AppToolServiceProvider
        let resolvedProtocol = await sharedContainer.resolveOptional(DeviantArtServiceProtocol.self)
        let resolved = resolvedProtocol as? AKDeviantArtClient

        // Assert
        XCTAssertNotNil(resolved)
    }

    func testContainer_ResolvesAKPatreonClientFromServiceProtocol() async throws {
        // Arrange
        let mockService = MockPatreonService()
        await sharedContainer.register(PatreonServiceProtocol.self, instance: mockService)

        // Act - resolve as protocol then cast, matching production usage in AppToolServiceProvider
        let resolvedProtocol = await sharedContainer.resolveOptional(PatreonServiceProtocol.self)
        let resolved = resolvedProtocol as? AKPatreonClient

        // Assert
        XCTAssertNotNil(resolved)
    }
}
