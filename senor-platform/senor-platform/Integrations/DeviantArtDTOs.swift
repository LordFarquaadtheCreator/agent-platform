import Foundation

// MARK: - Stash DTOs

public struct StashStack: Codable, Identifiable, Sendable {
    public let stackid: String
    public let title: String?
    public let items: [StashItem]?

    public var id: String { stackid }

    enum CodingKeys: String, CodingKey, Sendable {
        case stackid, title, items
    }
}

public struct StashItem: Codable, Identifiable, Sendable {
    public let itemid: String
    public let stackid: String?
    public let title: String
    public let path: String?
    public let size: Int?
    public let fileSize: Int?
    public let status: String
    public let thumb: String?
    public let position: Int?

    enum CodingKeys: String, CodingKey, Sendable {
        case itemid, stackid, title, path, size, status, thumb, position
        case fileSize = "filesize"
    }

    public var id: String { itemid }
    public var isPublished: Bool { status == "published" }
    public var previewURL: URL? {
        thumb.flatMap { URL(string: $0) }
    }
}

public struct StashContentsResponse: Codable, Sendable {
    public let results: [StashStack]
    public let hasMore: Bool
    public let nextOffset: Int?

    enum CodingKeys: String, CodingKey, Sendable {
        case results
        case hasMore = "has_more"
        case nextOffset = "next_offset"
    }
}

public struct StashPublishResponse: Codable, Sendable {
    public let status: String
    public let deviationid: String?
    public let url: String?

    enum CodingKeys: String, CodingKey, Sendable {
        case status, deviationid, url
    }
}

// MARK: - Deviation DTOs

public struct Deviation: Codable, Identifiable, Sendable {
    public let deviationid: String
    public let url: String
    public let title: String
    public let category: String?
    public let author: User?
    public let stats: Stats?
    public let publishedTime: String?
    public let allowsComments: Bool?
    public let isFavourited: Bool?
    public let isDeleted: Bool?
    public let thumbs: [Thumb]?
    public let content: ContentInfo?

    enum CodingKeys: String, CodingKey, Sendable {
        case deviationid, url, title, category, author, stats, thumbs, content
        case publishedTime = "published_time"
        case allowsComments = "allows_comments"
        case isFavourited = "is_favourited"
        case isDeleted = "is_deleted"
    }

    public var id: String { deviationid }

    public var previewURL: URL? {
        if let mediumThumb = thumbs?.first(where: { $0.quality == .medium }) ?? thumbs?.first(where: { $0.quality == .small }) {
            return URL(string: mediumThumb.src)
        }
        if let contentSrc = content?.src {
            return URL(string: contentSrc)
        }
        return thumbs?.first.map { URL(string: $0.src) } ?? nil
    }
}

extension Deviation {
    public struct Thumb: Codable, Sendable {
        public let src: String
        public let width: Int
        public let height: Int

        var quality: ThumbQuality {
            let maxDim = max(width, height)
            if maxDim >= 400 { return .large }
            if maxDim >= 200 { return .medium }
            return .small
        }
    }

    public enum ThumbQuality {
        case small, medium, large
    }

    public struct ContentInfo: Codable, Sendable {
        public let src: String?
        public let width: Int?
        public let height: Int?
        public let filesize: Int?
    }

    public struct User: Codable, Sendable {
        public let userid: String
        public let username: String
        public let usericon: String?
    }

    public struct Stats: Codable, Sendable {
        public let views: Int?
        public let favourites: Int?
        public let comments: Int?
        public let downloads: Int?
    }
}

public struct DeviationContent: Codable, Sendable {
    public let html: String?
    public let css: String?
    public let body: String?

    enum CodingKeys: String, CodingKey, Sendable {
        case html, css, body
    }
}

public struct DeviationMetadata: Codable, Sendable {
    public let deviationid: String
    public let type: String?
    public let tags: [Tag]?
    public let description: String?
    public let license: String?
    public let allowsComments: Bool?
    public let isFavouritable: Bool?
    public let isFavourited: Bool?
    public let isDeleted: Bool?

    enum CodingKeys: String, CodingKey, Sendable {
        case deviationid, type, tags, description, license
        case allowsComments = "allows_comments"
        case isFavouritable = "is_favouritable"
        case isFavourited = "is_favourited"
        case isDeleted = "is_deleted"
    }
}

extension DeviationMetadata {
    public struct Tag: Codable, Sendable {
        public let tagName: String

        enum CodingKeys: String, CodingKey, Sendable {
            case tagName = "tag_name"
        }
    }
}

public struct GalleryResponse: Codable, Sendable {
    public let results: [Deviation]
    public let hasMore: Bool
    public let nextOffset: Int?

    enum CodingKeys: String, CodingKey, Sendable {
        case results
        case hasMore = "has_more"
        case nextOffset = "next_offset"
    }
}

// MARK: - User DTOs

public struct UserProfile: Codable, Sendable {
    public let user: UserInfo
    public let stats: UserStats?

    enum CodingKeys: String, CodingKey, Sendable {
        case user, stats
    }
}

extension UserProfile {
    public struct UserInfo: Codable, Sendable {
        public let userid: String
        public let username: String
        public let usericon: String?
        public let type: String?

        enum CodingKeys: String, CodingKey, Sendable {
            case userid, username, usericon, type
        }
    }

    public struct UserStats: Codable, Sendable {
        public let watchers: Int?
        public let friends: Int?
        public let deviations: Int?

        enum CodingKeys: String, CodingKey, Sendable {
            case watchers, friends, deviations
        }
    }
}

// MARK: - Publish Response

public struct PublishResponse: Codable, Sendable {
    public let status: String
    public let deviationid: String?
    public let url: String?
}
