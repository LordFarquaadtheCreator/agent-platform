import Foundation
#if canImport(GRDB)
import GRDB

// MARK: - Patreon Data Store

public final class PatreonDataStore {
    private let databaseManager: DatabaseManager
    private let logger = AppLogger.database

    public init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    // MARK: - Stats Operations

    public func saveStats(_ stats: PatreonStatsRecord) async throws {
        try await databaseManager.asyncWrite { db in
            try stats.insert(db)
        }
        logger.debug("Saved Patreon stats: \(stats.totalPatrons) patrons, \(stats.activePatrons) active")
    }

    public func getRecentStats(limit: Int = 30) async throws -> [PatreonStatsRecord] {
        try await databaseManager.asyncRead { db in
            try PatreonStatsRecord
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - Pledge Event Operations

    public func savePledgeEvent(_ event: PatreonPledgeEventRecord) async throws {
        try await databaseManager.asyncWrite { db in
            try event.insert(db)
        }
        logger.debug("Saved pledge event: \(event.eventType) for member \(event.memberId)")
    }

    public func getPledgeEvents(for memberId: String, limit: Int = 50) async throws -> [PatreonPledgeEventRecord] {
        try await databaseManager.asyncRead { db in
            try PatreonPledgeEventRecord
                .filter(Column("member_id") == memberId)
                .order(Column("date").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func getRecentPledgeEvents(limit: Int = 100) async throws -> [PatreonPledgeEventRecord] {
        try await databaseManager.asyncRead { db in
            try PatreonPledgeEventRecord
                .order(Column("date").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}
#endif
