//
//  NewTaskView.swift
//  senor-platform
//

import SwiftUI
import Foundation

struct NewTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NewTaskViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task Name", text: $viewModel.taskName)
                        .autocorrectionDisabled()
                    
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...4)
                    
                    Picker("Task Type", selection: $viewModel.taskTypeId) {
                        Text("Select Type...").tag("")
                        ForEach(viewModel.availableTaskTypes, id: \.id) { type in
                            Text(type.name).tag(type.id)
                        }
                    }
                    
                    Picker("Agent", selection: $viewModel.agentId) {
                        Text("Select Agent...").tag("")
                        ForEach(viewModel.availableAgents, id: \.id) { agent in
                            Text(agent.displayName).tag(agent.id)
                        }
                    }
                }
                
                Section("Task Metadata") {
                    TextEditor(text: $viewModel.metadataJson)
                        .frame(minHeight: 150)
                        .overlay(alignment: .topLeading) {
                            if viewModel.metadataJson.isEmpty {
                                Text("{\n  \"key\": \"value\"\n}")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                    
                    if let validationError = viewModel.validationError {
                        Text(validationError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                
                Section("Schedule") {
                    Toggle("Enable Scheduling", isOn: $viewModel.hasSchedule)
                    
                    if viewModel.hasSchedule {
                        ScheduleSpecView(
                            scheduleSelection: $viewModel.scheduleKind,
                            oneTimeDate: $viewModel.oneTimeDate,
                            dailyTime: $viewModel.dailyTime,
                            selectedWeekdays: $viewModel.selectedWeekdays,
                            selectedMonthDays: $viewModel.selectedMonthDays,
                            timezone: $viewModel.timezone
                        )
                    }
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createTask()
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.loadData()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

@MainActor
class NewTaskViewModel: ObservableObject {
    @Published var taskName = ""
    @Published var description = ""
    @Published var taskTypeId = ""
    @Published var agentId = ""
    @Published var metadataJson = "{\n  \"prompt\": \"\",\n  \"workflow\": \"\"\n}"
    @Published var hasSchedule = false
    
    // Schedule state - using raw values that match ScheduleSpec enum
    @Published var scheduleKind: ScheduleUISelection = .oneTime
    @Published var oneTimeDate = Date().addingTimeInterval(3600)
    @Published var dailyTime = Date()
    @Published var selectedWeekdays: Set<ScheduleSpec.Weekday> = [.monday]
    @Published var selectedMonthDays: Set<Int> = [1]
    @Published var timezone = TimeZone.current.identifier
    
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var availableAgents: [AgentRecord] = []
    @Published var availableTaskTypes: [TaskTypeRecord] = []
    @Published var validationError: String?
    
    var isValid: Bool {
        !taskName.isEmpty && !agentId.isEmpty && !taskTypeId.isEmpty && validationError == nil
    }
    
    func loadData() async {
        do {
            let agentRepo: AgentRepository = await sharedContainer.resolveOrCrash(AgentRepository.self)
            availableAgents = try await agentRepo.listAll()
            
            let taskTypeRepo: TaskTypeRepository = await sharedContainer.resolveOrCrash(TaskTypeRepository.self)
            availableTaskTypes = try await taskTypeRepo.listAll()
            
            if let firstType = availableTaskTypes.first {
                taskTypeId = firstType.id
            }
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func createTask() async {
        do {
            guard !agentId.isEmpty, !taskTypeId.isEmpty else { return }
            
            // Validate JSON
            guard JSONUtils.validate(metadataJson) else {
                validationError = "Invalid JSON metadata"
                return
            }
            validationError = nil
            
            // Create task record with correct initializer
            // Get script path from SettingsService (configurable via settings)
            let settingsService = await sharedContainer.resolveOptional(SettingsService.self)
            let scriptPath = settingsService?.taskScriptPath()
                ?? Bundle.main.path(forResource: "senor-task", ofType: nil)
                ?? "/usr/local/bin/senor-task"
            let task = TaskRecord(
                agentId: agentId,
                taskTypeId: taskTypeId,
                taskName: taskName,
                taskMetadataJson: metadataJson,
                goScriptPath: scriptPath,
                isEnabled: true
            )
            
            let repository: TaskRepository = await sharedContainer.resolveOrCrash(TaskRepository.self)
            let savedTask = try await repository.create(task: task)
            
            // Create schedule if enabled
            if hasSchedule {
                let scheduleSpec = buildScheduleSpec()
                let compiler = ScheduleCompiler()
                let cronExpression = compiler.compileToCron(scheduleSpec)
                let nextRunAt = compiler.nextRunTime(from: scheduleSpec)
                
                let coder = ScheduleSpecCoder()
                let schedulePayload = coder.encode(scheduleSpec)
                
                let scheduleRecord = TaskScheduleRecord(
                    taskId: savedTask.id,
                    scheduleKind: scheduleKind == .oneTime ? "one_time" : "recurring",
                    schedulePayloadJson: schedulePayload,
                    cronExpression: cronExpression,
                    timezone: timezone,
                    nextRunAt: nextRunAt,
                    isActive: true
                )
                
                let scheduleRepo: TaskScheduleRepository = await sharedContainer.resolveOrCrash(TaskScheduleRepository.self)
                _ = try await scheduleRepo.create(schedule: scheduleRecord)
            }
            
            await EventBus.shared.refreshAllData()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func buildScheduleSpec() -> ScheduleSpec {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: dailyTime)
        let scheduleTime = ScheduleSpec.ScheduleTime(
            hour: timeComponents.hour ?? 9,
            minute: timeComponents.minute ?? 0
        )
        
        switch scheduleKind {
        case .oneTime:
            return .oneTime(date: oneTimeDate)
        case .daily:
            return .daily(time: scheduleTime, timezone: timezone)
        case .weekly:
            let days = Array(selectedWeekdays).sorted { $0.rawValue < $1.rawValue }
            return .weekly(time: scheduleTime, days: days, timezone: timezone)
        case .monthly:
            let days = Array(selectedMonthDays).sorted()
            return .monthly(time: scheduleTime, days: days, timezone: timezone)
        }
    }
}

// MARK: - Schedule UI Selection Enum

/// UI selection enum for schedule type picker - maps to ScheduleSpec cases
enum ScheduleUISelection: String, CaseIterable {
    case oneTime = "One Time"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    var displayName: String { rawValue }
}

// MARK: - Schedule Spec View

struct ScheduleSpecView: View {
    @Binding var scheduleSelection: ScheduleUISelection
    @Binding var oneTimeDate: Date
    @Binding var dailyTime: Date
    @Binding var selectedWeekdays: Set<ScheduleSpec.Weekday>
    @Binding var selectedMonthDays: Set<Int>
    @Binding var timezone: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Schedule Type", selection: $scheduleSelection) {
                ForEach(ScheduleUISelection.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            
            switch scheduleSelection {
            case .oneTime:
                DatePicker("Run At", selection: $oneTimeDate, in: Date()...)
                
            case .daily:
                DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                
            case .weekly:
                DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                
                VStack(alignment: .leading) {
                    Text("Days:")
                        .font(.caption)
                    HStack {
                        ForEach(ScheduleSpec.Weekday.allCases, id: \.self) { day in
                            Toggle(day.shortName, isOn: Binding(
                                get: { selectedWeekdays.contains(day) },
                                set: { isOn in
                                    if isOn {
                                        selectedWeekdays.insert(day)
                                    } else {
                                        selectedWeekdays.remove(day)
                                    }
                                }
                            ))
                            .toggleStyle(.button)
                            .font(.caption)
                        }
                    }
                }
                
            case .monthly:
                DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                
                VStack(alignment: .leading) {
                    Text("Days of month:")
                        .font(.caption)
                    
                    // Simplified - just use first selected day for now
                    Picker("Day", selection: Binding(
                        get: { selectedMonthDays.first ?? 1 },
                        set: { selectedMonthDays = [$0] }
                    )) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

#Preview {
    NewTaskView()
}
