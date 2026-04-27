import SwiftUI

struct TasksScreen: View {
    @ObservedObject var viewModel: TasksViewModel
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                title: "Tasks",
                detail: "\(viewModel.tasks.count) enabled workflows",
                action: AnyView(
                    Button(action: onCreate) {
                        Label("New Task", systemImage: AppTheme.Icon.add)
                    }
                    .appButtonStyle(.borderedProminent)
                )
            )
            .padding(AppTheme.Spacing.screenPadding)

            AppDivider()

            if viewModel.tasks.isEmpty {
                Spacer()
                AppEmptyState(
                    title: "No Tasks Yet",
                    systemImage: AppTheme.Icon.task,
                    message: "Tasks connect agents to their scheduled content workflows."
                )
                Spacer()
            } else {
                List(viewModel.tasks) { task in
                    AppListRow {
                        AppVStack(spacing: .small, alignment: .leading) {
                            AppHStack(spacing: .medium) {
                                AppText(task.name, style: .headline)
                                Spacer()
                                AppStatusPill(title: task.scheduleDescription, color: AppTheme.ColorToken.statusInfo)
                            }
                            AppHStack(spacing: .medium) {
                                if let nextRun = task.nextRun {
                                    Label(nextRun.formatted(), systemImage: AppTheme.Icon.calendar)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.ColorToken.textSecondary)
                                }
                                if let lastRun = task.lastRun {
                                    Label(lastRun.formatted(), systemImage: AppTheme.Icon.clock)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.ColorToken.textSecondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct TaskFormSheet: View {
    @EnvironmentObject private var appState: AppShellModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasksViewModel

    @State private var taskName = ""
    @State private var taskTypeID = ""
    @State private var agentID = ""
    @State private var metadataJSON = "{\n  \"prompt\": \"\",\n  \"workflow\": \"\"\n}"
    @State private var enableSchedule = false
    @State private var scheduleSelection: TaskScheduleSelection = .oneTime
    @State private var oneTimeDate = Date().addingTimeInterval(3600)
    @State private var timeOfDay = Date()
    @State private var weekdays: Set<ScheduleSpec.Weekday> = [.monday]
    @State private var monthDays: Set<Int> = [1]
    @State private var timezone = TimeZone.current.identifier
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    AppInputField(
                        title: "Task Name",
                        placeholder: "Enter task name",
                        text: $taskName
                    )

                    Picker("Task Type", selection: $taskTypeID) {
                        Text("Select Type").tag("")
                        ForEach(viewModel.creationContext.taskTypes) { type in
                            Text(type.name).tag(type.id)
                        }
                    }

                    Picker("Agent", selection: $agentID) {
                        Text("Select Agent").tag("")
                        ForEach(viewModel.creationContext.agents) { agent in
                            Text(agent.displayName).tag(agent.id)
                        }
                    }
                }

                Section("Metadata") {
                    AppInputField(
                        title: "Metadata",
                        placeholder: "Enter metadata JSON",
                        text: $metadataJSON,
                        isMultiline: true,
                        height: 140
                    )
                }

                Section("Scheduling") {
                    Toggle("Enable Schedule", isOn: $enableSchedule)

                    if enableSchedule {
                        Picker("Schedule Type", selection: $scheduleSelection) {
                            ForEach(TaskScheduleSelection.allCases, id: \.self) { selection in
                                Text(selection.title).tag(selection)
                            }
                        }

                        switch scheduleSelection {
                        case .oneTime:
                            DatePicker("Run At", selection: $oneTimeDate, in: Date()...)

                        case .daily:
                            DatePicker("Time", selection: $timeOfDay, displayedComponents: .hourAndMinute)

                        case .weekly:
                            DatePicker("Time", selection: $timeOfDay, displayedComponents: .hourAndMinute)
                            HStack {
                                ForEach(ScheduleSpec.Weekday.allCases, id: \.self) { weekday in
                                    Toggle(weekday.shortName, isOn: Binding(
                                        get: { weekdays.contains(weekday) },
                                        set: { isOn in
                                            if isOn {
                                                weekdays.insert(weekday)
                                            } else {
                                                weekdays.remove(weekday)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.button)
                                }
                            }

                        case .monthly:
                            DatePicker("Time", selection: $timeOfDay, displayedComponents: .hourAndMinute)
                            Picker("Day", selection: Binding(
                                get: { monthDays.first ?? 1 },
                                set: { monthDays = [$0] }
                            )) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)").tag(day)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await submit() }
                    }
                    .disabled(taskName.isEmpty || taskTypeID.isEmpty || agentID.isEmpty || isSaving)
                }
            }
            .task {
                do {
                    try await viewModel.loadCreationContext()
                    if taskTypeID.isEmpty {
                        taskTypeID = viewModel.creationContext.taskTypes.first?.id ?? ""
                    }
                    if agentID.isEmpty {
                        agentID = viewModel.creationContext.agents.first?.id ?? ""
                    }
                } catch {
                    appState.errorMessage = error.localizedDescription
                }
            }
        }
        .frame(minWidth: AppTheme.Layout.minSheetWidth, minHeight: 540)
    }

    private func submit() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await viewModel.create(
                draft: TaskDraft(
                    agentId: agentID,
                    taskTypeId: taskTypeID,
                    taskName: taskName,
                    metadataJSON: metadataJSON,
                    schedule: buildSchedule()
                )
            )
            dismiss()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func buildSchedule() -> ScheduleDraft? {
        guard enableSchedule else { return nil }
        switch scheduleSelection {
        case .oneTime:
            return .oneTime(oneTimeDate, timezone: timezone)

        case .daily:
            return .daily(time: timeOfDay, timezone: timezone)

        case .weekly:
            return .weekly(time: timeOfDay, weekdays: weekdays, timezone: timezone)

        case .monthly:
            return .monthly(time: timeOfDay, days: monthDays, timezone: timezone)
        }
    }
}

enum TaskScheduleSelection: CaseIterable {
    case oneTime
    case daily
    case weekly
    case monthly

    var title: String {
        switch self {
        case .oneTime: return "One Time"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - Previews

// Note: Preview requires complex dependencies - use WorkspaceView for testing
