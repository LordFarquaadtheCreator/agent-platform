import Foundation
import Combine

@MainActor
public final class PatreonComposeViewModel: ObservableObject {
	@Published public var title: String = ""
	@Published public var content: String = ""
	@Published public var isPaid: Bool = true
	@Published public var isPublic: Bool = false
	@Published public var selectedTiers: Set<String> = []
	@Published public var mediaURLs: [URL] = []
	@Published public private(set) var isSaving: Bool = false
	@Published public private(set) var errorMessage: String?

	public let viewModel: PatreonViewModel
	private let editingPost: PatreonPost?
	private let onComplete: () -> Void

	public var isEditing: Bool { editingPost != nil }

	public init(
		viewModel: PatreonViewModel,
		editingPost: PatreonPost? = nil,
		onComplete: @escaping () -> Void
	) {
		self.viewModel = viewModel
		self.editingPost = editingPost
		self.onComplete = onComplete

		if let post = editingPost {
			self.title = post.attributes.title ?? ""
			self.content = post.attributes.content ?? ""
			self.isPaid = post.attributes.isPaid ?? true
			self.isPublic = post.attributes.isPublic ?? false
			if let tierData = post.relationships?.tiers?.data {
				self.selectedTiers = Set(tierData.map(\.id))
			}
		}
	}

	public var canSave: Bool {
		!title.isEmpty && !content.isEmpty && !isSaving
	}

	public func save() async -> Bool {
		guard canSave else { return false }

		isSaving = true
		defer { isSaving = false }

		do {
			if isEditing, let post = editingPost {
				try await viewModel.updatePost(
					postId: post.id,
					title: title,
					content: content,
					isPaid: isPaid,
					isPublic: isPublic
				)
			} else {
				try await viewModel.createPost(
					title: title,
					content: content,
					isPaid: isPaid,
					isPublic: isPublic,
					tiers: Array(selectedTiers)
				)
			}
			onComplete()
			return true
		} catch {
			errorMessage = error.localizedDescription
			return false
		}
	}
}

