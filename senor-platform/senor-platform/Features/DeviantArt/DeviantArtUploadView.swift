import SwiftUI
import UniformTypeIdentifiers

struct DeviantArtUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var formViewModel: DeviantArtUploadViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    fileSection
                    titleSection
                    tagsSection
                    commentsSection
                }
                .appScreenPadding()
            }
            .background(AppTheme.ColorToken.chromeBackground)
            .navigationTitle("Upload to Sta.sh")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        Task { await performUpload() }
                    }
                    .disabled(!formViewModel.canUpload)
                }
            }
        }
        .frame(minWidth: AppTheme.Layout.mediumSheetWidth, minHeight: AppTheme.Layout.mediumSheetHeight)
        .disabled(formViewModel.isUploading)
        .overlay {
            if formViewModel.isUploading {
                ProgressView("Uploading...")
                    .padding()
                    .background(AppTheme.ColorToken.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
            }
        }
        .toast(message: .init(
            get: { ToastState.shared.message },
            set: { ToastState.shared.message = $0 }
        ))
    }

    private var fileSection: some View {
        MediaPicker(
            title: "Artwork",
            selectedURLs: $formViewModel.selectedFileURLs
        )
    }

    private var titleSection: some View {
        AppInputField(
            title: "Title",
            placeholder: "Enter artwork title",
            text: $formViewModel.title
        )
    }

    private var tagsSection: some View {
        AppTagInput(
            title: "Tags",
            tags: $formViewModel.tags
        )
    }

    private var commentsSection: some View {
        AppInputField(
            title: "Artist Comments",
            placeholder: "Enter description or comments...",
            text: $formViewModel.artistComments,
            isMultiline: true,
            height: 120
        )
    }

    private func performUpload() async {
        let success = await formViewModel.upload()
        if success {
            dismiss()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("DeviantArt Upload") {
	let deviantArtVM = previewDeviantArtViewModel(deviationCount: 0)
	DeviantArtUploadView(
		formViewModel: DeviantArtUploadViewModel(
			viewModel: deviantArtVM,
			onComplete: {}
		)
	)
}
#endif
