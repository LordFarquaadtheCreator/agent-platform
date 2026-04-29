import Foundation
import Combine

@MainActor
public final class TaskFormViewModel: ObservableObject {
	@Published public var taskName: String = ""
	@Published public var taskTypeID: String = ""
	@Published public var agentID: String = ""
	@Published public var metadataJSON: String = "{\n  \"prompt\": \"\",\n  \"workflow\": \"\"\n}"
	@Published public var enableSchedule: Bool = false
	@Published var scheduleSelection: TaskScheduleSelection = .oneTime
	@Published public var oneTimeDate: Date = Date().addingTimeInterval(3600)
	@Published public var timeOfDay: Date = Date()
	@Published public var weekdays: Set<ScheduleSpec.Weekday> = [.monday]
	@Published public var monthDays: Set<Int> = [1]
	@Published public var timezone: String = TimeZone.current.identifier
	@Published public private(set) var isSaving: Bool = false
	@Published public private(set) var errorMessage: String?

	@Published public private(set) var creationContext = TaskCreationContext(agents: [], taskTypes: [])

	private let loadContextUseCase: LoadTaskCreationContextUseCase
	private let createTaskUseCase: CreateTaskUseCase
	private let onComplete: () async -> Void

	public init(
		loadContextUseCase: LoadTaskCreationContextUseCase,
		createTaskUseCase: CreateTaskUseCase,
		onComplete: @escaping () async -> Void
	) {
		self.loadContextUseCase = loadContextUseCase
		self.createTaskUseCase = createTaskUseCase
		self.onComplete = onComplete
	}

	public func loadCreationContext() async {
		do {
			creationContext = try await loadContextUseCase.execute()
			if taskTypeID.isEmpty {
				taskTypeID = creationContext.taskTypes.first?.id ?? ""
			}
			if agentID.isEmpty {
				agentID = creationContext.agents.first?.id ?? ""
			}
		} catch {
			errorMessage = error.localizedDescription
		}
	}

	public var canSave: Bool {
		!taskName.isEmpty && !taskTypeID.isEmpty && !agentID.isEmpty && !isSaving
	}

	public func save() async -> Bool {
		guard canSave else { return false }

		isSaving = true
		defer { isSaving = false }

		do {
			try await createTaskUseCase.execute(TaskDraft(
				agentId: agentID,
				taskTypeId: taskTypeID,
				taskName: taskName,
				metadataJSON: metadataJSON,
				schedule: buildSchedule()
			))
			await onComplete()
			return true
		} catch {
			errorMessage = error.localizedDescription
			return false
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

