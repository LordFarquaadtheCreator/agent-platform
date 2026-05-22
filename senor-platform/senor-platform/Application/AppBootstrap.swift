import Foundation

@MainActor
public final class AppBootstrap {
    private let logger = AppLogger.ui
    private let legacyContainerBridge = LegacyContainerBridge()

    public init() {}

    public func bootstrap() async throws -> AppDependencies {
        logger.info("Bootstrapping application dependencies")

        let dbManager = try await setupDatabase()
        let repos = createRepositories(dbManager: dbManager)
        let settings = SettingsService()
        let integrations = try await setupIntegrations(settingsService: settings)
        let services = createServices(repos: repos, settings: settings, integrations: integrations)
        let runtime = try await setupTaskRuntime(repos: repos, services: services)

        await registerWithLegacyBridge(repos: repos, services: services, runtime: runtime, integrations: integrations)

        // AI Chat dependencies - use configured base URL from settings
        let aiSettings = settings.loadAISettings()
        let aiBaseURL = aiSettings.baseURL.replacingOccurrences(of: "/v1", with: "")
        let aiClient = AIClient(baseURL: aiBaseURL)
        let contextExtractor = ContextExtractor()
        let chatHistoryStore = ChatHistoryStore(databaseManager: repos.dbManager)

        // Warm up AI model in background - don't block bootstrap
        Task { await warmupAI(aiClient: aiClient, services: services) }

        let connectivityService = ConnectivityService()

        return createDependencies(
            repos: repos,
            services: services,
            runtime: runtime,
            integrations: integrations,
            aiClient: aiClient,
            contextExtractor: contextExtractor,
            chatHistoryStore: chatHistoryStore,
            connectivityService: connectivityService
        )
    }

    private func setupDatabase() async throws -> DatabaseManager {
        let dbManager = try DatabaseManager()
        try await dbManager.startup()
        return dbManager
    }

    private struct Repositories {
        let dbManager: DatabaseManager
        let agent: AgentRepositoryImpl
        let task: TaskRepositoryImpl
        let schedule: TaskScheduleRepositoryImpl
        let run: TaskRunRepositoryImpl
        let content: GeneratedContentRepositoryImpl
        let approval: ApprovalQueueRepositoryImpl
        let publication: PublicationTargetRepositoryImpl
        let cache: RemotePostCacheRepositoryImpl
        let taskType: TaskTypeRepositoryImpl
        let comfyUIExecution: ComfyUIExecutionRepositoryImpl
    }

    private func createRepositories(dbManager: DatabaseManager) -> Repositories {
        Repositories(
            dbManager: dbManager,
            agent: AgentRepositoryImpl(dbManager: dbManager),
            task: TaskRepositoryImpl(dbManager: dbManager),
            schedule: TaskScheduleRepositoryImpl(dbManager: dbManager),
            run: TaskRunRepositoryImpl(dbManager: dbManager),
            content: GeneratedContentRepositoryImpl(dbManager: dbManager),
            approval: ApprovalQueueRepositoryImpl(dbManager: dbManager),
            publication: PublicationTargetRepositoryImpl(dbManager: dbManager),
            cache: RemotePostCacheRepositoryImpl(dbManager: dbManager),
            taskType: TaskTypeRepositoryImpl(dbManager: dbManager),
            comfyUIExecution: ComfyUIExecutionRepositoryImpl(dbManager: dbManager)
        )
    }

    private struct Services {
        let settings: SettingsService
        let cache: CacheService
        let versioning: ContentVersioningService
        let approval: ApprovalService
        let publication: PublicationService
    }

    private func createServices(repos: Repositories, settings: SettingsService, integrations: Integrations) -> Services {
        let cache = CacheService(cacheRepository: repos.cache)
        let versioning = ContentVersioningService(contentRepository: repos.content)
        let approval = ApprovalService(
            approvalRepository: repos.approval,
            contentRepository: repos.content,
            publicationTargetRepository: repos.publication
        )
        let publication = PublicationService(
            approvalQueueRepository: repos.approval,
            publicationRepository: repos.publication,
            contentRepository: repos.content,
            cacheService: cache,
            settingsService: settings,
            deviantArtClient: integrations.deviantArt,
            patreonClient: integrations.patreon
        )
        return Services(
            settings: settings, cache: cache, versioning: versioning,
            approval: approval, publication: publication
        )
    }

