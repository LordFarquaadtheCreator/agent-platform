import Foundation

/// Repository for managing agents
public protocol AgentRepository: Sendable {
    func create(agent: AgentRecord) async throws -> AgentRecord
    func update(agent: AgentRecord) async throws -> AgentRecord
    func delete(id: String) async throws
    func getById(id: String) async throws -> AgentRecord?
    func getByDisplayName(name: String) async throws -> AgentRecord?
    func listAll() async throws -> [AgentRecord]
    func listActive() async throws -> [AgentRecord]
    func existsWithName(name: String) async throws -> Bool
}

/// Repository for managing tasks
public protocol TaskRepository: Sendable {
    func create(task: TaskRecord) async throws -> TaskRecord
    func update(task: TaskRecord) async throws -> TaskRecord
    func delete(id: String) async throws
    func getById(id: String) async throws -> TaskRecord?
    func listByAgent(agentId: String) async throws -> [TaskRecord]
    func listEnabled() async throws -> [TaskRecord]
    func countByAgent(agentId: String) async throws -> Int
}

/// Repository for managing task schedules
public protocol TaskScheduleRepository: Sendable {
    func create(schedule: TaskScheduleRecord) async throws -> TaskScheduleRecord
    func update(schedule: TaskScheduleRecord) async throws -> TaskScheduleRecord
    func delete(id: String) async throws
    func getById(id: String) async throws -> TaskScheduleRecord?
    func getByTask(taskId: String) async throws -> TaskScheduleRecord?
    func listDue(before: Date) async throws -> [TaskScheduleRecord]
    func listActive() async throws -> [TaskScheduleRecord]
}

/// Repository for managing task runs
public protocol TaskRunRepository: Sendable {
    func create(run: TaskRunRecord) async throws -> TaskRunRecord
    func update(run: TaskRunRecord) async throws -> TaskRunRecord
    func getById(id: String) async throws -> TaskRunRecord?
    func listByTask(taskId: String, limit: Int) async throws -> [TaskRunRecord]
    func listByAgent(agentId: String, limit: Int) async throws -> [TaskRunRecord]
    func listActive() async throws -> [TaskRunRecord]
    func listRecent(limit: Int) async throws -> [TaskRunRecord]
    func countByAgent(agentId: String) async throws -> Int
}

/// Repository for managing generated content
public protocol GeneratedContentRepository: Sendable {
    func create(content: GeneratedContentRecord) async throws -> GeneratedContentRecord
    func update(content: GeneratedContentRecord) async throws -> GeneratedContentRecord
    func getById(id: String) async throws -> GeneratedContentRecord?
    func getByTaskRun(taskRunId: String) async throws -> GeneratedContentRecord?
    func listByAgent(agentId: String, limit: Int) async throws -> [GeneratedContentRecord]
    func listRecent(limit: Int) async throws -> [GeneratedContentRecord]

    // Version management
    func createVersion(version: GeneratedContentVersionRecord) async throws -> GeneratedContentVersionRecord
    func listVersions(contentId: String) async throws -> [GeneratedContentVersionRecord]
    func getVersion(contentId: String, version: Int) async throws -> GeneratedContentVersionRecord?
}

/// Repository for managing approval queue
public protocol ApprovalQueueRepository: Sendable {
    func create(entry: ApprovalQueueRecord) async throws -> ApprovalQueueRecord
    func update(entry: ApprovalQueueRecord) async throws -> ApprovalQueueRecord
    func getById(id: String) async throws -> ApprovalQueueRecord?
    func getByContent(contentId: String) async throws -> ApprovalQueueRecord?
    func listByStatus(status: String, limit: Int) async throws -> [ApprovalQueueRecord]
    func listPending(limit: Int) async throws -> [ApprovalQueueRecord]
    func listByBatchToken(token: String) async throws -> [ApprovalQueueRecord]
}

/// Repository for managing publication targets
public protocol PublicationTargetRepository: Sendable {
    func create(target: PublicationTargetRecord) async throws -> PublicationTargetRecord
    func update(target: PublicationTargetRecord) async throws -> PublicationTargetRecord
    func getById(id: String) async throws -> PublicationTargetRecord?
    func listByContent(contentId: String) async throws -> [PublicationTargetRecord]
    func listByPlatform(platform: String, limit: Int) async throws -> [PublicationTargetRecord]
    func listPending(limit: Int) async throws -> [PublicationTargetRecord]
}

/// Repository for managing remote post cache
public protocol RemotePostCacheRepository: Sendable {
    func create(entry: RemotePostCacheRecord) async throws -> RemotePostCacheRecord
    func update(entry: RemotePostCacheRecord) async throws -> RemotePostCacheRecord
    func get(platform: String, cacheKey: String) async throws -> RemotePostCacheRecord?
    func listExpired(before: Date) async throws -> [RemotePostCacheRecord]
    func deleteExpired(before: Date) async throws
    func delete(platform: String, cacheKey: String) async throws
}

/// Repository for managing task types
public protocol TaskTypeRepository: Sendable {
    func create(taskType: TaskTypeRecord) async throws -> TaskTypeRecord
    func update(taskType: TaskTypeRecord) async throws -> TaskTypeRecord
    func delete(id: String) async throws
    func getById(id: String) async throws -> TaskTypeRecord?
    func getByName(name: String) async throws -> TaskTypeRecord?
    func listAll() async throws -> [TaskTypeRecord]
}

/// Repository for managing ComfyUI executions
public protocol ComfyUIExecutionRepository: Sendable {
    func create(execution: ComfyUIExecutionRecord) async throws -> ComfyUIExecutionRecord
    func update(execution: ComfyUIExecutionRecord) async throws -> ComfyUIExecutionRecord
    func getById(id: String) async throws -> ComfyUIExecutionRecord?
    func listByWorkflow(workflowID: String, limit: Int) async throws -> [ComfyUIExecutionRecord]
    func listRecent(limit: Int) async throws -> [ComfyUIExecutionRecord]
    func listByStatus(status: String, limit: Int) async throws -> [ComfyUIExecutionRecord]
    func delete(id: String) async throws
}
