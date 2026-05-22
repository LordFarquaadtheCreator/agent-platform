import SwiftUI

struct ComfyUIScreen: View {
    @ObservedObject var viewModel: ComfyUIViewModel
    @ObservedObject var router: AppRouter
    @State private var showOutputDirectoryPicker = false
    @State private var outputDirectory: String = ""

    var body: some View {
        VStack(spacing: 0) {
            headerView
            AppDivider()
            contentView
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task { await viewModel.load() }
    }

    private var headerView: some View {
        HStack {
            AppSectionHeader(
                title: "ComfyUI",
                detail: viewModel.isConnected ? "Connected" : "Disconnected"
            )
            Spacer()

            if viewModel.isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, AppTheme.Spacing.small)
            }

            HStack(spacing: AppTheme.Spacing.small) {
                AppStatusPill(
                    title: viewModel.isConnected ? "Online" : "Offline",
                    color: viewModel.isConnected ? AppTheme.ColorToken.statusSuccess : AppTheme.ColorToken.statusError
                )
            }
            .padding(.trailing, AppTheme.Spacing.small)

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: AppTheme.Icon.refresh)
            }
            .disabled(viewModel.isRefreshing)
        }
        .padding(AppTheme.Spacing.screenPadding)
    }

    @ViewBuilder
    private var contentView: some View {
        if !viewModel.isConnected {
            NotConnectedView(
                title: "ComfyUI Not Reachable",
                systemImage: "cpu.fill",
                message: "ComfyUI server not running at configured URL. Start ComfyUI or check Settings."
            )
        } else if viewModel.isLoading && viewModel.workflows.isEmpty {
            LoadingStateView()
        } else {
            HStack(spacing: 0) {
                // Left: Workflow list
                workflowListView
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 280)

                AppDivider()
                    .frame(width: 1)

                // Center: Node editor or empty state
                nodeEditorView
                    .frame(minWidth: 300, maxWidth: .infinity)

                AppDivider()
                    .frame(width: 1)

                // Right: Queue + History
                queueHistoryView
                    .frame(minWidth: 240, idealWidth: 300, maxWidth: 360)
            }
        }
    }

    // MARK: - Workflow List

    private var workflowListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppText("Workflows", style: .headline)
                .padding(AppTheme.Spacing.medium)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    ForEach(viewModel.workflows) { workflow in
                        WorkflowRow(
                            workflow: workflow,
                            isSelected: router.selectedWorkflowID == workflow.id
                        )
                        .onTapGesture {
                            router.selectedWorkflowID = workflow.id
                            viewModel.selectWorkflow(id: workflow.id)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
            }
        }
        .background(AppTheme.ColorToken.chromeBackground)
    }

    // MARK: - Node Editor

    @ViewBuilder
    private var nodeEditorView: some View {
        if let workflow = viewModel.selectedWorkflow {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    HStack {
                        AppText(workflow.name, style: .title2)
                        Spacer()
                        Button {
                            Task {
                                await viewModel.executeWorkflow(
                                    workflow: workflow,
                                    outputDirectory: outputDirectory.isEmpty ? nil : outputDirectory
                                )
                            }
                        } label: {
                            Label("Queue", systemImage: "play.fill")
                        }
                        .appButtonStyle(.borderedProminent)
                    }

                    // Output directory
                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            AppText("Output Directory", style: .caption)
                            HStack {
                                AppText(
                                    outputDirectory.isEmpty ? "Default (Documents/ComfyUI/user/default/output)" : outputDirectory,
                                    style: .body,
                                    color: AppTheme.ColorToken.textSecondary
                                )
                                .lineLimit(1)
                                Spacer()
                                Button("Browse") {
                                    showOutputDirectoryPicker = true
                                }
                                .appButtonStyle(.bordered)
                            }
                        }
                    }

                    // Nodes
                    ForEach(workflow.nodes) { node in
                        NodeEditorCard(
                            node: node,
                            workflowID: workflow.id,
                            viewModel: viewModel
                        )
                    }
                }
                .padding(AppTheme.Spacing.screenPadding)
            }
        } else {
            AppEmptyState(
                title: "No Workflow Selected",
                systemImage: "cpu.fill",
                message: "Choose a workflow from the list to edit inputs and queue execution."
            )
        }
    }

    // MARK: - Queue + History

    private var queueHistoryView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Queue section
            AppText("Queue", style: .headline)
                .padding(AppTheme.Spacing.medium)

            if let running = viewModel.queueStatus.runningItem {
                RunningItemRow(item: running, viewModel: viewModel)
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.bottom, AppTheme.Spacing.small)
            }

            if !viewModel.queueStatus.pendingItems.isEmpty {
                AppText("Pending", style: .caption)
                    .padding(.horizontal, AppTheme.Spacing.medium)
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: AppTheme.Spacing.small) {
                        ForEach(viewModel.queueStatus.pendingItems) { item in
                            QueueItemRow(item: item)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.medium)
                }
                .frame(maxHeight: 120)
            } else if viewModel.queueStatus.runningItem == nil {
                AppText("Queue empty", style: .caption, color: AppTheme.ColorToken.textSecondary)
                    .padding(.horizontal, AppTheme.Spacing.medium)
            }

            AppDivider()
                .padding(.vertical, AppTheme.Spacing.small)

            // History section
            AppText("History", style: .headline)
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.bottom, AppTheme.Spacing.small)

            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.small) {
                    ForEach(viewModel.executions) { execution in
                        ExecutionRow(
                            execution: execution,
                            isSelected: router.selectedExecutionID == execution.id
                        )
                        .onTapGesture {
                            router.selectedExecutionID = execution.id
                            viewModel.selectExecution(id: execution.id)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
            }
        }
        .background(AppTheme.ColorToken.chromeBackground)
    }
}