    private struct Integrations {
        var deviantArt: DeviantArtClient?
        var patreon: PatreonClient?
        var comfyUI: ComfyUIClient
    }

    private func setupIntegrations(settingsService: SettingsService) async throws -> Integrations {
        var integrations = Integrations(deviantArt: nil, patreon: nil, comfyUI: makeComfyUIClient(settingsService: settingsService))
        integrations.deviantArt = try await makeDeviantArtClient(settingsService: settingsService)
        integrations.patreon = await makePatreonClient(settingsService: settingsService)
        return integrations
    }

    private struct RuntimeComponents {
        let workerManager: WorkerProcessManager
        let taskPipeline: TaskExecutionPipeline
        let scheduler: SchedulerEngine
    }

    private func setupTaskRuntime(repos: Repositories, services: Services) async throws -> RuntimeComponents {
        let workerManager = try WorkerProcessManager()
        try await workerManager.startup()

        let taskPipeline = TaskExecutionPipeline(
            taskRepository: repos.task,
            taskScheduleRepository: repos.schedule,
            taskRunRepository: repos.run,
            contentRepository: repos.content,
            approvalQueueRepository: repos.approval,
            taskTypeRepository: repos.taskType,
            workerManager: workerManager,
            schemaValidator: TaskSchemaValidator()
        )

        let scheduler = SchedulerEngine(
            scheduleRepository: repos.schedule,
            taskRepository: repos.task,
            taskRunRepository: repos.run
        ) { task, schedule in
            await taskPipeline.execute(task: task, schedule: schedule)
        }
        try await scheduler.startup()

        return RuntimeComponents(
            workerManager: workerManager,
            taskPipeline: taskPipeline,
            scheduler: scheduler
        )
    }

    private func registerWithLegacyBridge(
        repos: Repositories,
        services: Services,
        runtime: RuntimeComponents,
        integrations: Integrations
    ) async {
        await legacyContainerBridge.register(
            LegacyContainerSnapshot(
                databaseManager: repos.dbManager,
                agentRepository: repos.agent,
                taskRepository: repos.task,
                taskScheduleRepository: repos.schedule,
                taskRunRepository: repos.run,
                contentRepository: repos.content,
                approvalRepository: repos.approval,
                publicationRepository: repos.publication,
                cacheRepository: repos.cache,
                taskTypeRepository: repos.taskType,
                settingsService: services.settings,
                versioningService: services.versioning,
                approvalService: services.approval,
                publicationService: services.publication,
                cacheService: services.cache,
                workerManager: runtime.workerManager,
                taskPipeline: runtime.taskPipeline,
                scheduler: runtime.scheduler,
                deviantArtClient: integrations.deviantArt,
                patreonClient: integrations.patreon
            )
        )
    }

