//
//  NewTaskView.swift
//  senor-platform
//

import SwiftUI

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
                    
                    Picker("Task Type", selection: $viewModel.taskType) {
                        ForEach(viewModel.availableTaskTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    Picker("Agent", selection: $viewModel.agentId) {
                        Text("Select Agent...").tag(nil as String?)
                        ForEach(viewModel.availableAgents, id: \.id) { agent in
                            Text(agent.agentName).tag(agent.id as String?)
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
                        ScheduleSpecView(schedule: $viewModel.schedule)
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
                    AsyncActionButton("Create") {
                        await viewModel.createTask()
                        dismiss()
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
    @Published var taskType = ""
    @Published var agentId: String?
    @Published var metadataJson = "{\n  \"prompt\": \"\",\n  \"workflow\": \"\"\n}"
    @Published var hasSchedule = false
    @Published var schedule = ScheduleSpec(kind: .oneTime, oneTime: OneTimeSchedule(date: Date()))
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var availableAgents: [AgentRecord] = []
    @Published var availableTaskTypes: [String] = []
    @Published var validationError: String?
    
    var isValid: Bool {
        !taskName.isEmpty && agentId != nil && validationError == nil
    }
    
    func loadData() async {
        do {
            let agentRepo = sharedContainer.resolveOrCrash(AgentRepository.self)
            availableAgents = try await agentRepo.listAll()
            
            let taskTypeRepo = sharedContainer.resolveOrCrash(TaskTypeRepository.self)
            let types = try await taskTypeRepo.listAll()
            availableTaskTypes = types.map { $0.name }
            
            if let firstType = availableTaskTypes.first {
                taskType = firstType
            }
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func createTask() async {
        do {
            guard let agentId = agentId else { return }
            
            // Validate JSON
            guard JSONUtils.isValidJSON(metadataJson) else {
                validationError = "Invalid JSON metadata"
                return
            }
            validationError = nil
            
            let task = TaskRecord(
                agentId: agentId,
                taskName: taskName,
                description: description,
                taskType: taskType,
                metadataJson: metadataJson,
                maxRetries: 3
            )
            
            let repository = sharedContainer.resolveOrCrash(TaskRepository.self)
            let taskId = try await repository.create(task: task)
            
            // Create schedule if enabled
            if hasSchedule {
                let scheduleRepo = sharedContainer.resolveOrCrash(TaskScheduleRepository.self)
                let compiler = ScheduleCompiler()
                let (cron, _) = compiler.compile(spec: schedule)
                
                let scheduleRecord = TaskScheduleRecord(
                    taskId: taskId,
                    scheduleKind: schedule.kind.rawValue,
                    schedulePayloadJson: schedule.toJSON() ?? "{}",
                    cronExpression: cron ?? "",
                    timezone: TimeZone.current.identifier,
                    nextRunAt: compiler.nextRunTime(spec: schedule),
                    isActive: true
                )
                _ = try await scheduleRepo.create(schedule: scheduleRecord)
            }
            
            EventBus.shared.refreshAllData()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct ScheduleSpecView: View {
    @Binding var schedule: ScheduleSpec
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Schedule Type", selection: $schedule.kind) {
                ForEach(ScheduleKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            
            switch schedule.kind {
            case .oneTime:
                if var oneTime = schedule.oneTime {
                    DatePicker("Date", selection: Binding(
                        get: { oneTime.date },
                        set: { oneTime.date = $0; schedule.oneTime = oneTime }
                    ))
                }
                
            case .daily:
                if var daily = schedule.daily {
                    DatePicker("Time", selection: Binding(
                        get: { daily.time },
                        set: { daily.time = $0; schedule.daily = daily }
                    ), displayedComponents: .hourAndMinute)
                    
                    Stepper("Every \(daily.interval) day(s)", value: Binding(
                        get: { daily.interval },
                        set: { daily.interval = $0; schedule.daily = daily }
                    ), in: 1...30)
                }
                
            case .weekly:
                if var weekly = schedule.weekly {
                    DatePicker("Time", selection: Binding(
                        get: { weekly.time },
                        set: { weekly.time = $0; schedule.weekly = weekly }
                    ), displayedComponents: .hourAndMinute)
                    
                    WeekdayPicker(selectedDays: Binding(
                        get: { weekly.days },
                        set: { weekly.days = $0; schedule.weekly = weekly }
                    ))
                }
                
            case .monthly:
                if var monthly = schedule.monthly {
                    DatePicker("Time", selection: Binding(
                        get: { monthly.time },
                        set: { monthly.time = $0; schedule.monthly = monthly }
                    ), displayedComponents: .hourAndMinute)
                    
                    Picker("Day", selection: Binding(
                        get: { monthly.day },
                        set: { monthly.day = $0; schedule.monthly = monthly }
                    )) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                }
                
            case .recurring:
                if var recurring = schedule.recurring {
                    HStack {
                        TextField("Minutes", value: Binding(
                            get: { recurring.minutes },
                            set: { recurring.minutes = $0; schedule.recurring = recurring }
                        ), format: .number)
                        .frame(width: 60)
                        
                        Text("min")
                        
                        TextField("Hours", value: Binding(
                            get: { recurring.hours },
                            set: { recurring.hours = $0; schedule.recurring = recurring }
                        ), format: .number)
                        .frame(width: 60)
                        
                        Text("hr")
                        
                        TextField("Days", value: Binding(
                            get: { recurring.days },
                            set: { recurring.days = $0; schedule.recurring = recurring }
                        ), format: .number)
                        .frame(width: 60)
                        
                        Text("day(s)")
                    }
                }
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selectedDays: [Int]
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<7) { index in
                let day = index + 1
                Button(weekdays[index]) {
                    if selectedDays.contains(day) {
                        selectedDays.removeAll { $0 == day }
                    } else {
                        selectedDays.append(day)
                    }
                    selectedDays.sort()
                }
                .buttonStyle(.bordered)
                .tint(selectedDays.contains(day) ? .blue : .gray)
            }
        }
    }
}

#Preview {
    NewTaskView()
}