// MARK: - Workflow Row

private struct WorkflowRow: View {
    let workflow: ComfyUIWorkflow
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: "doc.text")
                .foregroundStyle(AppTheme.ColorToken.accent)
            AppText(workflow.name, style: .body)
                .lineLimit(1)
            Spacer()
            AppText("\(workflow.nodes.count) nodes", style: .caption2, color: AppTheme.ColorToken.textSecondary)
        }
        .padding(AppTheme.Spacing.small)
        .background(
            isSelected
                ? AppTheme.ColorToken.accent.opacity(0.15)
                : AppTheme.ColorToken.clear
        )
        .cornerRadius(AppTheme.CornerRadius.small)
        .contentShape(Rectangle())
    }
}

// MARK: - Node Editor Card

private struct NodeEditorCard: View {
    let node: ComfyUINode
    let workflowID: String
    @ObservedObject var viewModel: ComfyUIViewModel
    @State private var isExpanded = true

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack {
                        AppText(node.classType, style: .headline)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .appButtonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        ForEach(node.inputs) { input in
                            NodeInputControl(
                                input: input,
                                workflowID: workflowID,
                                nodeID: node.id,
                                viewModel: viewModel
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Node Input Control

private struct NodeInputControl: View {
    let input: ComfyUIInputParameter
    let workflowID: String
    let nodeID: String
    @ObservedObject var viewModel: ComfyUIViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
            AppText(input.key, style: .caption)
                .foregroundStyle(AppTheme.ColorToken.textSecondary)

            switch input.type {
            case .string:
                TextEditor(text: Binding(
                    get: { input.currentValue },
                    set: { viewModel.updateInput(workflowID: workflowID, nodeID: nodeID, key: input.key, value: $0) }
                ))
                .frame(minHeight: 32, maxHeight: 80)
                .font(AppTheme.Typography.body)
                .padding(AppTheme.Spacing.xSmall)
                .background(AppTheme.ColorToken.textSecondary.opacity(0.05))
                .cornerRadius(AppTheme.CornerRadius.small)

            case .int:
                HStack {
                    TextField("", text: Binding(
                        get: { input.currentValue },
                        set: { viewModel.updateInput(workflowID: workflowID, nodeID: nodeID, key: input.key, value: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    if let min = input.minValue, let max = input.maxValue {
                        Slider(
                            value: Binding(
                                get: { Double(input.currentValue) ?? Double(input.defaultValue) ?? min },
                                set: { viewModel.updateInput(workflowID: workflowID, nodeID: nodeID, key: input.key, value: String(Int($0))) }
                            ),
                            in: min...max,
                            step: input.step ?? 1
                        )
                        .frame(width: 120)
                    }
                }

            case .float:
                HStack {
                    TextField("", text: Binding(
                        get: { input.currentValue },
                        set: { viewModel.updateInput(workflowID: workflowID, nodeID: nodeID, key: input.key, value: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    if let min = input.minValue, let max = input.maxValue {
                        Slider(
                            value: Binding(
                                get: { Double(input.currentValue) ?? Double(input.defaultValue) ?? min },
                                set: { viewModel.updateInput(workflowID: workflowID, nodeID: nodeID, key: input.key, value: String($0)) }
                            ),
                            in: min...max,
                            step: input.step ?? 0.1
                        )
                        .frame(width: 120)
                    }
                }

            case .boolean:
                Toggle(input.key, isOn: Binding(
                    get: { input.currentValue.lowercased() == "true" },
                    set: { viewModel.updateInput(workflowID: workflowID, nodeID: nodeID, key: input.key, value: $0 ? "true" : "false") }
                ))

            case .combo:
                if let options = input.options, !options.isEmpty {
                    Picker("", selection: Binding(
                        get: { input.currentValue },
                        set: { viewModel.updateInput(workflowID: workflowID, nodeID: nodeID, key: input.key, value: $0) }
                    )) {
                        ForEach(options, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    TextField("", text: Binding(
                        get: { input.currentValue },
                        set: { viewModel.updateInput(workflowID: workflowID, nodeID: nodeID, key: input.key, value: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

            case .image:
                HStack {
                    AppText(input.currentValue.isEmpty ? "No image selected" : input.currentValue, style: .body)
                        .lineLimit(1)
                    Spacer()
                    Button("Upload") {
                        // Image upload handled via sheet/picker
                    }
                    .appButtonStyle(.bordered)
                }
            }
        }
    }
}

// MARK: - Running Item Row

private struct RunningItemRow: View {
    let item: ComfyUIQueueItem
    @ObservedObject var viewModel: ComfyUIViewModel

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack {
                    AppText("Running", style: .caption, color: AppTheme.ColorToken.statusInfo)
                    Spacer()
                    Button {
                        Task { await viewModel.cancelExecution(id: item.promptID) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.ColorToken.statusError)
                    }
                    .appButtonStyle(.plain)
                }

                if let execution = viewModel.executions.first(where: { $0.id == item.promptID }) {
                    ProgressView(value: execution.progress)
                        .progressViewStyle(.linear)
                    HStack {
                        AppText("Node: \(execution.currentNode ?? "...")", style: .caption2, color: AppTheme.ColorToken.textSecondary)
                        Spacer()
                        AppText("\(Int(execution.progress * 100))%", style: .caption2, color: AppTheme.ColorToken.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Queue Item Row

private struct QueueItemRow: View {
    let item: ComfyUIQueueItem

    var body: some View {
        HStack {
            AppText("#\(item.number)", style: .caption, color: AppTheme.ColorToken.textSecondary)
            Spacer()
            AppText(String(item.promptID.prefix(8)), style: .caption2, color: AppTheme.ColorToken.textSecondary)
        }
        .padding(AppTheme.Spacing.small)
        .background(AppTheme.ColorToken.textSecondary.opacity(0.05))
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}

// MARK: - Execution Row

private struct ExecutionRow: View {
    let execution: ComfyUIExecution
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            statusIcon
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                AppText(execution.workflowName, style: .body)
                    .lineLimit(1)
                HStack(spacing: AppTheme.Spacing.small) {
                    AppText(execution.status.rawValue.capitalized, style: .caption2, color: statusColor)
                    if !execution.outputs.isEmpty {
                        AppText("\(execution.outputs.count) outputs", style: .caption2, color: AppTheme.ColorToken.textSecondary)
                    }
                }
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.small)
        .background(
            isSelected
                ? AppTheme.ColorToken.accent.opacity(0.15)
                : AppTheme.ColorToken.clear
        )
        .cornerRadius(AppTheme.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .stroke(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch execution.status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(AppTheme.ColorToken.statusNeutral)
        case .running:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(AppTheme.ColorToken.statusInfo)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.ColorToken.statusSuccess)
        case .error, .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AppTheme.ColorToken.statusError)
        }
    }

    private var statusColor: Color {
        switch execution.status {
        case .queued:
            return AppTheme.ColorToken.statusNeutral
        case .running:
            return AppTheme.ColorToken.statusInfo
        case .completed:
            return AppTheme.ColorToken.statusSuccess
        case .error, .cancelled:
            return AppTheme.ColorToken.statusError
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    ComfyUIScreen(
        viewModel: previewComfyUIViewModel(),
        router: AppRouter()
    )
}
#endif
