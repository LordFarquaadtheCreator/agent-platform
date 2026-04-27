import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Global Toast State
// Simple singleton for showing toasts from anywhere

@MainActor
final class ToastState: ObservableObject {
    static let shared = ToastState()
    @Published var message: String?
}

private var aiHelperButton: some View {
	Button {
		ToastState.shared.message = "TODO: IMPLEMENT"
	} label: {
		HStack(spacing: AppTheme.Spacing.xSmall) {
			Image(systemName: "sparkles")
				.font(.caption2)
				.foregroundStyle(AppTheme.ColorToken.accent)
			AppText("AI", style: .caption2, color: AppTheme.ColorToken.accent)
		}
		.padding(.horizontal, AppTheme.Spacing.small)
		.padding(.vertical, AppTheme.Spacing.xSmall)
		.background(AppTheme.ColorToken.accent.opacity(0.1))
		.clipShape(Capsule())
	}
	.buttonStyle(.plain)
}

// MARK: - AI Helper Field
// Text input with AI generation trigger button

struct AIHelperField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isMultiline: Bool
    let height: CGFloat?
    
    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isMultiline: Bool = false,
        height: CGFloat? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.isMultiline = isMultiline
        self.height = height
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AppText(title, style: .headline)
            
            HStack(spacing: 0) {
                if isMultiline {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.ColorToken.textPrimary)
                            .frame(height: height ?? 120)
                        if text.isEmpty {
                            Text(placeholder)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.ColorToken.textSecondary)
                                .padding(.top, 4)
								.padding(.horizontal, 8)
                                .allowsHitTesting(false)
                        }
                    }
                } else {
                    TextField(placeholder, text: $text)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.ColorToken.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                aiHelperButton
            }
			.padding(.horizontal, AppTheme.Spacing.xSmall)
			.padding(.vertical, AppTheme.Spacing.xSmall)
            .background(AppTheme.ColorToken.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
        }
    }
}

// MARK: - AI Helper Tag Input

struct AIHelperTagInput: View {
    let title: String
    @Binding var tags: [String]
    @State private var currentInput: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppText(title, style: .headline)
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                tagDisplay
                inputRow
            }
            .padding(AppTheme.Spacing.small)
            .background(AppTheme.ColorToken.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
        }
    }
    
    private var tagDisplay: some View {
        FlowLayout(spacing: AppTheme.Spacing.xSmall) {
            ForEach(tags, id: \.self) { tag in
                TagChip(text: tag) {
                    tags.removeAll { $0 == tag }
                }
            }
        }
    }
    
    private var inputRow: some View {
        HStack {
            TextField("Add tag...", text: $currentInput)
				.font(AppTheme.Typography.body)
				.foregroundStyle(AppTheme.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit { addTag() }
            
            Button {
                addTag()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.ColorToken.accent)
            }
            .buttonStyle(.plain)
            .disabled(currentInput.isEmpty)
			
			aiHelperButton
        }
    }
    
    private func addTag() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        currentInput = ""
    }
}

// MARK: - Supporting Components

private struct TagChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            AppText(text, style: .caption)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .background(AppTheme.ColorToken.accent.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Media Picker

struct MediaPicker: View {
    let title: String
    @Binding var selectedURL: URL?
    @Binding var selectedURLs: [URL]
    let allowsMultiple: Bool
    let allowedContentTypes: [UTType]
    
    @State private var isImporting = false
    
    init(
        title: String,
        selectedURL: Binding<URL?>,
        allowedContentTypes: [UTType] = [.image]
    ) {
        self.title = title
        self._selectedURL = selectedURL
        self._selectedURLs = .constant([])
        self.allowsMultiple = false
        self.allowedContentTypes = allowedContentTypes
    }
    
    init(
        title: String,
        selectedURLs: Binding<[URL]>,
        allowedContentTypes: [UTType] = [.image]
    ) {
        self.title = title
        self._selectedURL = .constant(nil)
        self._selectedURLs = selectedURLs
        self.allowsMultiple = true
        self.allowedContentTypes = allowedContentTypes
    }
    
    private var hasSelection: Bool {
        selectedURL != nil || !selectedURLs.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppText(title, style: .headline)
            
            AppSurface(style: .flat) {
                VStack(spacing: AppTheme.Spacing.medium) {
                    if allowsMultiple {
                        if selectedURLs.isEmpty {
                            emptyState
                        } else {
                            multipleMediaView
                        }
                    } else if let url = selectedURL {
                        singleMediaView(url: url)
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: allowsMultiple
        ) { result in
            switch result {
            case .success(let urls):
                if allowsMultiple {
                    selectedURLs = urls
                } else if let first = urls.first {
                    selectedURL = first
                }
            case .failure(let error):
                ToastState.shared.message = "Failed to select file: \(error.localizedDescription)"
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.ColorToken.textSecondary)
            
            Button {
                isImporting = true
            } label: {
                Text(allowsMultiple ? "Select Files" : "Select File")
            }
            .appButtonStyle(.bordered)
        }
        .padding(AppTheme.Spacing.large)
    }
    
    private func singleMediaView(url: URL) -> some View {
        VStack(spacing: AppTheme.Spacing.small) {
            mediaThumbnail(url: url)
            AppText(url.lastPathComponent, style: .caption, color: AppTheme.ColorToken.textSecondary)
            
            HStack {
                Button {
                    selectedURL = nil
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
                .appButtonStyle(.bordered)
                
                Button {
                    isImporting = true
                } label: {
                    Label("Change", systemImage: "folder")
                }
                .appButtonStyle(.bordered)
            }
        }
        .padding(AppTheme.Spacing.small)
    }
    
    private var multipleMediaView: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            FlowLayout(spacing: AppTheme.Spacing.xSmall) {
                ForEach(selectedURLs, id: \.self) { url in
                    VStack(spacing: 2) {
                        mediaThumbnail(url: url)
                            .frame(width: 80, height: 80)
                        AppText(url.lastPathComponent, style: .caption2, color: AppTheme.ColorToken.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            
            HStack {
                Button {
                    selectedURLs.removeAll()
                } label: {
                    Label("Clear All", systemImage: "xmark")
                }
                .appButtonStyle(.bordered)
                
                Button {
                    isImporting = true
                } label: {
                    Label("Add More", systemImage: "folder")
                }
                .appButtonStyle(.bordered)
            }
        }
        .padding(AppTheme.Spacing.small)
    }
    
    private func mediaThumbnail(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
            default:
                Image(systemName: "doc")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)
            }
        }
    }
}

#Preview("Field") {
    @Previewable @State var text = ""
    AIHelperField(
        title: "Post Title",
        placeholder: "Enter title",
        text: $text
    )
    .padding()
}

#Preview("Field Multiline") {
    @Previewable @State var text = ""
    AIHelperField(
        title: "Description",
        placeholder: "Enter description",
        text: $text,
        isMultiline: true,
        height: 100
    )
    .padding()
}

#Preview("Tag Input") {
    @Previewable @State var tags = ["art", "digital", "wip"]
    AIHelperTagInput(
        title: "Tags",
        tags: $tags
    )
    .padding()
}

#Preview("Media Picker Single") {
    @Previewable @State var url: URL? = nil
    MediaPicker(
        title: "Media",
        selectedURL: $url
    )
	.frame(width: 300)
    .padding()
}

#Preview("Media Picker Multiple") {
    @Previewable @State var urls: [URL] = []
    MediaPicker(
        title: "Media",
        selectedURLs: $urls
    )
    .padding()
}
