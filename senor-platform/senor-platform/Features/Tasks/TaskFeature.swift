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
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            HStack(spacing: AppTheme.Spacing.medium) {
                                AppText(task.name, style: .headline)
                                Spacer()
                                AppStatusPill(title: task.scheduleDescription, color: AppTheme.ColorToken.statusInfo)
                            }
                            HStack(spacing: AppTheme.Spacing.medium) {
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
    @StateObject var formViewModel: TaskFormViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    AppInputField(
                        title: "Task Name",
                        placeholder: "Enter task name",
                        text: $formViewModel.taskName
                    )

                    Picker("Task Type", selection: $formViewModel.taskTypeID) {
                        Text("Select Type").tag("")
                        ForEach(formViewModel.creationContext.taskTypes) { type in
                            Text(type.name).tag(type.id)
                        }
                    }

                    Picker("Agent", selection: $formViewModel.agentID) {
                        Text("Select Agent").tag("")
                        ForEach(formViewModel.creationContext.agents) { agent in
                            Text(agent.displayName).tag(agent.id)
                        }
                    }
                }

                Section("Metadata") {
                    AppInputField(
                        title: "Metadata",
                        placeholder: "Enter metadata JSON",
                        text: $formViewModel.metadataJSON,
                        isMultiline: true,
                        height: 140
                    )
                }

                Section("Scheduling") {
                    Toggle("Enable Schedule", isOn: $formViewModel.enableSchedule)

                    if formViewModel.enableSchedule {
                        Picker("Schedule Type", selection: $formViewModel.scheduleSelection) {
                            ForEach(TaskScheduleSelection.allCases, id: \.self) { selection in
                                Text(selection.title).tag(selection)
                            }
                        }

                        switch formViewModel.scheduleSelection {
                        case .oneTime:
                            DatePicker("Run At", selection: $formViewModel.oneTimeDate, in: Date()...)

                        case .daily:
                            DatePicker("Time", selection: $formViewModel.timeOfDay, displayedComponents: .hourAndMinute)

                        case .weekly:
                            DatePicker("Time", selection: $formViewModel.timeOfDay, displayedComponents: .hourAndMinute)
                            HStack {
                                ForEach(ScheduleSpec.Weekday.allCases, id: \.self) { weekday in
                                    Toggle(weekday.shortName, isOn: Binding(
                                        get: { formViewModel.weekdays.contains(weekday) },
                                        set: { isOn in
                                            if isOn {
                                                formViewModel.weekdays.insert(weekday)
                                            } else {
                                                formViewModel.weekdays.remove(weekday)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.button)
                                }
                            }

                        case .monthly:
                            DatePicker("Time", selection: $formViewModel.timeOfDay, displayedComponents: .hourAndMinute)
                            Picker("Day", selection: Binding(
                                get: { formViewModel.monthDays.first ?? 1 },
                                set: { formViewModel.monthDays = [$0] }
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
                    .disabled(!formViewModel.canSave)
                }
            }
            .task {
                await formViewModel.loadCreationContext()
                if let error = formViewModel.errorMessage {
                    appState.errorMessage = error
                }
            }
        }
        .frame(minWidth: AppTheme.Layout.minSheetWidth, minHeight: 540)
    }

    private func submit() async {
        let success = await formViewModel.save()
        if success {
            dismiss()
        } else if let error = formViewModel.errorMessage {
            appState.errorMessage = error
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
