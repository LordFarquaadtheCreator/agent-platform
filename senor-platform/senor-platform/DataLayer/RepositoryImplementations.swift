import Foundation
import GRDB

/// Concrete implementation of AgentRepository
public final class AgentRepositoryImpl: AgentRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(agent: AgentRecord) async throws -> AgentRecord {
        try await dbManager.asyncWrite { db in
            var mutableAgent = agent
            try mutableAgent.insert(db)
            return mutableAgent
        }
    }

    public func update(agent: AgentRecord) async throws -> AgentRecord {
        try await dbManager.asyncWrite { db in
            var mutableAgent = agent
            mutableAgent.updatedAt = Date()
            try mutableAgent.update(db)
            return mutableAgent
        }
    }

    public func delete(id: String) async throws {
        try await dbManager.asyncWrite { db in
            try AgentRecord.deleteOne(db, key: id)
        }
    }

    public func getById(id: String) async throws -> AgentRecord? {
        try await dbManager.asyncRead { db in
            try AgentRecord.fetchOne(db, key: id)
        }
    }

    public func getByDisplayName(name: String) async throws -> AgentRecord? {
        try await dbManager.asyncRead { db in
            try AgentRecord
                .filter(Column("display_name") == name)
                .fetchOne(db)
        }
    }

    public func listAll() async throws -> [AgentRecord] {
        try await dbManager.asyncRead { db in
            try AgentRecord
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    public func listActive() async throws -> [AgentRecord] {
        try await dbManager.asyncRead { db in
            try AgentRecord
                .filter(Column("status") != "disabled")
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    public func existsWithName(name: String) async throws -> Bool {
        try await dbManager.asyncRead { db in
            try AgentRecord
                .filter(Column("display_name") == name)
                .fetchCount(db) > 0
        }
    }
}

/// Concrete implementation of TaskRepository
public final class TaskRepositoryImpl: TaskRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(task: TaskRecord) async throws -> TaskRecord {
        try await dbManager.asyncWrite { db in
            var mutableTask = task
            try mutableTask.insert(db)
            return mutableTask
        }
    }

    public func update(task: TaskRecord) async throws -> TaskRecord {
        try await dbManager.asyncWrite { db in
            var mutableTask = task
            mutableTask.updatedAt = Date()
            try mutableTask.update(db)
            return mutableTask
        }
    }

    public func delete(id: String) async throws {
        try await dbManager.asyncWrite { db in
            try TaskRecord.deleteOne(db, key: id)
        }
    }

    public func getById(id: String) async throws -> TaskRecord? {
        try await dbManager.asyncRead { db in
            try TaskRecord.fetchOne(db, key: id)
        }
    }

    public func listByAgent(agentId: String) async throws -> [TaskRecord] {
        try await dbManager.asyncRead { db in
            try TaskRecord
                .filter(Column("agent_id") == agentId)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    public func listEnabled() async throws -> [TaskRecord] {
        try await dbManager.asyncRead { db in
            try TaskRecord
                .filter(Column("is_enabled") == true)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }
}

/// Concrete implementation of TaskScheduleRepository
public final class TaskScheduleRepositoryImpl: TaskScheduleRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(schedule: TaskScheduleRecord) async throws -> TaskScheduleRecord {
        try await dbManager.asyncWrite { db in
            var mutableSchedule = schedule
            try mutableSchedule.insert(db)
            return mutableSchedule
        }
    }

    public func update(schedule: TaskScheduleRecord) async throws -> TaskScheduleRecord {
        try await dbManager.asyncWrite { db in
            var mutableSchedule = schedule
            mutableSchedule.updatedAt = Date()
            try mutableSchedule.update(db)
            return mutableSchedule
        }
    }

    public func delete(id: String) async throws {
        try await dbManager.asyncWrite { db in
            try TaskScheduleRecord.deleteOne(db, key: id)
        }
    }

    public func getById(id: String) async throws -> TaskScheduleRecord? {
        try await dbManager.asyncRead { db in
            try TaskScheduleRecord.fetchOne(db, key: id)
        }
    }

    public func getByTask(taskId: String) async throws -> TaskScheduleRecord? {
        try await dbManager.asyncRead { db in
            try TaskScheduleRecord
                .filter(Column("task_id") == taskId)
                .fetchOne(db)
        }
    }

    public func listDue(before: Date) async throws -> [TaskScheduleRecord] {
        try await dbManager.asyncRead { db in
            try TaskScheduleRecord
                .filter(Column("is_active") == true)
                .filter(Column("next_run_at") <= before)
                .order(Column("next_run_at").asc)
                .fetchAll(db)
        }
    }

    public func listActive() async throws -> [TaskScheduleRecord] {
        try await dbManager.asyncRead { db in
            try TaskScheduleRecord
                .filter(Column("is_active") == true)
                .order(Column("next_run_at").asc)
                .fetchAll(db)
        }
    }
}

/// Concrete implementation of TaskRunRepository
public final class TaskRunRepositoryImpl: TaskRunRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(run: TaskRunRecord) async throws -> TaskRunRecord {
        try await dbManager.asyncWrite { db in
            var mutableRun = run
            try mutableRun.insert(db)
            return mutableRun
        }
    }

    public func update(run: TaskRunRecord) async throws -> TaskRunRecord {
        try await dbManager.asyncWrite { db in
            var mutableRun = run
            try mutableRun.update(db)
            return mutableRun
        }
    }

    public func getById(id: String) async throws -> TaskRunRecord? {
        try await dbManager.asyncRead { db in
            try TaskRunRecord.fetchOne(db, key: id)
        }
    }

    public func listByTask(taskId: String, limit: Int) async throws -> [TaskRunRecord] {
        try await dbManager.asyncRead { db in
            try TaskRunRecord
                .filter(Column("task_id") == taskId)
                .order(Column("scheduled_for").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func listByAgent(agentId: String, limit: Int) async throws -> [TaskRunRecord] {
        try await dbManager.asyncRead { db in
            try TaskRunRecord
                .filter(Column("agent_id") == agentId)
                .order(Column("scheduled_for").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func listActive() async throws -> [TaskRunRecord] {
        try await dbManager.asyncRead { db in
            try TaskRunRecord
                .filter(Column("status") == "running")
                .order(Column("started_at").desc)
                .fetchAll(db)
        }
    }

    public func listRecent(limit: Int) async throws -> [TaskRunRecord] {
        try await dbManager.asyncRead { db in
            try TaskRunRecord
                .order(Column("scheduled_for").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}

/// Concrete implementation of GeneratedContentRepository
public final class GeneratedContentRepositoryImpl: GeneratedContentRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(content: GeneratedContentRecord) async throws -> GeneratedContentRecord {
        try await dbManager.asyncWrite { db in
            var mutableContent = content
            try mutableContent.insert(db)
            return mutableContent
        }
    }

    public func update(content: GeneratedContentRecord) async throws -> GeneratedContentRecord {
        try await dbManager.asyncWrite { db in
            var mutableContent = content
            mutableContent.updatedAt = Date()
            try mutableContent.update(db)
            return mutableContent
        }
    }

    public func getById(id: String) async throws -> GeneratedContentRecord? {
        try await dbManager.asyncRead { db in
            try GeneratedContentRecord.fetchOne(db, key: id)
        }
    }

    public func getByTaskRun(taskRunId: String) async throws -> GeneratedContentRecord? {
        try await dbManager.asyncRead { db in
            try GeneratedContentRecord
                .filter(Column("task_run_id") == taskRunId)
                .fetchOne(db)
        }
    }

    public func listByAgent(agentId: String, limit: Int) async throws -> [GeneratedContentRecord] {
        try await dbManager.asyncRead { db in
            try GeneratedContentRecord
                .filter(Column("agent_id") == agentId)
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func listRecent(limit: Int) async throws -> [GeneratedContentRecord] {
        try await dbManager.asyncRead { db in
            try GeneratedContentRecord
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - Version Management

    public func createVersion(version: GeneratedContentVersionRecord) async throws -> GeneratedContentVersionRecord {
        try await dbManager.asyncWrite { db in
            var mutableVersion = version
            try mutableVersion.insert(db)
            return mutableVersion
        }
    }

    public func listVersions(contentId: String) async throws -> [GeneratedContentVersionRecord] {
        try await dbManager.asyncRead { db in
            try GeneratedContentVersionRecord
                .filter(Column("generated_content_id") == contentId)
                .order(Column("version").desc)
                .fetchAll(db)
        }
    }

    public func getVersion(contentId: String, version: Int) async throws -> GeneratedContentVersionRecord? {
        try await dbManager.asyncRead { db in
            try GeneratedContentVersionRecord
                .filter(Column("generated_content_id") == contentId)
                .filter(Column("version") == version)
                .fetchOne(db)
        }
    }
}

/// Concrete implementation of ApprovalQueueRepository
public final class ApprovalQueueRepositoryImpl: ApprovalQueueRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(entry: ApprovalQueueRecord) async throws -> ApprovalQueueRecord {
        try await dbManager.asyncWrite { db in
            var mutableEntry = entry
            try mutableEntry.insert(db)
            return mutableEntry
        }
    }

    public func update(entry: ApprovalQueueRecord) async throws -> ApprovalQueueRecord {
        try await dbManager.asyncWrite { db in
            var mutableEntry = entry
            mutableEntry.updatedAt = Date()
            try mutableEntry.update(db)
            return mutableEntry
        }
    }

    public func getById(id: String) async throws -> ApprovalQueueRecord? {
        try await dbManager.asyncRead { db in
            try ApprovalQueueRecord.fetchOne(db, key: id)
        }
    }

    public func getByContent(contentId: String) async throws -> ApprovalQueueRecord? {
        try await dbManager.asyncRead { db in
            try ApprovalQueueRecord
                .filter(Column("generated_content_id") == contentId)
                .fetchOne(db)
        }
    }

    public func listByStatus(status: String, limit: Int) async throws -> [ApprovalQueueRecord] {
        try await dbManager.asyncRead { db in
            try ApprovalQueueRecord
                .filter(Column("approval_status") == status)
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func listPending(limit: Int) async throws -> [ApprovalQueueRecord] {
        try await listByStatus(status: "pending", limit: limit)
    }

    public func listByBatchToken(token: String) async throws -> [ApprovalQueueRecord] {
        try await dbManager.asyncRead { db in
            try ApprovalQueueRecord
                .filter(Column("batch_token") == token)
                .fetchAll(db)
        }
    }
}

/// Concrete implementation of PublicationTargetRepository
public final class PublicationTargetRepositoryImpl: PublicationTargetRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(target: PublicationTargetRecord) async throws -> PublicationTargetRecord {
        try await dbManager.asyncWrite { db in
            var mutableTarget = target
            try mutableTarget.insert(db)
            return mutableTarget
        }
    }

    public func update(target: PublicationTargetRecord) async throws -> PublicationTargetRecord {
        try await dbManager.asyncWrite { db in
            var mutableTarget = target
            mutableTarget.updatedAt = Date()
            try mutableTarget.update(db)
            return mutableTarget
        }
    }

    public func getById(id: String) async throws -> PublicationTargetRecord? {
        try await dbManager.asyncRead { db in
            try PublicationTargetRecord.fetchOne(db, key: id)
        }
    }

    public func listByContent(contentId: String) async throws -> [PublicationTargetRecord] {
        try await dbManager.asyncRead { db in
            try PublicationTargetRecord
                .filter(Column("generated_content_id") == contentId)
                .fetchAll(db)
        }
    }

    public func listByPlatform(platform: String, limit: Int) async throws -> [PublicationTargetRecord] {
        try await dbManager.asyncRead { db in
            try PublicationTargetRecord
                .filter(Column("platform") == platform)
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func listPending(limit: Int) async throws -> [PublicationTargetRecord] {
        try await dbManager.asyncRead { db in
            try PublicationTargetRecord
                .filter(Column("state") == "pending")
                .order(Column("scheduled_at").asc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}

/// Concrete implementation of RemotePostCacheRepository
public final class RemotePostCacheRepositoryImpl: RemotePostCacheRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(entry: RemotePostCacheRecord) async throws -> RemotePostCacheRecord {
        try await dbManager.asyncWrite { db in
            var mutableEntry = entry
            try mutableEntry.insert(db)
            return mutableEntry
        }
    }

    public func update(entry: RemotePostCacheRecord) async throws -> RemotePostCacheRecord {
        try await dbManager.asyncWrite { db in
            var mutableEntry = entry
            try mutableEntry.update(db)
            return mutableEntry
        }
    }

    public func get(platform: String, cacheKey: String) async throws -> RemotePostCacheRecord? {
        try await dbManager.asyncRead { db in
            try RemotePostCacheRecord
                .filter(Column("platform") == platform)
                .filter(Column("cache_key") == cacheKey)
                .fetchOne(db)
        }
    }

    public func listExpired(before: Date) async throws -> [RemotePostCacheRecord] {
        try await dbManager.asyncRead { db in
            try RemotePostCacheRecord
                .filter(Column("expires_at") < before)
                .fetchAll(db)
        }
    }

    public func deleteExpired(before: Date) async throws {
        try await dbManager.asyncWrite { db in
            try RemotePostCacheRecord
                .filter(Column("expires_at") < before)
                .deleteAll(db)
        }
    }

    public func delete(platform: String, cacheKey: String) async throws {
        try await dbManager.asyncWrite { db in
            try RemotePostCacheRecord
                .filter(Column("platform") == platform)
                .filter(Column("cache_key") == cacheKey)
                .deleteAll(db)
        }
    }
}

/// Concrete implementation of TaskTypeRepository
public final class TaskTypeRepositoryImpl: TaskTypeRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(taskType: TaskTypeRecord) async throws -> TaskTypeRecord {
        try await dbManager.asyncWrite { db in
            var mutableTaskType = taskType
            try mutableTaskType.insert(db)
            return mutableTaskType
        }
    }

    public func update(taskType: TaskTypeRecord) async throws -> TaskTypeRecord {
        try await dbManager.asyncWrite { db in
            var mutableTaskType = taskType
            try mutableTaskType.update(db)
            return mutableTaskType
        }
    }

    public func delete(id: String) async throws {
        try await dbManager.asyncWrite { db in
            try TaskTypeRecord.deleteOne(db, key: id)
        }
    }

    public func getById(id: String) async throws -> TaskTypeRecord? {
        try await dbManager.asyncRead { db in
            try TaskTypeRecord.fetchOne(db, key: id)
        }
    }

    public func getByName(name: String) async throws -> TaskTypeRecord? {
        try await dbManager.asyncRead { db in
            try TaskTypeRecord
                .filter(Column("name") == name)
                .fetchOne(db)
        }
    }

    public func listAll() async throws -> [TaskTypeRecord] {
        try await dbManager.asyncRead { db in
            try TaskTypeRecord
                .order(Column("name").asc)
                .fetchAll(db)
        }
    }
}
