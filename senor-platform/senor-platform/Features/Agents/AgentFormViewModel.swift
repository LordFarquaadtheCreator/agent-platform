import Foundation
import Combine

@MainActor
public final class AgentFormViewModel: ObservableObject {
	@Published public var displayName: String = ""
	@Published public var description: String = ""
	@Published public var workerScriptPath: String = ""
	@Published public var configJSON: String = "{}"
	@Published public var isActive: Bool = true
	@Published public private(set) var isSaving: Bool = false
	@Published public private(set) var errorMessage: String?

	private let createAgentUseCase: CreateAgentUseCase
	private let onComplete: () async -> Void

	public init(
		createAgentUseCase: CreateAgentUseCase,
		onComplete: @escaping () async -> Void
	) {
		self.createAgentUseCase = createAgentUseCase
		self.onComplete = onComplete
	}

	public var canSave: Bool {
		!displayName.isEmpty && !workerScriptPath.isEmpty && !isSaving
	}

	public func save() async -> Bool {
		guard canSave else { return false }

		isSaving = true
		defer { isSaving = false }

		do {
			_ = try await createAgentUseCase.execute(AgentDraft(
				displayName: displayName,
				isActive: isActive,
				description: description,
				workerScriptPath: workerScriptPath,
				configJSON: configJSON
			))
			await onComplete()
			return true
		} catch {
			errorMessage = error.localizedDescription
			return false
		}
	}
}

