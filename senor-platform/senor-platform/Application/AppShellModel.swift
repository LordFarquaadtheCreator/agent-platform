import Foundation
import Combine

@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public private(set) var snapshot = DashboardSnapshot(
        activeAgentCount: 0,
        pendingApprovalCount: 0,
        scheduledTaskCount: 0,
        publishedContentCount: 0,
        recentContent: []
    )

    func apply(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class AgentsViewModel: ObservableObject {
    @Published public private(set) var agents: [Agent] = []

    private let createAgentUseCase: CreateAgentUseCase
    private let refresh: @MainActor () async -> Void

    init(createAgentUseCase: CreateAgentUseCase, refresh: @escaping @MainActor () async -> Void) {
        self.createAgentUseCase = createAgentUseCase
        self.refresh = refresh
    }

    func apply(_ agents: [Agent]) {
        self.agents = agents
    }

    func create(draft: AgentDraft) async throws {
        _ = try await createAgentUseCase.execute(draft)
        await refresh()
    }
}

@MainActor
public final class TasksViewModel: ObservableObject {
    @Published public private(set) var tasks: [TaskSummary] = []
    @Published public private(set) var creationContext = TaskCreationContext(agents: [], taskTypes: [])

    private let loadContextUseCase: LoadTaskCreationContextUseCase
    private let createTaskUseCase: CreateTaskUseCase
    private let refresh: @MainActor () async -> Void

    init(
        loadContextUseCase: LoadTaskCreationContextUseCase,
        createTaskUseCase: CreateTaskUseCase,
        refresh: @escaping @MainActor () async -> Void
    ) {
        self.loadContextUseCase = loadContextUseCase
        self.createTaskUseCase = createTaskUseCase
        self.refresh = refresh
    }

    func apply(_ tasks: [TaskSummary]) {
        self.tasks = tasks
    }

    func loadCreationContext() async throws {
        creationContext = try await loadContextUseCase.execute()
    }

    func create(draft: TaskDraft) async throws {
        _ = try await createTaskUseCase.execute(draft)
        await refresh()
    }
}

@MainActor
public final class ContentViewModel: ObservableObject {
    @Published public private(set) var contentItems: [ContentSummary] = []

    private let loadEditorUseCase: LoadContentEditorUseCase
    private let editContentUseCase: EditContentUseCase
    private let refresh: @MainActor () async -> Void

    init(
        loadEditorUseCase: LoadContentEditorUseCase,
        editContentUseCase: EditContentUseCase,
        refresh: @escaping @MainActor () async -> Void
    ) {
        self.loadEditorUseCase = loadEditorUseCase
        self.editContentUseCase = editContentUseCase
        self.refresh = refresh
    }

    func apply(_ items: [ContentSummary]) {
        self.contentItems = items
    }

    func loadEditorJSON(contentId: String) async throws -> String {
        try await loadEditorUseCase.loadCurrentJSON(contentId: contentId)
    }

    func loadHistory(contentId: String) async throws -> [VersionInfo] {
        try await loadEditorUseCase.loadHistory(contentId: contentId)
    }

    func save(_ request: ContentEditRequest) async throws {
        try await editContentUseCase.execute(request)
        await refresh()
    }

    func restore(contentId: String, version: Int, changeReason: String?) async throws {
        try await loadEditorUseCase.restore(contentId: contentId, version: version, changeReason: changeReason)
        await refresh()
    }
}

@MainActor
public final class ApprovalsViewModel: ObservableObject {
    @Published public private(set) var approvals: [ApprovalSummary] = []

    private let approveContentUseCase: ApproveContentUseCase
    private let rejectContentUseCase: RejectContentUseCase
    private let publishContentUseCase: PublishContentUseCase
    private let refresh: @MainActor () async -> Void

    init(
        approveContentUseCase: ApproveContentUseCase,
        rejectContentUseCase: RejectContentUseCase,
        publishContentUseCase: PublishContentUseCase,
        refresh: @escaping @MainActor () async -> Void
    ) {
        self.approveContentUseCase = approveContentUseCase
        self.rejectContentUseCase = rejectContentUseCase
        self.publishContentUseCase = publishContentUseCase
        self.refresh = refresh
    }

    func apply(_ approvals: [ApprovalSummary]) {
        self.approvals = approvals
    }

    func approve(contentId: String) async throws {
        try await approveContentUseCase.execute(contentId: contentId)
        await refresh()
    }

    func reject(contentId: String, reason: String?) async throws {
        try await rejectContentUseCase.execute(contentId: contentId, reason: reason)
        await refresh()
    }

    func publish(_ request: PublicationRequest) async throws {
        try await publishContentUseCase.execute(request)
        await refresh()
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var generalSettings: SettingsService.GeneralSettings
    @Published public var deviantArtSettings: SettingsService.DeviantArtSettings
    @Published public var patreonSettings: SettingsService.PatreonSettings
    @Published public var comfyUISettings: SettingsService.ComfyUISettings
    @Published public var taskScriptPath: String

    private let settingsService: SettingsService

    init(settingsService: SettingsService) {
        self.settingsService = settingsService
        self.generalSettings = settingsService.loadGeneralSettings()
        self.deviantArtSettings = settingsService.loadDeviantArtSettings()
        self.patreonSettings = settingsService.loadPatreonSettings()
        self.comfyUISettings = settingsService.loadComfyUISettings()
        self.taskScriptPath = settingsService.taskScriptPath()
    }

    func reload() {
        generalSettings = settingsService.loadGeneralSettings()
        deviantArtSettings = settingsService.loadDeviantArtSettings()
        patreonSettings = settingsService.loadPatreonSettings()
        comfyUISettings = settingsService.loadComfyUISettings()
        taskScriptPath = settingsService.taskScriptPath()
    }

    func saveGeneral() {
        settingsService.saveGeneralSettings(generalSettings)
    }

    func saveComfyUI() {
        settingsService.saveComfyUISettings(comfyUISettings)
    }

    func saveTaskScriptPath() {
        settingsService.setTaskScriptPath(taskScriptPath)
    }

    func saveDeviantArt() throws {
        try settingsService.saveDeviantArtSettings(deviantArtSettings)
    }

    func savePatreon() throws {
        try settingsService.savePatreonSettings(patreonSettings)
    }

    func clearAll() async throws {
        try await settingsService.clearAllSettings()
        reload()
    }
}

import Combine

@MainActor
public final class WorkspaceModel: ObservableObject {
    public let dependencies: AppDependencies
    public let router = AppRouter()
    public let dashboardViewModel = DashboardViewModel()
    
    private var cancellables = Set<AnyCancellable>()
    public let settingsViewModel: SettingsViewModel
    public lazy var deviantArtViewModel = DeviantArtViewModel(client: dependencies.deviantArtClient, settingsService: dependencies.settingsService)
    public lazy var patreonViewModel = PatreonViewModel(
        client: dependencies.patreonClient,
        settings: dependencies.settingsService.loadPatreonSettings()
    )
    public lazy var agentsViewModel = AgentsViewModel(
        createAgentUseCase: dependencies.createAgentUseCase
    ) { [weak self] in
        await self?.refreshAll()
    }
    public lazy var tasksViewModel = TasksViewModel(
        loadContextUseCase: dependencies.loadTaskCreationContextUseCase,
        createTaskUseCase: dependencies.createTaskUseCase
    ) { [weak self] in
        await self?.refreshAll()
    }
    public lazy var contentViewModel = ContentViewModel(
        loadEditorUseCase: dependencies.loadContentEditorUseCase,
        editContentUseCase: dependencies.editContentUseCase
    ) { [weak self] in
        await self?.refreshAll()
    }
    public lazy var approvalsViewModel = ApprovalsViewModel(
        approveContentUseCase: dependencies.approveContentUseCase,
        rejectContentUseCase: dependencies.rejectContentUseCase,
        publishContentUseCase: dependencies.publishContentUseCase
    ) { [weak self] in
        await self?.refreshAll()
    }

    @Published public private(set) var isRefreshing = false
    @Published public var lastErrorMessage: String?

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.settingsViewModel = SettingsViewModel(settingsService: dependencies.settingsService)
        
        // Forward router changes to workspace observers
        router.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let snapshot = try await dependencies.loadWorkspaceUseCase.execute()
            dashboardViewModel.apply(snapshot.dashboard)
            agentsViewModel.apply(snapshot.agents)
            tasksViewModel.apply(snapshot.tasks)
            contentViewModel.apply(snapshot.content)
            approvalsViewModel.apply(snapshot.approvals)
            settingsViewModel.reload()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

@MainActor
public final class AppShellModel: ObservableObject {
    @Published public private(set) var workspace: WorkspaceModel?
    @Published public var activeSheet: AppSheet?
    @Published public var errorMessage: String?
    @Published public var toastMessage: String?
    @Published public private(set) var isInitializing = true

    private let bootstrap: AppBootstrap
    private let logger = AppLogger.ui

    public init(bootstrap: AppBootstrap? = nil) {
        self.bootstrap = bootstrap ?? AppBootstrap()
        Task { await initialize() }
    }

    public func initialize() async {
        isInitializing = true
        do {
            let dependencies = try await bootstrap.bootstrap()
            let workspace = WorkspaceModel(dependencies: dependencies)
            self.workspace = workspace
            await workspace.refreshAll()
            isInitializing = false
        } catch {
            logger.error("Failed to initialize shell: \(error)")
            errorMessage = error.localizedDescription
            isInitializing = false
        }
    }

    public func refreshAll() async {
        await workspace?.refreshAll()
        if let message = workspace?.lastErrorMessage {
            errorMessage = message
        }
    }

    public func present(_ sheet: AppSheet) {
        activeSheet = sheet
    }

    public func dismissSheet() {
        activeSheet = nil
    }

    public func showToast(_ message: String) {
        toastMessage = message
    }
}

public typealias AppState = AppShellModel

// MARK: - Previews

extension ApprovalsViewModel {
    static var preview: ApprovalsViewModel {
        ApprovalsViewModel(
            approveContentUseCase: PreviewApproveContentUseCase(),
            rejectContentUseCase: PreviewRejectContentUseCase(),
            publishContentUseCase: PreviewPublishContentUseCase(),
            refresh: {}
        )
    }
}

// Preview use cases that do nothing but satisfy protocol requirements
struct PreviewApproveContentUseCase: ApproveContentUseCaseProtocol {
    func execute(contentId: String) async throws {}
}

struct PreviewRejectContentUseCase: RejectContentUseCaseProtocol {
    func execute(contentId: String, reason: String?) async throws {}
}

struct PreviewPublishContentUseCase: PublishContentUseCaseProtocol {
    func execute(_ request: PublicationRequest) async throws {}
}
