//
//  MainContentView.swift
//  senor-platform
//

import SwiftUI

struct MainContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch viewModel.selectedMainView {
            case .dashboard:
                DashboardView(viewModel: viewModel)
            case .agents:
                AgentsListView(viewModel: viewModel)
            case .tasks:
                TasksListView(viewModel: viewModel)
            case .content:
                ContentListView(viewModel: viewModel)
            case .approvals:
                ApprovalsView(viewModel: viewModel)
            case .settings:
                SettingsMainView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(
                        title: "Active Agents",
                        value: "\(viewModel.agents.count)",
                        icon: "cpu",
                        color: .blue
                    )

                    StatCard(
                        title: "Pending Approvals",
                        value: "\(viewModel.pendingApprovals.count)",
                        icon: "checkmark.shield",
                        color: .orange
                    )

                    StatCard(
                        title: "Scheduled Tasks",
                        value: "\(viewModel.tasks.filter { $0.isEnabled }.count)",
                        icon: "list.bullet.rectangle",
                        color: .green
                    )

                    StatCard(
                        title: "Published Content",
                        value: "\(viewModel.contentItems.filter { $0.status == .published }.count)",
                        icon: "doc.text.image",
                        color: .purple
                    )
                }
                .padding(.horizontal)

                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.title2)
                        .bold()

                    if viewModel.contentItems.isEmpty {
                        ContentUnavailableView("No Recent Activity", systemImage: "clock")
                            .frame(height: 200)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.contentItems.prefix(5)) { item in
                                ActivityRow(item: item)
                            }
                        }
                    }
                }
                .padding()
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("Dashboard")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.largeTitle)
                        .bold()
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }
}

