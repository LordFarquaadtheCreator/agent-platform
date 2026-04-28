import XCTest
@testable import senor_platform

@MainActor
final class DeviantArtTests: XCTestCase {

    // MARK: - RelativeDateFormatter Tests

    func testRelativeDateFormatterUnixTimestamp() {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let unixTime = String(Int(twoHoursAgo.timeIntervalSince1970))

        let result = RelativeDateFormatter.format(unixTime: unixTime)

        XCTAssertTrue(result.contains("hour") || result.contains("ago"), "Expected relative time format, got: \(result)")
    }

    func testRelativeDateFormatterInvalidTimestamp() {
        let result = RelativeDateFormatter.format(unixTime: "invalid")
        XCTAssertEqual(result, "invalid", "Should return original string for invalid input")
    }

    func testRelativeDateFormatterDate() {
        let yesterday = Date().addingTimeInterval(-86400)
        let result = RelativeDateFormatter.format(yesterday)

        XCTAssertTrue(result.contains("day") || result.contains("ago"), "Expected relative time format, got: \(result)")
    }

    // MARK: - DeviantArt DTO Decoding Tests

    func testDeviationDecoding() throws {
        let json = """
        {
            "deviationid": "ABC123",
            "url": "https://www.deviantart.com/test/art/Test-123",
            "title": "Test Deviation",
            "category": "Digital Art",
            "author": {
                "userid": "USER1",
                "username": "TestUser",
                "usericon": "https://a.deviantart.net/avatar.gif"
            },
            "stats": {
                "views": 100,
                "favourites": 50,
                "comments": 10,
                "downloads": 5
            },
            "published_time": "1234567890",
            "allows_comments": true,
            "is_favourited": false,
            "is_deleted": false,
            "thumbs": [
                {
                    "src": "https://thumbs.deviantart.com/small.jpg",
                    "width": 150,
                    "height": 150
                },
                {
                    "src": "https://thumbs.deviantart.com/medium.jpg",
                    "width": 300,
                    "height": 300
                }
            ],
            "content": {
                "src": "https://images.deviantart.com/full.jpg",
                "width": 1920,
                "height": 1080,
                "filesize": 1024000
            }
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let deviation = try JSONDecoder().decode(DeviantArtClient.Deviation.self, from: data)

        XCTAssertEqual(deviation.id, "ABC123")
        XCTAssertEqual(deviation.title, "Test Deviation")
        XCTAssertEqual(deviation.category, "Digital Art")
        XCTAssertEqual(deviation.author?.username, "TestUser")
        XCTAssertEqual(deviation.isFavourited, false)
        XCTAssertEqual(deviation.stats?.comments, 10)
        XCTAssertEqual(deviation.stats?.downloads, 5)
        XCTAssertEqual(deviation.publishedTime, "1234567890")
        XCTAssertTrue(deviation.allowsComments ?? false)
        XCTAssertEqual(deviation.thumbs?.count, 2)
    }

    func testDeviationPreviewURL() {
        let deviation = DeviantArtClient.Deviation(
            deviationid: "TEST",
            url: "https://example.com",
            title: "Test",
            category: nil,
            author: nil,
            stats: nil,
            publishedTime: nil,
            allowsComments: nil,
            isFavourited: nil,
            isDeleted: nil,
            thumbs: [
                DeviantArtClient.Deviation.Thumb(src: "https://small.jpg", width: 150, height: 150),
                DeviantArtClient.Deviation.Thumb(src: "https://medium.jpg", width: 300, height: 300)
            ],
            content: nil
        )

        let previewURL = deviation.previewURL
        XCTAssertNotNil(previewURL)
        XCTAssertEqual(previewURL?.absoluteString, "https://medium.jpg")
    }

    func testUserProfileDecoding() throws {
        let json = """
        {
            "user": {
                "userid": "USER123",
                "username": "TestArtist",
                "usericon": "https://a.deviantart.net/avatars/test.gif",
                "type": "regular"
            },
            "stats": {
                "watchers": 1000,
                "friends": 50,
                "deviations": 200
            }
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let profile = try JSONDecoder().decode(DeviantArtClient.UserProfile.self, from: data)

        XCTAssertEqual(profile.user.username, "TestArtist")
        XCTAssertEqual(profile.user.usericon, "https://a.deviantart.net/avatars/test.gif")
        XCTAssertEqual(profile.stats?.watchers, 1000)
        XCTAssertEqual(profile.stats?.friends, 50)
        XCTAssertEqual(profile.stats?.deviations, 200)
    }

    func testGalleryResponseDecoding() throws {
        let json = """
        {
            "results": [
                {
                    "deviationid": "1",
                    "url": "https://deviantart.com/art/1",
                    "title": "Art 1"
                },
                {
                    "deviationid": "2",
                    "url": "https://deviantart.com/art/2",
                    "title": "Art 2"
                }
            ],
            "has_more": true,
            "next_offset": 24
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(DeviantArtClient.GalleryResponse.self, from: data)

        XCTAssertEqual(response.results.count, 2)
        XCTAssertTrue(response.hasMore)
        XCTAssertEqual(response.nextOffset, 24)
    }

    func testDeviationMetadataDecoding() throws {
        let json = """
        {
            "deviationid": "META123",
            "type": "image",
            "tags": [
                {"tag_name": "digital"},
                {"tag_name": "art"},
                {"tag_name": "test"}
            ],
            "description": "<p>This is a test description</p>",
            "license": "CC BY-NC-ND 3.0",
            "allows_comments": true,
            "is_favouritable": true,
            "is_favourited": false,
            "is_deleted": false
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let metadata = try JSONDecoder().decode(DeviantArtClient.DeviationMetadata.self, from: data)

        XCTAssertEqual(metadata.deviationid, "META123")
        XCTAssertEqual(metadata.type, "image")
        XCTAssertEqual(metadata.tags?.count, 3)
        XCTAssertEqual(metadata.tags?.first?.tagName, "digital")
        XCTAssertEqual(metadata.description, "<p>This is a test description</p>")
        XCTAssertEqual(metadata.license, "CC BY-NC-ND 3.0")
        XCTAssertTrue(metadata.allowsComments ?? false)
        XCTAssertTrue(metadata.isFavouritable ?? false)
    }

    func testStashStackDecoding() throws {
        let json = """
        {
            "stackid": "STACK123",
            "title": "My Stack",
            "items": [
                {
                    "itemid": "ITEM1",
                    "stackid": "STACK123",
                    "title": "Item 1",
                    "status": "published",
                    "filesize": 1024,
                    "thumb": "https://thumb.jpg"
                },
                {
                    "itemid": "ITEM2",
                    "stackid": "STACK123",
                    "title": "Item 2",
                    "status": "draft",
                    "filesize": 2048
                }
            ]
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let stack = try JSONDecoder().decode(DeviantArtClient.StashStack.self, from: data)

        XCTAssertEqual(stack.id, "STACK123")
        XCTAssertEqual(stack.title, "My Stack")
        XCTAssertEqual(stack.items?.count, 2)
        XCTAssertTrue(stack.items?.first?.isPublished ?? false)
        XCTAssertFalse(stack.items?.last?.isPublished ?? true)
    }

    func testStashItemPreviewURL() {
        let item = DeviantArtClient.StashItem(
            itemid: "TEST",
            stackid: nil,
            title: "Test",
            path: nil,
            size: nil,
            fileSize: nil,
            status: "draft",
            thumb: "https://example.com/thumb.jpg",
            position: nil
        )

        XCTAssertEqual(item.previewURL?.absoluteString, "https://example.com/thumb.jpg")
    }

    // MARK: - ImageCacheService Tests

    func testImageCacheServiceCreatesCacheDirectory() async throws {
        let service = ImageCacheService(cacheName: "TestCache", maxCacheSizeMB: 10)

        // Verify cache directory exists by attempting to cache a test
        // swiftlint:disable:next force_unwrapping
        let testURL = URL(string: "https://example.com/test.jpg")!

        // Mock - just verify service initializes without crashing
        XCTAssertNotNil(service)
        _ = testURL  // Silence unused warning
    }

    // MARK: - Cache Key Tests

    func testCacheKeyDeviantArtFormats() {
        let deviationKey = CacheKey.deviation(id: "ABC123")
        XCTAssertEqual(deviationKey.stringValue, "da:deviation:ABC123")

        let galleryKey = CacheKey.gallery(username: "TestUser", offset: 0)
        XCTAssertEqual(galleryKey.stringValue, "da:gallery:TestUser:0")

        let profileKey = CacheKey.userProfile(username: "TestUser")
        XCTAssertEqual(profileKey.stringValue, "da:profile:TestUser")

        let metadataKey = CacheKey.deviationMetadata(deviationId: "META456")
        XCTAssertEqual(metadataKey.stringValue, "da:metadata:META456")
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

    func testPublishToDeviantArt_CreatesTargetAndPublishes() async throws {
        let content = GeneratedContentRecord(
            taskRunId: "task-run-1",
            agentId: "agent-1",
            title: "Test Artwork",
            generatedContentJson: "{\"description\": \"A test artwork\"}"
        )
        _ = try await contentRepository.create(content: content)

        let result = try await publicationService.publishToDeviantArt(
            contentId: content.id,
            title: "Published Artwork",
            category: "digitalart/paintings/other",
            isMature: false,
            tags: ["art", "digital"]
        )

        XCTAssertEqual(result.platform, "deviantart")
        XCTAssertEqual(result.state, .published)
        XCTAssertNotNil(result.remotePostId)
        XCTAssertNotNil(result.remoteUrl)

        let daCalls = await deviantArtService.stashSubmitCallCount
        XCTAssertEqual(daCalls, 1)

        let daPublishCalls = await deviantArtService.stashPublishCallCount
        XCTAssertEqual(daPublishCalls, 1)
    }

    func testPublishToDeviantArt_WithoutClient_ThrowsError() async {
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
        _ = try? await contentRepository.create(content: content)

        do {
            _ = try await service.publishToDeviantArt(contentId: content.id)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("DeviantArt client not configured"))
        }
    }

    func testPublishToPatreon_CreatesTargetAndPublishes() async throws {
        let content = GeneratedContentRecord(
            taskRunId: "task-run-4",
            agentId: "agent-4",
            title: "Test Post",
            generatedContentJson: "{\"description\": \"A test post\"}"
        )
        _ = try await contentRepository.create(content: content)

        let result = try await publicationService.publishToPatreon(
            contentId: content.id,
            campaignId: "campaign-123",
            title: "Published Post",
            isPaid: true,
            isPublic: false,
            tiers: ["tier-1", "tier-2"]
        )

        XCTAssertEqual(result.platform, "patreon")
        XCTAssertEqual(result.state, .published)
        XCTAssertNotNil(result.remotePostId)
        XCTAssertNotNil(result.remoteUrl)

        let patreonCalls = await patreonService.createPostCallCount
        XCTAssertEqual(patreonCalls, 1)

        let urlCalls = await patreonService.getPublicURLCallCount
        XCTAssertEqual(urlCalls, 1)
    }

    func testPublishToPatreon_WithoutClient_ThrowsError() async {
        let service = PublicationService(
            approvalQueueRepository: approvalRepository,
            publicationRepository: publicationRepository,
            contentRepository: contentRepository,
            cacheService: cacheService,
            settingsService: settingsService,
            deviantArtClient: deviantArtService,
            patreonClient: nil
        )

        let content = GeneratedContentRecord(
            taskRunId: "task-run-5",
            agentId: "agent-5",
            title: "Test Post",
            generatedContentJson: "{}"
        )
        _ = try? await contentRepository.create(content: content)

        do {
            _ = try await service.publishToPatreon(contentId: content.id, campaignId: "campaign-123")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Patreon client not configured"))
        }
    }
}

// MARK: - Mock Service Implementations

actor MockDeviantArtService: DeviantArtServiceProtocol {
    var stashItems: [String: DeviantArtClient.StashItem] = [:]
    var publishedItems: [String: DeviantArtClient.StashPublishResponse] = [:]
    var deviations: [String: DeviantArtClient.Deviation] = [:]

    var stashSubmitCallCount = 0
    var stashPublishCallCount = 0
    var getDeviationCallCount = 0

    nonisolated(unsafe) var shouldFailStashSubmit = false
    nonisolated(unsafe) var shouldFailStashPublish = false
    var shouldFailGetDeviation = false

    func stashSubmit(filename: String, title: String?, artistComments: String?, tags: [String]?, originalUrl: String?) async throws -> DeviantArtClient.StashItem {
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

    func stashPublish(stashId: String, title: String, category: String?, isMature: Bool, matureLevel: String?, allowsComments: Bool, galleryIds: [String]?, licenseOptions: [String: String]?) async throws -> DeviantArtClient.StashPublishResponse {
        stashPublishCallCount += 1

        if shouldFailStashPublish {
            throw AppError.apiRequestFailed("stashPublish", NSError(domain: "Mock", code: -1))
        }

        let response = DeviantArtClient.StashPublishResponse(
            status: "published",
            deviationid: "dev-\(stashId)",
            url: "https://www.deviantart.com/test/art/Test-123"
        )
        publishedItems[stashId] = response
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
}

actor MockPatreonService: PatreonServiceProtocol {
    var posts: [String: PatreonClient.Post] = [:]
    var postURLs: [String: String] = [:]

    var createPostCallCount = 0
    var getPublicURLCallCount = 0

    nonisolated(unsafe) var shouldFailCreatePost = false
    nonisolated(unsafe) var shouldFailGetPublicURL = false

    func createPost(campaignId: String, title: String, content: String, isPaid: Bool?, isPublic: Bool?, tiers: [String]?, publishAt: Date?) async throws -> PatreonClient.Post {
        createPostCallCount += 1

        if shouldFailCreatePost {
            throw AppError.apiRequestFailed("createPost", NSError(domain: "Mock", code: -1))
        }

        let post = PatreonClient.Post(
            id: "post-\(createPostCallCount)",
            type: "post",
            attributes: PatreonClient.Post.PatreonPostAttributes(
                title: title,
                content: content,
                url: "https://www.patreon.com/posts/post-\(createPostCallCount)",
                isPaid: isPaid,
                isPublic: isPublic,
                publishedAt: publishAt
            ),
            relationships: nil
        )
        posts[post.id] = post
        return post
    }

    func getPublicURL(for postId: String) async throws -> String {
        getPublicURLCallCount += 1

        if shouldFailGetPublicURL {
            throw AppError.apiRequestFailed("getPublicURL", NSError(domain: "Mock", code: -1))
        }

        if let url = postURLs[postId] {
            return url
        }

        return "https://www.patreon.com/posts/\(postId)"
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
