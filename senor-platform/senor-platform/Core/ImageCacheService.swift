import Foundation

// MARK: - Dependencies
// AppLogger is accessed through the Core module's shared logging infrastructure

/// Disk-based image caching service with LRU eviction and size limits
public actor ImageCacheService {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int64
    private let defaultTTL: TimeInterval

    private var currentCacheSize: Int64 = 0

    public init(
        cacheName: String = "ImageCache",
        maxCacheSizeMB: Int = 100,
        defaultTTLHours: Int = 3
    ) {
        self.maxCacheSize = Int64(maxCacheSizeMB) * 1024 * 1024
        self.defaultTTL = TimeInterval(defaultTTLHours * 3600)

        // Get cache directory in app support
        let appSupportURL: URL
        do {
            appSupportURL = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            // Fallback to temp directory if caches directory is unavailable
            appSupportURL = fileManager.temporaryDirectory
        }
        let bundleId = Bundle.main.bundleIdentifier ?? "fahad.senor-platform"
        self.cacheDirectory = appSupportURL
            .appendingPathComponent(bundleId, isDirectory: true)
            .appendingPathComponent(cacheName, isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        // Calculate initial size
        Task {
            await calculateCacheSize()
        }
    }

    /// Cache image from URL to disk, returns local file URL
    public func cacheImage(from url: URL, key: String? = nil) async throws -> URL {
        let cacheKey = key ?? url.absoluteString
        let safeKey = makeSafeFilename(from: cacheKey)
        let fileURL = cacheDirectory.appendingPathComponent(safeKey)

        // Check if already cached and not expired
        if let existingURL = getCachedImage(key: cacheKey),
           !isExpired(fileURL: existingURL) {
            // Update access time
            try? updateAccessTime(fileURL: existingURL)
            return existingURL
        }

        // Download image data
        let (data, _) = try await URLSession.shared.data(from: url)

        // Ensure we have space
        await ensureSpace(for: Int64(data.count))

        // Write to disk
        try data.write(to: fileURL)

        // Store metadata
        try storeMetadata(for: fileURL, originalURL: url.absoluteString)

        // Update cache size
        currentCacheSize += Int64(data.count)

        return fileURL
    }

    /// Get cached image URL if it exists and is not expired
    public func getCachedImage(key: String) -> URL? {
        let safeKey = makeSafeFilename(from: key)
        let fileURL = cacheDirectory.appendingPathComponent(safeKey)

        guard fileManager.fileExists(atPath: fileURL.path),
              !isExpired(fileURL: fileURL) else {
            return nil
        }

        // Update access time
        try? updateAccessTime(fileURL: fileURL)

        return fileURL
    }

    /// Get cached image for URL (convenience method)
    public func getCachedImage(for url: URL) -> URL? {
        return getCachedImage(key: url.absoluteString)
    }

    /// Preload/cache multiple images
    public func preloadImages(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = try? await self.cacheImage(from: url)
                }
            }
        }
    }

    /// Clean up expired images
    public func cleanupExpired() async throws {
        let files = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )

        var deletedCount = 0
        var freedSpace: Int64 = 0

        for fileURL in files {
            if isExpired(fileURL: fileURL) {
                if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let size = attrs[.size] as? Int64 {
                    freedSpace += size
                }
                try? fileManager.removeItem(at: fileURL)
                try? fileManager.removeItem(at: metadataURL(for: fileURL))
                deletedCount += 1
            }
        }

        currentCacheSize -= freedSpace
        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file
        let freedString = byteFormatter.string(fromByteCount: freedSpace)
        AppLogger.ui.debug("[ImageCache] Cleaned up \(deletedCount) expired images, freed \(freedString)")
    }

    /// Clear entire cache
    public func clearCache() async throws {
        let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for fileURL in files {
            try fileManager.removeItem(at: fileURL)
        }
        currentCacheSize = 0
    }

    // MARK: - Private Methods

    private func makeSafeFilename(from key: String) -> String {
        // Create safe filename from URL or key
        var safe = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
            .replacingOccurrences(of: "=", with: "_")

        // Limit length and add extension
        if safe.count > 200 {
            safe = String(safe.prefix(200))
        }

        // Add hash for uniqueness if needed
        let hash = String(key.hashValue)
        return "\(safe)_\(hash).jpg"
    }

    private func metadataURL(for fileURL: URL) -> URL {
        return fileURL.appendingPathExtension("meta")
    }

    private func storeMetadata(for fileURL: URL, originalURL: String) throws {
        let metaURL = metadataURL(for: fileURL)
        let metadata = ImageMetadata(
            originalURL: originalURL,
            cachedAt: Date(),
            lastAccessed: Date()
        )
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metaURL)
    }

    private func isExpired(fileURL: URL) -> Bool {
        guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return true
        }

        let age = Date().timeIntervalSince(modDate)
        return age > defaultTTL
    }

    private func updateAccessTime(fileURL: URL) throws {
        let metaURL = metadataURL(for: fileURL)

        // Update file modification time
        try fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )

        // Update metadata
        if let data = try? Data(contentsOf: metaURL),
           var metadata = try? JSONDecoder().decode(ImageMetadata.self, from: data) {
            metadata.lastAccessed = Date()
            let newData = try JSONEncoder().encode(metadata)
            try newData.write(to: metaURL)
        }
    }

    private func calculateCacheSize() async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }

        var totalSize: Int64 = 0
        for fileURL in files where fileURL.pathExtension != "meta" {
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        currentCacheSize = totalSize
    }

    private func ensureSpace(for requiredBytes: Int64) async {
        // Clean up expired first
        try? await cleanupExpired()

        // If still not enough space, evict oldest
        while currentCacheSize + requiredBytes > maxCacheSize {
            guard let oldestFile = await findOldestFile() else { break }

            if let attrs = try? fileManager.attributesOfItem(atPath: oldestFile.path),
               let size = attrs[.size] as? Int64 {
                currentCacheSize -= size
            }

            try? fileManager.removeItem(at: oldestFile)
            try? fileManager.removeItem(at: metadataURL(for: oldestFile))
        }
    }

    private func findOldestFile() async -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        return files
            .filter { $0.pathExtension != "meta" }
            .compactMap { fileURL -> (URL, Date)? in
                guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                      let date = attrs[.modificationDate] as? Date else {
                    return nil
                }
                return (fileURL, date)
            }
            .sorted { $0.1 < $1.1 }
            .first?.0
    }
}

// MARK: - Image Metadata

private struct ImageMetadata: Codable, Sendable {
    let originalURL: String
    let cachedAt: Date
    var lastAccessed: Date
}