struct ActivityRow: View {
    let item: ContentItemViewModel

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(StatusColor.from(item.status.rawValue).swiftUIColor)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                Text(item.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: item.status.rawValue)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Agents List

struct AgentsListView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(viewModel.agents.count) Agents")
                    .font(.headline)
                Spacer()
                Button {
                    appState.showNewAgentSheet = true
                } label: {
                    Label("New Agent", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            // List
            List(viewModel.agents) { agent in
                AgentRow(agent: agent)
                    .tag(agent.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedAgentId = agent.id
                    }
                    .background(viewModel.selectedAgentId == agent.id ? Color.accentColor.opacity(0.1) : Color.clear)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Agents")
    }
}

struct AgentRow: View {
    let agent: AgentViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: agent.status.icon)
                .foregroundStyle(agent.status.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.headline)
                HStack {
                    Text(agent.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lastActivity = agent.lastActivity {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(lastActivity, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text("\(agent.taskCount) tasks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tasks List

struct TasksListView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(viewModel.tasks.count) Tasks")
                    .font(.headline)
                Spacer()
                Button {
                    appState.showNewTaskSheet = true
                } label: {
                    Label("New Task", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            List(viewModel.tasks) { task in
                TaskRow(task: task)
                    .tag(task.id)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Tasks")
    }
}

struct TaskRow: View {
    let task: TaskViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                Text(task.schedule)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if task.isEnabled {
                    Label("Enabled", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Disabled", systemImage: "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let nextRun = task.nextRun {
                    Text("Next: \(nextRun, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Content List

struct ContentListView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var filterStatus: ContentItemViewModel.ContentStatus?
    @State private var searchText = ""

    var filteredContent: [ContentItemViewModel] {
        var items = viewModel.contentItems

        if let filter = filterStatus {
            items = items.filter { $0.status == filter }
        }

        if !searchText.isEmpty {
            items = items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter
            HStack {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Filter", selection: $filterStatus) {
                    Text("All")
                        .tag(nil as ContentItemViewModel.ContentStatus?)
                    ForEach(ContentItemViewModel.ContentStatus.allCases, id: \.self) { status in
                        Text(status.rawValue)
                            .tag(status as ContentItemViewModel.ContentStatus?)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding()

            Divider()

            List(selection: $viewModel.selectedContentId) {
                ForEach(filteredContent) { item in
                    ContentRow(item: item)
                        .tag(item.id)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Content")
    }
}

struct ContentRow: View {
    let item: ContentItemViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let previewURL = item.previewImage {
                AsyncImage(url: previewURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.secondary.opacity(0.2))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                HStack {
                    Text("v\(item.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StatusBadge(status: item.status.rawValue)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Approvals View

struct ApprovalsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var selectedItems = Set<String>()
    @State private var showRejectDialog = false
    @State private var rejectReason = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            // Batch Actions Toolbar
            if !selectedItems.isEmpty {
                HStack {
                    Text("\(selectedItems.count) selected")
                    Spacer()
                    Button("Approve All") {
                        batchApprove()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button("Reject All") {
                        showRejectDialog = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
                .background(.background.secondary)
            }

            Divider()

            if viewModel.pendingApprovals.isEmpty {
                ContentUnavailableView(
                    "No Pending Approvals",
                    systemImage: "checkmark.circle.fill"
                )
            } else {
                List(selection: $selectedItems) {
                    ForEach(viewModel.pendingApprovals) { approval in
                        ApprovalRow(
                            approval: approval,
                            onApprove: { approveItem(approval.contentId) },
                            onReject: { rejectItem(approval.contentId) }
                        )
                        .tag(approval.id)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Pending Approvals")
        .disabled(isProcessing)
        .overlay {
            if isProcessing {
                ProgressView()
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert("Reject Selected", isPresented: $showRejectDialog) {
            TextField("Reason (optional)", text: $rejectReason)
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) {
                batchReject()
            }
        } message: {
            Text("Provide a reason for rejection (optional)")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private func approveItem(_ id: String) {
        isProcessing = true
        Task {
            do {
                try await viewModel.approveContent(id: id)
                isProcessing = false
            } catch {
                isProcessing = false
                errorMessage = "Failed to approve: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func rejectItem(_ id: String) {
        isProcessing = true
        Task {
            do {
                try await viewModel.rejectContent(id: id, reason: nil)
                isProcessing = false
            } catch {
                isProcessing = false
                errorMessage = "Failed to reject: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func batchApprove() {
        isProcessing = true
        Task {
            do {
                let contentIds = viewModel.pendingApprovals
                    .filter { selectedItems.contains($0.id) }
                    .map { $0.contentId }
                try await viewModel.batchApprove(ids: contentIds)
                selectedItems.removeAll()
                isProcessing = false
            } catch {
                isProcessing = false
                errorMessage = "Failed to batch approve: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func batchReject() {
        isProcessing = true
        Task {
            do {
                let contentIds = viewModel.pendingApprovals
                    .filter { selectedItems.contains($0.id) }
                    .map { $0.contentId }
                try await viewModel.batchReject(ids: contentIds, reason: rejectReason.isEmpty ? nil : rejectReason)
                rejectReason = ""
                selectedItems.removeAll()
                isProcessing = false
            } catch {
                isProcessing = false
                errorMessage = "Failed to batch reject: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

struct ApprovalRow: View {
    let approval: ApprovalViewModel
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let previewURL = approval.previewImage {
                AsyncImage(url: previewURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ContentThumbnail(
                        url: previewURL,
                        size: 80,
                        cornerRadius: 8
                    )
                }
                .frame(width: 80, height: 80)
            } else {
                ContentThumbnail(
                    url: nil,
                    size: 80,
                    cornerRadius: 8
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(approval.contentTitle)
                    .font(.headline)
                Text("By \(approval.agentName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(approval.submittedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onApprove()
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    onReject()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Settings Main View

struct SettingsMainView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: .constant(false))
                Toggle("Show Notifications", isOn: .constant(true))
            }

            Section("Storage") {
                LabeledContent("Database Size", value: "--")
                LabeledContent("Cache Size", value: "--")
                Button("Clear Cache") {}
            }

            Section("Integrations") {
                NavigationLink("DeviantArt") {
                    DeviantArtSettingsView()
                }
                NavigationLink("Patreon") {
                    PatreonSettingsView()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

#Preview("Dashboard - Empty") {
    MainContentView(viewModel: ContentViewModel())
        .environmentObject(AppState())
}

#Preview("Dashboard - With Data") {
    let viewModel = ContentViewModel()
    viewModel.selectedMainView = .dashboard
    viewModel.agents = [
        AgentViewModel(id: "1", name: "Agent Alpha", status: .running, lastActivity: Date(), taskCount: 10),
        AgentViewModel(id: "2", name: "Agent Beta", status: .idle, lastActivity: Date().addingTimeInterval(-7200), taskCount: 5),
        AgentViewModel(id: "3", name: "Agent Gamma", status: .error, lastActivity: Date().addingTimeInterval(-3600), taskCount: 3),
        AgentViewModel(id: "4", name: "Agent Delta", status: .offline, lastActivity: nil, taskCount: 0)
    ]
    viewModel.tasks = [
        TaskViewModel(id: "1", name: "Task 1", schedule: "Daily", lastRun: Date(), nextRun: Date().addingTimeInterval(3600), isEnabled: true),
        TaskViewModel(id: "2", name: "Task 2", schedule: "Weekly", lastRun: Date().addingTimeInterval(-86400), nextRun: Date().addingTimeInterval(172800), isEnabled: true),
        TaskViewModel(id: "3", name: "Disabled Task", schedule: "Monthly", lastRun: nil, nextRun: nil, isEnabled: false)
    ]
    viewModel.contentItems = [
        ContentItemViewModel(id: "1", title: "Content 1", previewImage: nil, createdAt: Date(), status: .pending, version: 1),
        ContentItemViewModel(id: "2", title: "Content 2", previewImage: nil, createdAt: Date().addingTimeInterval(-3600), status: .approved, version: 2),
        ContentItemViewModel(id: "3", title: "Content 3", previewImage: nil, createdAt: Date().addingTimeInterval(-7200), status: .published, version: 3),
        ContentItemViewModel(id: "4", title: "Content 4", previewImage: nil, createdAt: Date().addingTimeInterval(-10800), status: .rejected, version: 1)
    ]
    viewModel.pendingApprovals = [
        ApprovalViewModel(id: "1", contentId: "1", contentTitle: "Approval Item 1", previewImage: nil, submittedAt: Date(), agentName: "Agent Alpha"),
        ApprovalViewModel(id: "2", contentId: "2", contentTitle: "Approval Item 2", previewImage: nil, submittedAt: Date().addingTimeInterval(-1800), agentName: "Agent Beta")
    ]
    return MainContentView(viewModel: viewModel)
        .environmentObject(AppState())
}

#Preview("Agents View") {
    let viewModel = ContentViewModel()
    viewModel.selectedMainView = .agents
    viewModel.agents = [
        AgentViewModel(id: "1", name: "Running Agent", status: .running, lastActivity: Date(), taskCount: 5),
        AgentViewModel(id: "2", name: "Idle Agent", status: .idle, lastActivity: Date().addingTimeInterval(-3600), taskCount: 3),
        AgentViewModel(id: "3", name: "Error Agent", status: .error, lastActivity: Date().addingTimeInterval(-7200), taskCount: 0),
        AgentViewModel(id: "4", name: "Offline Agent", status: .offline, lastActivity: nil, taskCount: 1)
    ]
    return MainContentView(viewModel: viewModel)
        .environmentObject(AppState())
}

#Preview("Tasks View - Empty") {
    let viewModel = ContentViewModel()
    viewModel.selectedMainView = .tasks
    return MainContentView(viewModel: viewModel)
        .environmentObject(AppState())
}

#Preview("Tasks View - With Tasks") {
    let viewModel = ContentViewModel()
    viewModel.selectedMainView = .tasks
    viewModel.tasks = [
        TaskViewModel(id: "1", name: "Enabled Task", schedule: "Daily at 9:00 AM", lastRun: Date(), nextRun: Date().addingTimeInterval(3600), isEnabled: true),
        TaskViewModel(id: "2", name: "Disabled Task", schedule: "Weekly", lastRun: Date().addingTimeInterval(-86400), nextRun: nil, isEnabled: false),
        TaskViewModel(id: "3", name: "No Next Run", schedule: "One-time", lastRun: Date(), nextRun: nil, isEnabled: true)
    ]
    return MainContentView(viewModel: viewModel)
        .environmentObject(AppState())
}

#Preview("Content View - All Filters") {
    let viewModel = ContentViewModel()
    viewModel.selectedMainView = .content
    viewModel.contentItems = (0..<20).map { i in
        ContentItemViewModel(
            id: "\(i)",
            title: "Content Item \(i + 1) with a longer title",
            previewImage: nil,
            createdAt: Date().addingTimeInterval(Double(-i * 3600)),
            status: [.pending, .approved, .published, .rejected][i % 4],
            version: (i % 3) + 1
        )
    }
    return MainContentView(viewModel: viewModel)
        .environmentObject(AppState())
}

#Preview("Approvals View - Empty") {
    let viewModel = ContentViewModel()
    viewModel.selectedMainView = .approvals
    return MainContentView(viewModel: viewModel)
        .environmentObject(AppState())
}

#Preview("Approvals View - With Items") {
    let viewModel = ContentViewModel()
    viewModel.selectedMainView = .approvals
    viewModel.pendingApprovals = (0..<10).map { i in
        ApprovalViewModel(
            id: "\(i)",
            contentId: "\(i)",
            contentTitle: "Content for Approval \(i + 1)",
            previewImage: nil,
            submittedAt: Date().addingTimeInterval(Double(-i * 600)),
            agentName: "Agent \(i % 3 + 1)"
        )
    }
    return MainContentView(viewModel: viewModel)
        .environmentObject(AppState())
}

#Preview("Settings View") {
    let viewModel = ContentViewModel()
    viewModel.selectedMainView = .settings
    return MainContentView(viewModel: viewModel)
        .environmentObject(AppState())
}

#Preview("Dark Mode") {
    MainContentView(viewModel: ContentViewModel())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Compact Width") {
    MainContentView(viewModel: ContentViewModel())
        .environmentObject(AppState())
        .frame(width: 600, height: 500)
}
