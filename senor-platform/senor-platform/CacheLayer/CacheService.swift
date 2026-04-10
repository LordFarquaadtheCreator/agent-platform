import Foundation

/// TTL Cache service for API data with snapshot persistence
public final class CacheService: Sendable {
    private let cacheRepository: RemotePostCacheRepository
    private let logger = AppLogger.general
    
    /// Cache configuration by endpoint category
    public struct CacheConfiguration: Sendable {
        public let metadataTTL: TimeInterval  // For slower changing data
        public let statsTTL: TimeInterval     // For frequently changing stats
        public let listTTL: TimeInterval      // For lists/collections
        
        public static let `default` = CacheConfiguration(
            metadataTTL: 3600,    // 1 hour
            statsTTL: 300,        // 5 minutes
            listTTL: 1800         // 30 minutes
        )
    }
    
    private let configuration: CacheConfiguration
    
    public init(cacheRepository: RemotePostCacheRepository, configuration: CacheConfiguration = .default) {
        self.cacheRepository = cacheRepository
        self.configuration = configuration
    }
    
    // MARK: - Cache Operations
    
    /// Cache data with automatic TTL based on category
    public func cache<T: Codable & Sendable>(
        platform: String,
        cacheKey: String,
        data: T,
        category: CacheCategory
    ) async throws {
        let payloadData = try JSONEncoder().encode(data)
        let payloadJson = String(data: payloadData, encoding: .utf8) ?? "{}"
        
        let ttl = ttl(for: category)
        let expiresAt = Date().addingTimeInterval(ttl)
        
        let cacheEntry = RemotePostCacheRecord(
            platform: platform,
            cacheKey: cacheKey,
            payloadJson: payloadJson,
            statsJson: nil,
            expiresAt: expiresAt
        )
        
        // Check if entry exists and update, or create new
        if let existing = try await cacheRepository.get(platform: platform, cacheKey: cacheKey) {
            var updated = existing
            updated.payloadJson = payloadJson
            updated.fetchedAt = Date()
            updated.expiresAt = expiresAt
            _ = try await cacheRepository.update(entry: updated)
        } else {
            _ = try await cacheRepository.create(entry: cacheEntry)
        }
        
        logger.debug("Cached \(platform)/\(cacheKey) (expires: \(expiresAt))")
    }
    
    /// Cache data with stats
    public func cacheWithStats<T: Codable & Sendable, S: Codable & Sendable>(
        platform: String,
        cacheKey: String,
        data: T,
        stats: S,
        category: CacheCategory
    ) async throws {
        let payloadData = try JSONEncoder().encode(data)
        let payloadJson = String(data: payloadData, encoding: .utf8) ?? "{}"
        
        let statsData = try JSONEncoder().encode(stats)
        let statsJson = String(data: statsData, encoding: .utf8)
        
        let ttl = ttl(for: category)
        let expiresAt = Date().addingTimeInterval(ttl)
        
        let cacheEntry = RemotePostCacheRecord(
            platform: platform,
            cacheKey: cacheKey,
            payloadJson: payloadJson,
            statsJson: statsJson,
            expiresAt: expiresAt
        )
        
        if let existing = try await cacheRepository.get(platform: platform, cacheKey: cacheKey) {
            var updated = existing
            updated.payloadJson = payloadJson
            updated.statsJson = statsJson
            updated.fetchedAt = Date()
            updated.expiresAt = expiresAt
            _ = try await cacheRepository.update(entry: updated)
        } else {
            _ = try await cacheRepository.create(entry: cacheEntry)
        }
        
        logger.debug("Cached \(platform)/\(cacheKey) with stats (expires: \(expiresAt))")
    }
    
    /// Get cached data if not expired
    public func get<T: Codable & Sendable>(
        platform: String,
        cacheKey: String,
        as type: T.Type
    ) async throws -> T? {
        guard let entry = try await cacheRepository.get(platform: platform, cacheKey: cacheKey) else {
            return nil
        }
        
        // Check if expired
        if entry.expiresAt < Date() {
            logger.debug("Cache miss (expired): \(platform)/\(cacheKey)")
            return nil
        }
        
        // Parse payload
        guard let data = entry.payloadJson.data(using: .utf8) else {
            return nil
        }
        
        let decoded = try JSONDecoder().decode(T.self, from: data)
        logger.debug("Cache hit: \(platform)/\(cacheKey)")
        return decoded
    }
    
    /// Get cached data with stats
    public func getWithStats<T: Codable & Sendable, S: Codable & Sendable>(
        platform: String,
        cacheKey: String,
        dataType: T.Type,
        statsType: S.Type
    ) async throws -> (data: T, stats: S?)? {
        guard let entry = try await cacheRepository.get(platform: platform, cacheKey: cacheKey) else {
            return nil
        }
        
        if entry.expiresAt < Date() {
            logger.debug("Cache miss (expired): \(platform)/\(cacheKey)")
            return nil
        }
        
        guard let data = entry.payloadJson.data(using: .utf8) else {
            return nil
        }
        
        let decodedData = try JSONDecoder().decode(T.self, from: data)
        
        var decodedStats: S?
        if let statsJson = entry.statsJson, let statsData = statsJson.data(using: .utf8) {
            decodedStats = try? JSONDecoder().decode(S.self, from: statsData)
        }
        
        logger.debug("Cache hit: \(platform)/\(cacheKey)")
        return (decodedData, decodedStats)
    }
    
