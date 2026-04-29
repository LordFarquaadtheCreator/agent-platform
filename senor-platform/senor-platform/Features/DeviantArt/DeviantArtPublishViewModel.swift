import Foundation
import Combine

@MainActor
public final class DeviantArtPublishViewModel: ObservableObject {
	@Published public var title: String = ""
	@Published public var category: String = ""
	@Published public var isMature: Bool = false
	@Published public var matureLevel: String = ""
	@Published public var allowsComments: Bool = true
	@Published public private(set) var isPublishing: Bool = false
	@Published public private(set) var errorMessage: String?

	public let stashItem: DeviantArtClient.StashItem
	private let viewModel: DeviantArtViewModel
	private let onComplete: () -> Void

	public var canPublish: Bool {
		!title.isEmpty && !category.isEmpty && !isPublishing
	}

	public init(
		viewModel: DeviantArtViewModel,
		stashItem: DeviantArtClient.StashItem,
		onComplete: @escaping () -> Void
	) {
		self.viewModel = viewModel
		self.stashItem = stashItem
		self.onComplete = onComplete
		self.title = stashItem.title
	}

	public func publish() async -> Bool {
		guard canPublish else { return false }

		isPublishing = true
		defer { isPublishing = false }

		do {
			try await viewModel.publishFromStash(
				stashId: stashItem.itemid,
				title: title,
				category: category.isEmpty ? nil : category,
				isMature: isMature,
				matureLevel: matureLevel.isEmpty ? nil : matureLevel,
				allowsComments: allowsComments
			)
			onComplete()
			return true
		} catch {
			errorMessage = error.localizedDescription
			return false
		}
	}
}

