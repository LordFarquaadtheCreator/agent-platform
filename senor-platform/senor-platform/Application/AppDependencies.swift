import Foundation

@MainActor
public struct AppDependencies {
    public let agentRepository: AgentRepository
    public let taskRepository: TaskRepository
    public let taskScheduleRepository: TaskScheduleRepository
    public let taskRunRepository: TaskRunRepository
    public let contentRepository: GeneratedContentRepository
    public let approvalRepository: ApprovalQueueRepository
    public let publicationRepository: PublicationTargetRepository
    public let taskTypeRepository: TaskTypeRepository

    public let deviantArtClient: DeviantArtClient?
    public let patreonClient: PatreonClient?

    public let settingsService: SettingsService
    public let approvalService: ApprovalService
    public let versioningService: ContentVersioningService
    public let publicationService: PublicationService

    public let loadWorkspaceUseCase: LoadWorkspaceUseCase
    public let loadTaskCreationContextUseCase: LoadTaskCreationContextUseCase
    public let createAgentUseCase: CreateAgentUseCase
    public let createTaskUseCase: CreateTaskUseCase
    public let approveContentUseCase: ApproveContentUseCase
    public let rejectContentUseCase: RejectContentUseCase
    public let publishContentUseCase: PublishContentUseCase
    public let editContentUseCase: EditContentUseCase
    public let loadContentEditorUseCase: LoadContentEditorUseCase

    // AI Chat dependencies
    public let aiClient: AIClient
    public let contextExtractor: ContextExtractor
    public let chatHistoryStore: ChatHistoryStore

    // Connectivity
    public let connectivityService: ConnectivityService
}