    private func createDependencies(
        repos: Repositories,
        services: Services,
        runtime: RuntimeComponents,
        integrations: Integrations,
        aiClient: AIClient,
        contextExtractor: ContextExtractor,
        chatHistoryStore: ChatHistoryStore,
        connectivityService: ConnectivityService
    ) -> AppDependencies {
        let loadWorkspaceUseCase = LoadWorkspaceUseCase(
            agentRepository: repos.agent,
            taskRepository: repos.task,
            taskScheduleRepository: repos.schedule,
            taskRunRepository: repos.run,
            contentRepository: repos.content,
            approvalQueueRepository: repos.approval,
            publicationRepository: repos.publication
        )

        return AppDependencies(
            agentRepository: repos.agent,
            taskRepository: repos.task,
            taskScheduleRepository: repos.schedule,
            taskRunRepository: repos.run,
            contentRepository: repos.content,
            approvalRepository: repos.approval,
            publicationRepository: repos.publication,
            taskTypeRepository: repos.taskType,
            deviantArtClient: integrations.deviantArt,
            patreonClient: integrations.patreon,
            comfyUIClient: integrations.comfyUI,
            settingsService: services.settings,
            comfyUIExecutionRepository: repos.comfyUIExecution,
            approvalService: services.approval,
            versioningService: services.versioning,
            publicationService: services.publication,
            loadWorkspaceUseCase: loadWorkspaceUseCase,
            loadTaskCreationContextUseCase: LoadTaskCreationContextUseCase(
                agentRepository: repos.agent,
                taskTypeRepository: repos.taskType
            ),
            createAgentUseCase: CreateAgentUseCase(agentRepository: repos.agent),
            createTaskUseCase: CreateTaskUseCase(
                taskRepository: repos.task,
                scheduleRepository: repos.schedule,
                settingsService: services.settings
            ),
            approveContentUseCase: ApproveContentUseCase(approvalService: services.approval),
            rejectContentUseCase: RejectContentUseCase(approvalService: services.approval),
            publishContentUseCase: PublishContentUseCase(
                publicationService: services.publication,
                settingsService: services.settings
            ),
            editContentUseCase: EditContentUseCase(versioningService: services.versioning),
            loadContentEditorUseCase: LoadContentEditorUseCase(
                contentRepository: repos.content,
                versioningService: services.versioning
            ),
            aiClient: aiClient,
            contextExtractor: contextExtractor,
            chatHistoryStore: chatHistoryStore,
            connectivityService: connectivityService,
            databaseManager: repos.dbManager
        )
    }

    private func makeDeviantArtClient(settingsService: SettingsService) async throws -> DeviantArtClient? {
        let settings = settingsService.loadDeviantArtSettings()
        guard !settings.clientId.isEmpty, !settings.clientSecret.isEmpty else {
            return nil
        }

        let config = DeviantArtClient.Configuration(
            clientId: settings.clientId,
            clientSecret: settings.clientSecret,
            redirectURI: settings.redirectURI
        )
        guard let deviantArtURL = URL(string: "https://www.deviantart.com") else {
            fatalError("Invalid DeviantArt base URL")
        }
        let httpClient = HTTPClient(
            configuration: HTTPClient.Configuration(baseURL: deviantArtURL)
        )
        let client = try await DeviantArtClient(configuration: config, httpClient: httpClient)
        if let accessToken = settings.accessToken {
            let token = HTTPClient.AuthToken(
                accessToken: accessToken,
                refreshToken: settings.refreshToken,
                expiresAt: settings.tokenExpiry,
                tokenType: "Bearer"
            )
            client.setAuthToken(token)
        }
        return client
    }

    private func makeComfyUIClient(settingsService: SettingsService) -> ComfyUIClient {
        let settings = settingsService.loadComfyUISettings()
        let url = settings.serverURL.isEmpty || settings.serverURL.hasSuffix(":8188")
            ? nil
            : settings.serverURL
        return ComfyUIClient(baseURL: url ?? "http://127.0.0.1:8000")
    }

    private func makePatreonClient(settingsService: SettingsService) async -> PatreonClient? {
        let settings = settingsService.loadPatreonSettings()
        guard !settings.accessToken.isEmpty else {
            return nil
        }

        let config = PatreonClient.Configuration(
            clientId: settings.campaignId ?? "patreon-app",
            clientSecret: "",
            redirectURI: "senorplatform://oauth/patreon"
        )
        guard let patreonURL = URL(string: "https://www.patreon.com") else {
            fatalError("Invalid Patreon base URL")
        }
        let httpClient = HTTPClient(
            configuration: HTTPClient.Configuration(baseURL: patreonURL)
        )
        let client = await PatreonClient(configuration: config, httpClient: httpClient)
        if !settings.accessToken.isEmpty {
            let token = HTTPClient.AuthToken(
                accessToken: settings.accessToken,
                refreshToken: settings.refreshToken,
                expiresAt: settings.tokenExpiry,
                tokenType: "Bearer"
            )
            client.setAuthToken(token)
        }
        return client
    }

    private func warmupAI(aiClient: AIClient, services: Services) async {
        let warmupService = AIWarmupService(
            aiClient: aiClient,
            settingsService: services.settings
        )
        await warmupService.warmupIfNeeded()
    }
}
