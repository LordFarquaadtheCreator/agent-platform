//
//  senor_platformApp.swift
//  senor-platform
//
//  Created by Fahad Faruqi on 4/7/26.
//

import SwiftUI
import GRDB
import Combine

@main
struct senor_platformApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Agents") {
                Button("New Agent") {
                    appState.showNewAgentSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Refresh") {
                    Task {
                        await appState.refreshAll()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            
            CommandMenu("Tasks") {
                Button("New Task") {
                    appState.showNewTaskSheet = true
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var selectedAgent: AgentViewModel?
    @Published var selectedContent: ContentItemViewModel?
    @Published var selectedView: MainView = .dashboard
    @Published var showNewAgentSheet = false
    @Published var showNewTaskSheet = false
    @Published var showSettingsSheet = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isInitialized = false
    
    private let container = sharedContainer
    private let logger = AppLogger.ui
    private var initializationTask: Task<Void, Never>?
    
    init() {
        // Start initialization but don't await - UI will show loading state
        initializationTask = Task {
            await initializeApp()
        }
    }
    
    /// Wait for initialization to complete (for testing or synchronous requirements)
    func awaitInitialization() async {
        await initializationTask?.value
    }
    
    private func initializeApp() async {
        do {
            logger.info("=== Starting app initialization ===")
            
            // 1. Initialize database
            logger.info("Step 1: Initializing database...")
            let dbManager = try DatabaseManager()
            container.register(DatabaseManager.self, instance: dbManager)
            logger.info("Step 1a: DatabaseManager created, running startup...")
            try await dbManager.startup()
            logger.info("Step 1b: Database startup complete")
            
            // 2. Register repositories
            logger.info("Step 2: Registering repositories...")
            container.register(AgentRepository.self, instance: AgentRepositoryImpl(dbManager: dbManager))
            container.register(TaskRepository.self, instance: TaskRepositoryImpl(dbManager: dbManager))
            container.register(TaskScheduleRepository.self, instance: TaskScheduleRepositoryImpl(dbManager: dbManager))
            container.register(TaskRunRepository.self, instance: TaskRunRepositoryImpl(dbManager: dbManager))
            container.register(GeneratedContentRepository.self, instance: GeneratedContentRepositoryImpl(dbManager: dbManager))
            container.register(ApprovalQueueRepository.self, instance: ApprovalQueueRepositoryImpl(dbManager: dbManager))
            container.register(PublicationTargetRepository.self, instance: PublicationTargetRepositoryImpl(dbManager: dbManager))
            container.register(RemotePostCacheRepository.self, instance: RemotePostCacheRepositoryImpl(dbManager: dbManager))
            container.register(TaskTypeRepository.self, instance: TaskTypeRepositoryImpl(dbManager: dbManager))
            logger.info("Step 2 complete: Repositories registered")
            
            // 3. Register services
            logger.info("Step 3: Registering services...")
            let agentRepo: AgentRepository = try await container.resolve(AgentRepository.self)
            let namingService = AgentNamingService(repository: agentRepo)
            await container.register(AgentNamingService.self, instance: namingService)
            
            let contentRepo: GeneratedContentRepository = try await container.resolve(GeneratedContentRepository.self)
            let versioningService = ContentVersioningService(contentRepository: contentRepo)
            await container.register(ContentVersioningService.self, instance: versioningService)
            
            let approvalQueueRepo: ApprovalQueueRepository = try await container.resolve(ApprovalQueueRepository.self)
            let pubTargetRepo: PublicationTargetRepository = try await container.resolve(PublicationTargetRepository.self)
            let approvalService = ApprovalService(
                approvalRepository: approvalQueueRepo,
                contentRepository: contentRepo,
                publicationTargetRepository: pubTargetRepo
            )
            await container.register(ApprovalService.self, instance: approvalService)
            
            let settingsService = SettingsService()
            await container.register(SettingsService.self, instance: settingsService)
            
            await container.register(CacheService.self) {
                let cacheRepo = try await container.resolve(RemotePostCacheRepository.self)
                return CacheService(cacheRepository: cacheRepo)
            }
            
            let cacheRepo: RemotePostCacheRepository = try await container.resolve(RemotePostCacheRepository.self)
            let publicationService = PublicationService(
                approvalQueueRepository: approvalQueueRepo,
                contentRepository: contentRepo,
                publicationTargetRepository: pubTargetRepo,
                remotePostCacheRepository: cacheRepo,
                settingsService: settingsService
            )
            await container.register(PublicationService.self, instance: publicationService)
            
            // Register API clients lazily - they'll be configured when credentials are available
            await container.register(DeviantArtClient.self) {
                let daSettings = settingsService.loadDeviantArtSettings()
                guard !daSettings.clientId.isEmpty, !daSettings.clientSecret.isEmpty else {
                    throw DependencyContainerError.serviceNotRegistered("DeviantArtClient - missing credentials")
                }
                let config = DeviantArtClient.Configuration(
                    clientId: daSettings.clientId,
                    clientSecret: daSettings.clientSecret,
                    redirectURI: "senorplatform://oauth/deviantart"
                )
                let httpClient = HTTPClient(configuration: HTTPClient.Configuration(baseURL: URL(string: "https://www.deviantart.com")!))
                return try await DeviantArtClient(configuration: config, httpClient: httpClient)
            }
            
            await container.register(PatreonClient.self) {
                let patSettings = settingsService.loadPatreonSettings()
                guard !patSettings.accessToken.isEmpty else {
                    throw DependencyContainerError.serviceNotRegistered("PatreonClient - missing credentials")
                }
                // For Patreon, we use the campaign ID as a pseudo clientId for now
                let config = PatreonClient.Configuration(
                    clientId: patSettings.campaignId ?? "patreon-app",
                    clientSecret: "", // Patreon uses creator access token instead
                    redirectURI: "senorplatform://oauth/patreon"
                )
                let httpClient = HTTPClient(configuration: HTTPClient.Configuration(baseURL: URL(string: "https://www.patreon.com")!))
                return await PatreonClient(configuration: config, httpClient: httpClient)
            }
            
            logger.info("Step 3 complete: Services registered")
            
            // 4. Register worker manager
            logger.info("Step 4: Starting worker manager...")
            let workerManager = try WorkerProcessManager()
            await container.register(WorkerProcessManager.self, instance: workerManager)
            try await workerManager.startup()
            logger.info("Step 4 complete: Worker manager started")
            
            // 5. Create task execution pipeline
            logger.info("Step 5: Creating task execution pipeline...")
            let taskRepo: TaskRepository = try await container.resolve(TaskRepository.self)
            let taskRunRepo: TaskRunRepository = try await container.resolve(TaskRunRepository.self)
            let taskTypeRepo: TaskTypeRepository = try await container.resolve(TaskTypeRepository.self)
            let scheduleRepo: TaskScheduleRepository = try await container.resolve(TaskScheduleRepository.self)
            let taskPipeline = TaskExecutionPipeline(
                taskRepository: taskRepo,
                taskScheduleRepository: scheduleRepo,
                taskRunRepository: taskRunRepo,
                contentRepository: contentRepo,
                approvalQueueRepository: approvalQueueRepo,
                taskTypeRepository: taskTypeRepo,
                workerManager: workerManager,
                schemaValidator: TaskSchemaValidator()
            )
            await container.register(TaskExecutionPipeline.self, instance: taskPipeline)
            logger.info("Step 5a: TaskExecutionPipeline created")
            
            // 6. Register scheduler engine
            logger.info("Step 6: Starting scheduler engine...")
            let schedulerEngine = SchedulerEngine(
                scheduleRepository: scheduleRepo,
                taskRepository: taskRepo,
                taskRunRepository: taskRunRepo
            ) { task, schedule in
                // Task due callback - execute via pipeline
                Task {
                    await pipeline.execute(task: task, schedule: schedule)
                }
            }
            await container.register(SchedulerEngine.self, instance: schedulerEngine)
            try await schedulerEngine.startup()
            
            await MainActor.run {
                self.isInitialized = true
            }
            logger.info("=== App initialization complete ===")
            
        } catch {
            logger.error("App initialization failed: \(error)")
            showError("Failed to initialize app: \(error.localizedDescription)")
        }
    }
    
    func refreshAll() {
        // Trigger refresh through EventBus
        EventBus.shared.refreshAllData()
    }
    
    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

enum MainView: String, CaseIterable {
    case dashboard = "Dashboard"
    case agents = "Agents"
    case tasks = "Tasks"
    case content = "Content"
    case approvals = "Approvals"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .agents: return "cpu"
        case .tasks: return "list.bullet.rectangle"
        case .content: return "doc.text.image"
        case .approvals: return "checkmark.shield"
        case .settings: return "gear"
        }
    }
}
