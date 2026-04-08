//
//  ContentView.swift
//  senor-platform
//
//  Created by Fahad Faruqi on 4/7/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var viewModel: ContentViewModel?
    
    var body: some View {
        Group {
            if appState.isInitialized, let vm = viewModel {
                mainContent(viewModel: vm)
            } else {
                loadingView
            }
        }
        .onChange(of: appState.isInitialized) { initialized in
            if initialized && viewModel == nil {
                viewModel = ContentViewModel()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Initializing...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func mainContent(viewModel: ContentViewModel) -> some View {
        NavigationSplitView {
            // Sidebar - Agent/Navigation List
            SidebarView(viewModel: viewModel)
                .frame(minWidth: 220, idealWidth: 250)
        } content: {
            // Content Area - Main View
            MainContentView(viewModel: viewModel)
                .frame(minWidth: 600)
        } detail: {
            // Inspector Panel - Contextual Details
            InspectorView(viewModel: viewModel)
                .frame(minWidth: 280, idealWidth: 320)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $appState.showNewAgentSheet) {
            NewAgentView()
                .frame(width: 500, height: 400)
        }
        .sheet(isPresented: $appState.showNewTaskSheet) {
            NewTaskView()
                .frame(width: 600, height: 500)
        }
        .sheet(isPresented: $appState.showSettingsSheet) {
            SettingsView()
                .frame(width: 700, height: 500)
        }
        .alert("Error", isPresented: $appState.showError, presenting: appState.errorMessage) { _ in
            Button("OK") {}
        } message: { error in
            Text(error)
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
}

@MainActor
class ContentViewModel: ObservableObject {
    @Published var selectedMainView: MainView = .dashboard
    @Published var selectedAgentId: String?
    @Published var selectedTaskId: String?
    @Published var selectedContentId: String?
    @Published var agents: [AgentViewModel] = []
    @Published var tasks: [TaskViewModel] = []
    @Published var contentItems: [ContentItemViewModel] = []
    @Published var pendingApprovals: [ApprovalViewModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Repositories
    private let agentRepository: AgentRepository
    private let taskRepository: TaskRepository
    private let taskScheduleRepository: TaskScheduleRepository
    private let taskRunRepository: TaskRunRepository
    private let contentRepository: GeneratedContentRepository
    private let approvalRepository: ApprovalQueueRepository
    private let publicationRepository: PublicationTargetRepository
    private let namingService: AgentNamingService
    private let logger = AppLogger.ui
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Resolve dependencies from container
        let container = sharedContainer
        self.agentRepository = container.resolveOrCrash(AgentRepository.self)
        self.taskRepository = container.resolveOrCrash(TaskRepository.self)
        self.taskScheduleRepository = container.resolveOrCrash(TaskScheduleRepository.self)
        self.taskRunRepository = container.resolveOrCrash(TaskRunRepository.self)
        self.contentRepository = container.resolveOrCrash(GeneratedContentRepository.self)
        self.approvalRepository = container.resolveOrCrash(ApprovalQueueRepository.self)
        self.publicationRepository = container.resolveOrCrash(PublicationTargetRepository.self)
        self.namingService = container.resolveOrCrash(AgentNamingService.self)
        
        // Subscribe to EventBus events
        setupEventBusSubscriptions()
    }
    
    private func setupEventBusSubscriptions() {
        // Listen for refresh events
        EventBus.shared.onRefresh { [weak self] event in
            Task { @MainActor in
                await self?.refreshData()
            }
        }
        .store(in: &cancellables)
        
        // Listen for agent creation requests
        EventBus.shared.onAction { [weak self] action in
            if case .createAgent(let categoryString) = action {
                Task { @MainActor in
                    do {
                        // Convert string category to enum
                        let category: NameCategory? = categoryString.flatMap {
                            NameCategory(rawValue: $0)
                        }
                        _ = try await self?.createAgent(category: category)
                    } catch {
                        self?.logger.error("Failed to create agent: \(error)")
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .store(in: &cancellables)
    }
    
    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }
        
        await refreshData()
    }
    
    
    private func refreshData() async {
        do {
            async let agentsTask = loadAgents()
            async let tasksTask = loadTasks()
            async let contentTask = loadContent()
            async let approvalsTask = loadApprovals()
            
            _ = try await (agentsTask, tasksTask, contentTask, approvalsTask)
            logger.info("Data refresh complete")
        } catch {
            logger.error("Failed to refresh data: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Data Loading
    
    private func loadAgents() async throws {
        let records = try await agentRepository.listAll()
        
        let viewModels = try await withThrowingTaskGroup(of: AgentViewModel.self) { group in
            for record in records {
                group.addTask {
                    let taskCount = try await self.taskRepository.listByAgent(agentId: record.id).count
                    
                    // Map AgentRuntimeStatus to AgentViewModel.AgentStatus
                    let agentStatus: AgentViewModel.AgentStatus = {
                        switch record.status {
                        case .idle: return .idle
                        case .running: return .running
                        case .paused: return .idle // Paused maps to idle for UI
                        case .error: return .error
                        }
                    }()
                    
                    return AgentViewModel(
                        id: record.id,
                        name: record.displayName,
                        status: agentStatus,
                        lastActivity: record.updatedAt,
                        taskCount: taskCount
                    )
                }
            }
            
            var results: [AgentViewModel] = []
            for try await vm in group {
                results.append(vm)
            }
            return results.sorted { $0.name < $1.name }
        }
        
        await MainActor.run {
            self.agents = viewModels
        }
    }
    
    private func loadTasks() async throws {
        let records = try await taskRepository.listEnabled()
        
        let viewModels = try await withThrowingTaskGroup(of: TaskViewModel.self) { group in
            for record in records {
                group.addTask {
                    let schedule = try await self.taskScheduleRepository.getByTask(taskId: record.id)
                    let lastRun = try await self.taskRunRepository.listByTask(taskId: record.id, limit: 1).first
                    
                    return TaskViewModel(
                        id: record.id,
                        name: record.taskName,
                        schedule: schedule?.scheduleKind == "recurring" ? "Recurring" : (schedule?.scheduleKind == "one_time" ? "One-time" : "No schedule"),
                        lastRun: lastRun?.completedAt,
                        nextRun: schedule?.nextRunAt,
                        isEnabled: record.isEnabled
                    )
                }
            }
            
            var results: [TaskViewModel] = []
            for try await vm in group {
                results.append(vm)
            }
            return results.sorted { $0.name < $1.name }
        }
        
        await MainActor.run {
            self.tasks = viewModels
        }
    }
    
    private func loadContent() async throws {
        let records = try await contentRepository.listRecent(limit: 100)
        
        let viewModels = records.map { record -> ContentItemViewModel in
            ContentItemViewModel(
                id: record.id,
                title: record.title,
                previewImage: nil, // TODO: Extract from JSON if available
                createdAt: record.createdAt,
                status: self.contentStatus(for: record.id),
                version: record.currentVersion
            )
        }
        
        await MainActor.run {
            self.contentItems = viewModels
        }
    }
    
    private func loadApprovals() async throws {
        let pendingRecords = try await approvalRepository.listPending(limit: 50)
        
        let viewModels = try await withThrowingTaskGroup(of: ApprovalViewModel?.self) { group in
            for record in pendingRecords {
                group.addTask {
                    guard let content = try await self.contentRepository.getById(id: record.generatedContentId) else {
                        return nil
                    }
                    guard let agent = try await self.agentRepository.getById(id: content.agentId) else {
                        return nil
                    }
                    
                    return ApprovalViewModel(
                        id: record.id,
                        contentId: content.id,
                        contentTitle: content.title,
                        previewImage: nil,
                        submittedAt: record.createdAt,
                        agentName: agent.displayName
                    )
                }
            }
            
            var results: [ApprovalViewModel] = []
            for try await vm in group {
                if let vm = vm {
                    results.append(vm)
                }
            }
            return results.sorted { $0.submittedAt > $1.submittedAt }
        }
        
        await MainActor.run {
            self.pendingApprovals = viewModels
        }
    }
    
    private func contentStatus(for contentId: String) -> ContentItemViewModel.ContentStatus {
        // This is synchronous - could be improved
        // For now, just return pending; async status check would need to be handled differently
        // TODO: Make this async and properly check publication status
        return ContentItemViewModel.ContentStatus.pending
    }
    
    // MARK: - Actions
    
    func createAgent(category: NameCategory? = nil) async throws -> AgentRecord {
        let generatedName: AgentNamingService.GeneratedName
        if let category = category {
            // Generate from specific category
            var attempts = 0
            var name: AgentNamingService.GeneratedName?
            while attempts < 100 && name == nil {
                let baseName = namingService.names(from: category).randomElement() ?? "Agent"
                let seed = Int.random(in: 1...99)
                let displayName = "\(baseName)-\(String(format: "%02d", seed))"
                
                let exists = try await agentRepository.existsWithName(name: displayName)
                if !exists {
                    name = AgentNamingService.GeneratedName(
                        displayName: displayName,
                        category: category,
                        baseName: baseName,
                        seed: seed
                    )
                }
                attempts += 1
            }
            if let name = name {
                generatedName = name
            } else {
                generatedName = try await namingService.generateUniqueName()
            }
        } else {
            generatedName = try await namingService.generateUniqueName()
        }
        
        let agent = AgentRecord(
            displayName: generatedName.displayName,
            status: AgentRuntimeStatus.idle,
            nameSource: generatedName.category.rawValue,
            nameSeed: generatedName.seed
        )
        
        let saved = try await agentRepository.create(agent: agent)
        logger.info("Created agent: \(saved.displayName)")
        
        await refreshData()
        return saved
    }
    
    func deleteAgent(id: String) async throws {
        try await agentRepository.delete(id: id)
        logger.info("Deleted agent: \(id)")
        await refreshData()
    }
    
    func approveContent(id: String) async throws {
        guard let approval = try await approvalRepository.getByContent(contentId: id) else {
            throw AppError.approvalStateInvalid("No approval entry found for content")
        }
        
        var updated = approval
        updated.approvalStatus = "approved"
        updated.approvedAt = Date()
        updated.approvedBy = "user" // TODO: Get actual user
        
        _ = try await approvalRepository.update(entry: updated)
        logger.info("Approved content: \(id)")
        
        await refreshData()
    }
    
    func rejectContent(id: String, reason: String? = nil) async throws {
        guard let approval = try await approvalRepository.getByContent(contentId: id) else {
            throw AppError.approvalStateInvalid("No approval entry found for content")
        }
        
        var updated = approval
        updated.approvalStatus = "rejected"
        updated.rejectedAt = Date()
        updated.rejectionReason = reason
        
        _ = try await approvalRepository.update(entry: updated)
        logger.info("Rejected content: \(id)")
        
        await refreshData()
    }
    
    func batchApprove(ids: [String]) async throws {
        for id in ids {
            try await approveContent(id: id)
        }
    }
    
    func batchReject(ids: [String], reason: String? = nil) async throws {
        for id in ids {
            try await rejectContent(id: id, reason: reason)
        }
    }
    
    // MARK: - Computed Properties
    
    var selectedAgent: AgentViewModel? {
        agents.first { $0.id == selectedAgentId }
    }
    
    var selectedContentItem: ContentItemViewModel? {
        contentItems.first { $0.id == selectedContentId }
    }
}

// MARK: - Helper Extensions

extension AgentViewModel.AgentStatus {
    init(from status: String) {
        switch status.lowercased() {
        case "running": self = .running
        case "error", "failed": self = .error
        case "disabled", "offline": self = .offline
        default: self = .idle
        }
    }
}

// View model structs for UI
struct AgentViewModel: Identifiable {
    let id: String
    let name: String
    let status: AgentStatus
    let lastActivity: Date?
    let taskCount: Int
    
    enum AgentStatus: String {
        case idle = "Idle"
        case running = "Running"
        case error = "Error"
        case offline = "Offline"
        
        var color: Color {
            switch self {
            case .idle: return .green
            case .running: return .blue
            case .error: return .red
            case .offline: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return "checkmark.circle.fill"
            case .running: return "arrow.triangle.2.circlepath"
            case .error: return "exclamationmark.triangle.fill"
            case .offline: return "moon.fill"
            }
        }
    }
}

struct TaskViewModel: Identifiable {
    let id: String
    let name: String
    let schedule: String
    let lastRun: Date?
    let nextRun: Date?
    let isEnabled: Bool
}

struct ContentItemViewModel: Identifiable {
    let id: String
    let title: String
    let previewImage: URL?
    let createdAt: Date
    let status: ContentStatus
    let version: Int
    
    enum ContentStatus: String, CaseIterable {
        case pending = "Pending"
        case approved = "Approved"
        case published = "Published"
        case rejected = "Rejected"
    }
}

struct ApprovalViewModel: Identifiable {
    let id: String
    let contentId: String
    let contentTitle: String
    let previewImage: URL?
    let submittedAt: Date
    let agentName: String
}

// MARK: - Shared UI Components

struct ContentStatusBadge: View {
    let status: ContentItemViewModel.ContentStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }
    
    var backgroundColor: Color {
        switch status {
        case .pending: return .orange
        case .approved: return .blue
        case .published: return .green
        case .rejected: return .red
        }
    }
}

#Preview("Empty") {
    ContentView()
        .environmentObject(AppState())
}

/*
#Preview("With Data") {
    let appState = AppState()
    let viewModel = ContentViewModel()
    viewModel.agents = [
        AgentViewModel(id: "1", name: "HAL-9000", status: .running, lastActivity: Date(), taskCount: 5),
        AgentViewModel(id: "2", name: "R2-D2", status: .idle, lastActivity: Date().addingTimeInterval(-3600), taskCount: 3),
        AgentViewModel(id: "3", name: "C-3PO", status: .error, lastActivity: nil, taskCount: 0)
    ]
    viewModel.tasks = [
        TaskViewModel(id: "1", name: "Daily Image Gen", schedule: "Daily at 9:00 AM", lastRun: Date(), nextRun: Date().addingTimeInterval(3600), isEnabled: true),
        TaskViewModel(id: "2", name: "Weekly Publish", schedule: "Mondays", lastRun: nil, nextRun: nil, isEnabled: false)
    ]
    viewModel.contentItems = [
        ContentItemViewModel(id: "1", title: "Amazing Artwork #1", previewImage: nil, createdAt: Date(), status: .pending, version: 1),
        ContentItemViewModel(id: "2", title: "Stunning Visual", previewImage: nil, createdAt: Date().addingTimeInterval(-86400), status: .approved, version: 3),
        ContentItemViewModel(id: "3", title: "Published Masterpiece", previewImage: nil, createdAt: Date().addingTimeInterval(-172800), status: .published, version: 2),
        ContentItemViewModel(id: "4", title: "Rejected Draft", previewImage: nil, createdAt: Date().addingTimeInterval(-259200), status: .rejected, version: 1)
    ]
    viewModel.pendingApprovals = [
        ApprovalViewModel(id: "1", contentId: "1", contentTitle: "Content for Review", previewImage: nil, submittedAt: Date(), agentName: "HAL-9000")
    ]
    ContentView()
        .environmentObject(appState)
}
*/

#Preview("Dark Mode") {
    ContentView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Small Window") {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
