//
//  senor_platformApp.swift
//  senor-platform
//
//  Created by Fahad Faruqi on 4/7/26.
//

import SwiftUI
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
    
    init() {
        Task {
            await initializeApp()
        }
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
            let namingService = AgentNamingService(repository: container.resolveOrCrash(AgentRepository.self))
            container.register(AgentNamingService.self, instance: namingService)
            
            let versioningService = ContentVersioningService(
                contentRepository: container.resolveOrCrash(GeneratedContentRepository.self)
            )
            container.register(ContentVersioningService.self, instance: versioningService)
            
            let approvalService = ApprovalService(
                approvalRepository: container.resolveOrCrash(ApprovalQueueRepository.self),
                contentRepository: container.resolveOrCrash(GeneratedContentRepository.self),
                publicationTargetRepository: container.resolveOrCrash(PublicationTargetRepository.self)
            )
            container.register(ApprovalService.self, instance: approvalService)
            
            let settingsService = SettingsService()
            container.register(SettingsService.self, instance: settingsService)
            
            let cacheService = CacheService()
            container.register(CacheService.self, instance: cacheService)
            
            let publicationService = PublicationService(
                approvalQueueRepository: container.resolveOrCrash(ApprovalQueueRepository.self),
                contentRepository: container.resolveOrCrash(GeneratedContentRepository.self),
                publicationTargetRepository: container.resolveOrCrash(PublicationTargetRepository.self),
                remotePostCacheRepository: container.resolveOrCrash(RemotePostCacheRepository.self),
                settingsService: settingsService
            )
            container.register(PublicationService.self, instance: publicationService)
            
            // Register API clients if tokens available
            if settingsService.deviantArtAccessToken != nil {
                let deviantArtClient = DeviantArtClient(
                    clientId: "",
                    clientSecret: "",
                    redirectURI: "",
                    settingsService: settingsService
                )
                container.register(DeviantArtClient.self, instance: deviantArtClient)
            }
            
            if settingsService.patreonAccessToken != nil {
                let patreonClient = PatreonClient(
                    clientId: "",
                    clientSecret: "",
                    redirectURI: "",
                    settingsService: settingsService
                )
                container.register(PatreonClient.self, instance: patreonClient)
            }
            
            logger.info("Step 3 complete: Services registered")
            
            // 4. Register worker manager
            logger.info("Step 4: Starting worker manager...")
            let workerManager = try WorkerProcessManager()
            container.register(WorkerProcessManager.self, instance: workerManager)
            try await workerManager.startup()
            logger.info("Step 4 complete: Worker manager started")
            
            // 5. Create task execution pipeline
            logger.info("Step 5: Creating task execution pipeline...")
            let taskPipeline = TaskExecutionPipeline(
                taskRepository: container.resolveOrCrash(TaskRepository.self),
                taskRunRepository: container.resolveOrCrash(TaskRunRepository.self),
                contentRepository: container.resolveOrCrash(GeneratedContentRepository.self),
                approvalQueueRepository: container.resolveOrCrash(ApprovalQueueRepository.self),
                taskTypeRepository: container.resolveOrCrash(TaskTypeRepository.self),
                workerManager: workerManager,
                schemaValidator: TaskSchemaValidator()
            )
            container.register(TaskExecutionPipeline.self, instance: taskPipeline)
            logger.info("Step 5a: TaskExecutionPipeline created")

            // 6. Start scheduler engine
            logger.info("Step 6: Starting scheduler engine...")
            let schedulerEngine = SchedulerEngine(
                scheduleRepository: container.resolveOrCrash(TaskScheduleRepository.self),
                taskRepository: container.resolveOrCrash(TaskRepository.self),
                taskRunRepository: container.resolveOrCrash(TaskRunRepository.self),
                onTaskDue: { @Sendable (task: TaskRecord, schedule: TaskScheduleRecord) async -> Void in
                    await taskPipeline.execute(task: task, schedule: schedule)
                }
            )
            container.register(SchedulerEngine.self, instance: schedulerEngine)
            try await schedulerEngine.startup()
            logger.info("Step 6: SchedulerEngine startup complete")
            
            logger.info("Step 6: Setting isInitialized = true")
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
