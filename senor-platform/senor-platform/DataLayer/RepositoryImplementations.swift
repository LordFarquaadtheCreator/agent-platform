import Foundation
#if canImport(GRDB)
@preconcurrency import GRDB
#endif

/// Concrete implementation of AgentRepository
public final class AgentRepositoryImpl: AgentRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(agent: AgentRecord) async throws -> AgentRecord {
        try await dbManager.asyncWrite { db in
            let agent = agent
            try agent.insert(db)
            return agent
        }
    }

    public func update(agent: AgentRecord) async throws -> AgentRecord {
        try await dbManager.asyncWrite { db in
            var agent = agent
            agent.updatedAt = Date()
            try agent.update(db)
            return agent
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbManager.asyncWrite { db in
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
            let task = task
            try task.insert(db)
            return task
        }
    }

    public func update(task: TaskRecord) async throws -> TaskRecord {
        try await dbManager.asyncWrite { db in
            var task = task
            task.updatedAt = Date()
            try task.update(db)
            return task
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbManager.asyncWrite { db in
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

    public func countByAgent(agentId: String) async throws -> Int {
        try await dbManager.asyncRead { db in
            try TaskRecord
                .filter(Column("agent_id") == agentId)
                .fetchCount(db)
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
            let schedule = schedule
            try schedule.insert(db)
            return schedule
        }
    }

    public func update(schedule: TaskScheduleRecord) async throws -> TaskScheduleRecord {
        try await dbManager.asyncWrite { db in
            var schedule = schedule
            schedule.updatedAt = Date()
            try schedule.update(db)
            return schedule
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbManager.asyncWrite { db in
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
            let run = run
            try run.insert(db)
            return run
        }
    }

    public func update(run: TaskRunRecord) async throws -> TaskRunRecord {
        try await dbManager.asyncWrite { db in
            let run = run
            try run.update(db)
            return run
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

    public func countByAgent(agentId: String) async throws -> Int {
        try await dbManager.asyncRead { db in
            try TaskRunRecord
                .filter(Column("agent_id") == agentId)
                .fetchCount(db)
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
            let content = content
            try content.insert(db)
            return content
        }
    }

    public func update(content: GeneratedContentRecord) async throws -> GeneratedContentRecord {
        try await dbManager.asyncWrite { db in
            var content = content
            content.updatedAt = Date()
            try content.update(db)
            return content
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
            let version = version
            try version.insert(db)
            return version
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
            let entry = entry
            try entry.insert(db)
            return entry
        }
    }

    public func update(entry: ApprovalQueueRecord) async throws -> ApprovalQueueRecord {
        try await dbManager.asyncWrite { db in
            var entry = entry
            entry.updatedAt = Date()
            try entry.update(db)
            return entry
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
            let target = target
            try target.insert(db)
            return target
        }
    }

    public func update(target: PublicationTargetRecord) async throws -> PublicationTargetRecord {
        try await dbManager.asyncWrite { db in
            var target = target
            target.updatedAt = Date()
            try target.update(db)
            return target
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
            let entry = entry
            try entry.insert(db)
            return entry
        }
    }

    public func update(entry: RemotePostCacheRecord) async throws -> RemotePostCacheRecord {
        try await dbManager.asyncWrite { db in
            let entry = entry
            try entry.update(db)
            return entry
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
        _ = try await dbManager.asyncWrite { db in
            try RemotePostCacheRecord
                .filter(Column("expires_at") < before)
                .deleteAll(db)
        }
    }

    public func delete(platform: String, cacheKey: String) async throws {
        _ = try await dbManager.asyncWrite { db in
            try RemotePostCacheRecord
                .filter(Column("platform") == platform)
                .filter(Column("cache_key") == cacheKey)
                .deleteAll(db)
        }
    }
}

/// Concrete implementation of ComfyUIExecutionRepository
public final class ComfyUIExecutionRepositoryImpl: ComfyUIExecutionRepository {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    public func create(execution: ComfyUIExecutionRecord) async throws -> ComfyUIExecutionRecord {
        try await dbManager.asyncWrite { db in
            let execution = execution
            try execution.insert(db)
            return execution
        }
    }

    public func update(execution: ComfyUIExecutionRecord) async throws -> ComfyUIExecutionRecord {
        try await dbManager.asyncWrite { db in
            let execution = execution
            try execution.update(db)
            return execution
        }
    }

    public func getById(id: String) async throws -> ComfyUIExecutionRecord? {
        try await dbManager.asyncRead { db in
            try ComfyUIExecutionRecord.fetchOne(db, key: id)
        }
    }

    public func listByWorkflow(workflowID: String, limit: Int) async throws -> [ComfyUIExecutionRecord] {
        try await dbManager.asyncRead { db in
            try ComfyUIExecutionRecord
                .filter(Column("workflow_id") == workflowID)
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func listRecent(limit: Int) async throws -> [ComfyUIExecutionRecord] {
        try await dbManager.asyncRead { db in
            try ComfyUIExecutionRecord
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func listByStatus(status: String, limit: Int) async throws -> [ComfyUIExecutionRecord] {
        try await dbManager.asyncRead { db in
            try ComfyUIExecutionRecord
                .filter(Column("status") == status)
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbManager.asyncWrite { db in
            try ComfyUIExecutionRecord.deleteOne(db, key: id)
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
            let taskType = taskType
            try taskType.insert(db)
            return taskType
        }
    }

    public func update(taskType: TaskTypeRecord) async throws -> TaskTypeRecord {
        try await dbManager.asyncWrite { db in
            let taskType = taskType
            try taskType.update(db)
            return taskType
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbManager.asyncWrite { db in
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
