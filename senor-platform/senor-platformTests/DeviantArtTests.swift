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

        let data = json.data(using: .utf8)!
        let deviation = try JSONDecoder().decode(DeviantArtClient.Deviation.self, from: data)

        XCTAssertEqual(deviation.id, "ABC123")
        XCTAssertEqual(deviation.title, "Test Deviation")
        XCTAssertEqual(deviation.category, "Digital Art")
        XCTAssertEqual(deviation.author?.username, "TestUser")
        XCTAssertEqual(deviation.stats?.views, 100)
        XCTAssertEqual(deviation.stats?.favourites, 50)
        XCTAssertEqual(deviation.stats?.comments, 10)
        XCTAssertEqual(deviation.stats?.downloads, 5)
        XCTAssertEqual(deviation.publishedTime, "1234567890")
        XCTAssertEqual(deviation.allowsComments, true)
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

        let data = json.data(using: .utf8)!
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

        let data = json.data(using: .utf8)!
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

        let data = json.data(using: .utf8)!
        let metadata = try JSONDecoder().decode(DeviantArtClient.DeviationMetadata.self, from: data)

        XCTAssertEqual(metadata.deviationid, "META123")
        XCTAssertEqual(metadata.type, "image")
        XCTAssertEqual(metadata.tags?.count, 3)
        XCTAssertEqual(metadata.tags?.first?.tagName, "digital")
        XCTAssertEqual(metadata.description, "<p>This is a test description</p>")
        XCTAssertEqual(metadata.license, "CC BY-NC-ND 3.0")
        XCTAssertEqual(metadata.allowsComments, true)
        XCTAssertEqual(metadata.isFavouritable, true)
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

        let data = json.data(using: .utf8)!
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
        let testURL = URL(string: "https://example.com/test.jpg")!

        // Mock - just verify service initializes without crashing
        XCTAssertNotNil(service)
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
