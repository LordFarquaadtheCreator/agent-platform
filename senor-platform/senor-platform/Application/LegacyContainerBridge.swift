import Foundation

@MainActor
struct LegacyContainerSnapshot {
    let databaseManager: DatabaseManager
    let agentRepository: AgentRepository
    let taskRepository: TaskRepository
    let taskScheduleRepository: TaskScheduleRepository
    let taskRunRepository: TaskRunRepository
    let contentRepository: GeneratedContentRepository
    let approvalRepository: ApprovalQueueRepository
    let publicationRepository: PublicationTargetRepository
    let cacheRepository: RemotePostCacheRepository
    let taskTypeRepository: TaskTypeRepository
    let settingsService: SettingsService
    let versioningService: ContentVersioningService
    let approvalService: ApprovalService
    let publicationService: PublicationService
    let cacheService: CacheService
    let workerManager: WorkerProcessManager
    let taskPipeline: TaskExecutionPipeline
    let scheduler: SchedulerEngine
    let deviantArtClient: DeviantArtServiceProtocol?
    let patreonClient: PatreonServiceProtocol?
}

@MainActor
struct LegacyContainerBridge {
    func register(_ snapshot: LegacyContainerSnapshot) async {
        await sharedContainer.register(DatabaseManager.self, instance: snapshot.databaseManager)
        await sharedContainer.register(AgentRepository.self, instance: snapshot.agentRepository)
        await sharedContainer.register(TaskRepository.self, instance: snapshot.taskRepository)
        await sharedContainer.register(TaskScheduleRepository.self, instance: snapshot.taskScheduleRepository)
        await sharedContainer.register(TaskRunRepository.self, instance: snapshot.taskRunRepository)
        await sharedContainer.register(GeneratedContentRepository.self, instance: snapshot.contentRepository)
        await sharedContainer.register(ApprovalQueueRepository.self, instance: snapshot.approvalRepository)
        await sharedContainer.register(PublicationTargetRepository.self, instance: snapshot.publicationRepository)
        await sharedContainer.register(RemotePostCacheRepository.self, instance: snapshot.cacheRepository)
        await sharedContainer.register(TaskTypeRepository.self, instance: snapshot.taskTypeRepository)
        await sharedContainer.register(SettingsService.self, instance: snapshot.settingsService)
        await sharedContainer.register(ContentVersioningService.self, instance: snapshot.versioningService)
        await sharedContainer.register(ApprovalService.self, instance: snapshot.approvalService)
        await sharedContainer.register(PublicationService.self, instance: snapshot.publicationService)
        await sharedContainer.register(CacheService.self, instance: snapshot.cacheService)
        await sharedContainer.register(WorkerProcessManager.self, instance: snapshot.workerManager)
        await sharedContainer.register(TaskExecutionPipeline.self, instance: snapshot.taskPipeline)
        await sharedContainer.register(SchedulerEngine.self, instance: snapshot.scheduler)

        if let deviantArtClient = snapshot.deviantArtClient {
            await sharedContainer.register(DeviantArtServiceProtocol.self, instance: deviantArtClient)
        }

        if let patreonClient = snapshot.patreonClient {
            await sharedContainer.register(PatreonServiceProtocol.self, instance: patreonClient)
        }
    }
}
