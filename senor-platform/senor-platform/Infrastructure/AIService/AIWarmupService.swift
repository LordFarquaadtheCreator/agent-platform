import Foundation

// MARK: - AI Warmup Service

/// Service to warm up the AI model on app launch
/// Prevents cold-start latency on first user message
@MainActor
public final class AIWarmupService {
	private let aiClient: AIClient
	private let settingsService: SettingsService
	private let logger = AppLogger.general

	public init(aiClient: AIClient, settingsService: SettingsService) {
		self.aiClient = aiClient
		self.settingsService = settingsService
	}

	/// Perform warmup ping if enabled in settings
	/// Silently fails - don't block app launch on AI issues
	public func warmupIfNeeded() async {
		let settings = settingsService.loadAISettings()

		guard settings.warmupOnLaunch else {
			logger.info("AI warmup skipped (disabled)")
			return
		}

		guard !settings.model.isEmpty else {
			logger.info("AI warmup skipped (no model configured)")
			return
		}

		logger.info("Starting AI warmup...")

		do {
			let response = try await aiClient.chat(
				input: "hi",
				model: settings.model,
				temperature: 0.7,
				stream: false
			)
			logger.info("AI warmup completed, responseID: \(response.id)")
		} catch {
			logger.warning("AI warmup failed (non-critical): \(error.localizedDescription)")
		}
	}
}
