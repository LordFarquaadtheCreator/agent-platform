import Foundation
import Combine

@MainActor
public final class DeviantArtUploadViewModel: ObservableObject {
	@Published public var title: String = ""
	@Published public var tags: [String] = []
	@Published public var artistComments: String = ""
	@Published public var selectedFileURLs: [URL] = []
	@Published public private(set) var isUploading: Bool = false
	@Published public private(set) var errorMessage: String?

	private let viewModel: DeviantArtViewModel
	private let onComplete: () -> Void

	public var canUpload: Bool {
		!title.isEmpty && !selectedFileURLs.isEmpty && !isUploading
	}

	public init(
		viewModel: DeviantArtViewModel,
		onComplete: @escaping () -> Void
	) {
		self.viewModel = viewModel
		self.onComplete = onComplete
	}

	public func upload() async -> Bool {
		guard canUpload, let fileURL = selectedFileURLs.first else { return false }

		isUploading = true
		defer { isUploading = false }

		do {
			try await viewModel.uploadToStash(
				fileURL: fileURL,
				title: title,
				tags: tags.isEmpty ? nil : tags,
				artistComments: artistComments.isEmpty ? nil : artistComments
			)
			onComplete()
			return true
		} catch {
			errorMessage = error.localizedDescription
			return false
		}
	}
}

