import Foundation
#if canImport(GRDB)
import GRDB

// MARK: - Chat History Store

public final class ChatHistoryStore {
    private let databaseManager: DatabaseManager

    public init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    public func load(for section: AppSection) async throws -> [ChatMessage] {
        try await databaseManager.asyncRead { db in
            guard let record = try ChatHistoryRecord
                .filter(ChatHistoryRecord.Columns.section == section.rawValue)
                .order(ChatHistoryRecord.Columns.updatedAt.desc)
                .fetchOne(db) else {
                return []
            }

            return record.messages
        }
    }

    public func save(for section: AppSection, messages: [ChatMessage]) async throws {
        let record = ChatHistoryRecord(
            section: section.rawValue,
            messages: messages,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await databaseManager.asyncWrite { db in
            // Upsert: delete existing then insert new
            try ChatHistoryRecord
                .filter(ChatHistoryRecord.Columns.section == section.rawValue)
                .deleteAll(db)

            try record.insert(db)
        }
    }

    public func clear(for section: AppSection) async throws {
        try await databaseManager.asyncWrite { db in
            try ChatHistoryRecord
                .filter(ChatHistoryRecord.Columns.section == section.rawValue)
                .deleteAll(db)
        }
    }

    public func listAllSessions() async throws -> [ChatSession] {
        try await databaseManager.asyncRead { db in
            let records = try ChatHistoryRecord
                .order(ChatHistoryRecord.Columns.updatedAt.desc)
                .fetchAll(db)

            return records.map { record in
                ChatSession(
                    section: record.section,
                    messages: record.messages,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt
                )
            }
        }
    }
}

public struct ChatSession: Identifiable {
    public let id = UUID()
    public let section: String
    public let messages: [ChatMessage]
    public let createdAt: Date
    public let updatedAt: Date
}

// MARK: - Database Record

private struct ChatHistoryRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "chat_history" }

    var id: Int64?
    let section: String
    let messagesJSON: String
    let createdAt: Date
    let updatedAt: Date

    // Coding keys map Swift property names to database column names
    enum CodingKeys: String, CodingKey {
        case id
        case section
        case messagesJSON = "messages_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns {
        static let id = Column("id")
        static let section = Column("section")
        static let messagesJSON = Column("messages_json")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }

    init(section: String, messages: [ChatMessage], createdAt: Date, updatedAt: Date) {
        self.id = nil
        self.section = section
        self.messagesJSON = (try? JSONEncoder().encode(messages).base64EncodedString()) ?? ""
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var messages: [ChatMessage] {
        guard let data = Data(base64Encoded: messagesJSON),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return []
        }
        return messages
    }
}
#endif
