import SwiftUI
import UniformTypeIdentifiers

struct DeviantArtUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DeviantArtViewModel
    
    @State private var title: String = ""
    @State private var tags: [String] = []
    @State private var artistComments: String = ""
    @State private var selectedFileURLs: [URL] = []
    @State private var isUploading = false
    
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
                        performUpload()
                    }
                    .disabled(!canUpload)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
        .disabled(isUploading)
        .overlay {
            if isUploading {
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
            selectedURLs: $selectedFileURLs
        )
    }
    
    private var titleSection: some View {
        AIHelperField(
            title: "Title",
            placeholder: "Enter artwork title",
            text: $title
        )
    }
    
    private var tagsSection: some View {
        AIHelperTagInput(
            title: "Tags",
            tags: $tags
        )
    }
    
    private var commentsSection: some View {
        AIHelperField(
            title: "Artist Comments",
            placeholder: "Enter description or comments...",
            text: $artistComments,
            isMultiline: true,
            height: 120
        )
    }
    
    private var canUpload: Bool {
        !title.isEmpty && !selectedFileURLs.isEmpty
    }

    private func performUpload() {
        guard let fileURL = selectedFileURLs.first else { return }
        
        isUploading = true
        Task {
            do {
                try await viewModel.uploadToStash(
                    fileURL: fileURL,
                    title: title,
                    tags: tags.isEmpty ? nil : tags,
                    artistComments: artistComments.isEmpty ? nil : artistComments
                )
                await MainActor.run {
                    isUploading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    ToastState.shared.message = "Upload failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
