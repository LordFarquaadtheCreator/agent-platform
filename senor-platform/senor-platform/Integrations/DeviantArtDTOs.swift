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
        let mediumThumb = thumbs?.first { $0.quality == .medium }
            ?? thumbs?.first { $0.quality == .small }
        if let mediumThumb {
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

// MARK: - Watchers / Friends

public struct WatchersResponse: Codable, Sendable {
    public let results: [Watcher]
    public let hasMore: Bool
    public let nextOffset: Int?

    enum CodingKeys: String, CodingKey, Sendable {
        case results
        case hasMore = "has_more"
        case nextOffset = "next_offset"
    }
}

public struct Watcher: Codable, Identifiable, Sendable {
    public let user: Deviation.User
    public let isWatching: Bool?
    public let lastvisit: String?
    public let watchSettings: WatchSettings?

    public var id: String { user.userid }

    enum CodingKeys: String, CodingKey, Sendable {
        case user, lastvisit
        case isWatching = "is_watching"
        case watchSettings = "watch_settings"
    }
}

public struct WatchSettings: Codable, Sendable {
    public let friend: Bool?
    public let deviations: Bool?
    public let journals: Bool?
    public let forumThreads: Bool?
    public let comments: Bool?
    public let activity: Bool?
    public let scraps: Bool?

    enum CodingKeys: String, CodingKey, Sendable {
        case friend, deviations, journals
        case forumThreads = "forum_threads"
        case comments, activity, scraps
    }
}

public struct FriendsResponse: Codable, Sendable {
    public let results: [Friend]
    public let hasMore: Bool
    public let nextOffset: Int?

    enum CodingKeys: String, CodingKey, Sendable {
        case results
        case hasMore = "has_more"
        case nextOffset = "next_offset"
    }
}

public struct Friend: Codable, Identifiable, Sendable {
    public let user: Deviation.User
    public let isWatching: Bool?

    public var id: String { user.userid }

    enum CodingKeys: String, CodingKey, Sendable {
        case user
        case isWatching = "is_watching"
    }
}

// MARK: - Gallery Folder DTOs

public struct GalleryFoldersResponse: Codable, Sendable {
    public let results: [GalleryFolder]
    public let hasMore: Bool
    public let nextOffset: Int?

    enum CodingKeys: String, CodingKey, Sendable {
        case results
        case hasMore = "has_more"
        case nextOffset = "next_offset"
    }
}

public struct GalleryFolder: Codable, Identifiable, Sendable {
    public let folderid: String
    public let parent: String?
    public let name: String

    public var id: String { folderid }

    enum CodingKeys: String, CodingKey, Sendable {
        case folderid, parent, name
    }
}

// MARK: - Deviation Edit / Journal / Literature

public struct DeviationEditResponse: Codable, Sendable {
    public let status: String
    public let deviationid: String?
    public let url: String?
}

// MARK: - Publish Response

public struct PublishResponse: Codable, Sendable {
    public let status: String
    public let deviationid: String?
    public let url: String?
}