    /// Get cached data or fetch fresh (read-through cache)
    public func getOrFetch<T: Codable & Sendable>(
        platform: String,
        cacheKey: String,
        category: CacheCategory,
        fetch: @Sendable () async throws -> T
    ) async throws -> T {
        // Try cache first
        if let cached = try await get(platform: platform, cacheKey: cacheKey, as: T.self) {
            return cached
        }
        
        // Fetch fresh data
        let fresh = try await fetch()
        
        // Cache the fresh data
        try await cache(platform: platform, cacheKey: cacheKey, data: fresh, category: category)
        
        return fresh
    }
    
    /// Invalidate (delete) a specific cache entry
    public func invalidate(platform: String, cacheKey: String) async throws {
        try await cacheRepository.delete(platform: platform, cacheKey: cacheKey)
        logger.debug("Invalidated cache: \(platform)/\(cacheKey)")
    }
    
    /// Invalidate all entries for a platform
    public func invalidateAll(platform: String) async throws {
        // Use the repository's deleteExpired with a far-future date to delete all entries
        // This avoids loading all entries into memory
        // Note: This assumes the repository deleteExpired supports filtering by platform
        // If not, we iterate with a reasonable batch size to avoid memory pressure
        let farFuture = Date().addingTimeInterval(365 * 24 * 60 * 60)

        // Get expired entries for this platform only (using listExpired with platform filter if available)
        // For now, fetch in batches to avoid loading all into memory at once
        var deletedCount = 0
        let batchSize = 100

        // Since we don't have a direct platform filter in listExpired, we need to fetch and delete
        // This is still better than loading ALL entries - we process in batches
        while true {
            let entries = try await cacheRepository.listExpired(before: farFuture)
            let platformEntries = entries.filter { $0.platform == platform }

            if platformEntries.isEmpty {
                break
            }

            // Delete batch
            for entry in platformEntries.prefix(batchSize) {
                try await cacheRepository.delete(platform: entry.platform, cacheKey: entry.cacheKey)
                deletedCount += 1
            }

            // If we processed less than batch size, we're done
            if platformEntries.count < batchSize {
                break
            }
        }

        logger.debug("Invalidated \(deletedCount) cache entries for platform: \(platform)")
    }
    
    /// Clean up expired entries
    public func cleanupExpired() async throws {
        let now = Date()
        try await cacheRepository.deleteExpired(before: now)
        logger.debug("Cleaned up expired cache entries")
    }
    
    /// Get cache status for a key
    public func cacheStatus(platform: String, cacheKey: String) async throws -> CacheStatus {
        guard let entry = try await cacheRepository.get(platform: platform, cacheKey: cacheKey) else {
            return .miss
        }
        
        if entry.expiresAt < Date() {
            return .stale
        }
        
        return .fresh(fetchedAt: entry.fetchedAt, expiresAt: entry.expiresAt)
    }
    
    // MARK: - Private Methods
    
    private func ttl(for category: CacheCategory) -> TimeInterval {
        switch category {
        case .metadata:
            return configuration.metadataTTL
        case .stats:
            return configuration.statsTTL
        case .list:
            return configuration.listTTL
        case .custom(let ttl):
            return ttl
        }
    }
}

// MARK: - Cache Categories

public enum CacheCategory: Sendable {
    case metadata    // User profiles, post metadata, etc.
    case stats       // Views, likes, comments, etc.
    case list        // Lists of posts, campaigns, etc.
    case custom(TimeInterval)  // Custom TTL
}

// MARK: - Cache Status

public enum CacheStatus: Sendable {
    case miss                    // Not in cache
    case stale                   // In cache but expired
    case fresh(fetchedAt: Date, expiresAt: Date)  // Valid cached data
    
    public var isFresh: Bool {
        switch self {
        case .fresh:
            return true
        default:
            return false
        }
    }
    
    public var isStale: Bool {
        if case .stale = self {
            return true
        }
        return false
    }
    
    public var exists: Bool {
        switch self {
        case .miss:
            return false
        default:
            return true
        }
    }
}

// MARK: - Cache Keys

public enum CacheKey: Sendable {
    case deviation(id: String)
    case gallery(username: String, offset: Int)
    case userProfile(username: String?)
    case post(campaignId: String, postId: String)
    case campaignPosts(campaignId: String, cursor: String?)
    case campaignMembers(campaignId: String, cursor: String?)
    case campaign(campaignId: String)
    case identity
    
    public var stringValue: String {
        switch self {
        case .deviation(let id):
            return "deviation:\(id)"
        case .gallery(let username, let offset):
            return "gallery:\(username ?? "me"):\(offset)"
        case .userProfile(let username):
            return "profile:\(username ?? "me")"
        case .post(let campaignId, let postId):
            return "post:\(campaignId):\(postId)"
        case .campaignPosts(let campaignId, let cursor):
            return "campaign-posts:\(campaignId):\(cursor ?? "first")"
        case .campaignMembers(let campaignId, let cursor):
            return "campaign-members:\(campaignId):\(cursor ?? "first")"
        case .campaign(let campaignId):
            return "campaign:\(campaignId)"
        case .identity:
            return "identity"
        }
    }
}

