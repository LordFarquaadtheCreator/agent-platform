import SwiftUI
import UniformTypeIdentifiers

// MARK: - AI Helper Field

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
                inputField
                AIHelperButton()
            }
            .padding(.horizontal, AppTheme.Spacing.xSmall)
            .padding(.vertical, AppTheme.Spacing.xSmall)
            .background(AppTheme.ColorToken.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
        }
    }

    @ViewBuilder
    private var inputField: some View {
        if isMultiline {
            multilineField
        } else {
            singleLineField
        }
    }

    private var singleLineField: some View {
        // Label provided by parent AIHelperField via `title` property
        // swiftlint:disable:next unlabeled_input_field
        TextField(placeholder, text: $text)
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.ColorToken.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var multilineField: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.ColorToken.textPrimary)
                .frame(height: height ?? 120)

            if text.isEmpty {
                placeholderOverlay
            }
        }
    }

    private var placeholderOverlay: some View {
        Text(placeholder)
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.ColorToken.textSecondary)
            .padding(.top, 4)
            .padding(.horizontal, 8)
            .allowsHitTesting(false)
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
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                TagChip(text: tag) {
                    tags.remove(at: index)
                }
            }
        }
    }

    private var inputRow: some View {
        HStack {
            // Tag input has contextual label from surrounding UI
            // swiftlint:disable:next unlabeled_input_field
            TextField("Add tag...", text: $currentInput)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit(addTag)

            Button(action: addTag) {
                Text("Add Tag")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.ColorToken.accent)
            }
            .disabled(currentInput.isEmpty)
            .labelStyle(.iconOnly)

            AIHelperButton()
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

// MARK: - AI Helper Button

private struct AIHelperButton: View {
    var body: some View {
        Button("AI Helper", systemImage: "sparkles") {
            // AI helper: see AgentKit for tool protocol
        }
        .buttonStyle(.plain)
        .labelStyle(AIHelperLabelStyle())
    }
}

private struct AIHelperLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            configuration.icon
                .font(AppTheme.Typography.caption2)
            configuration.title
                .font(AppTheme.Typography.caption2)
        }
        .foregroundStyle(AppTheme.ColorToken.accent)
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .background(AppTheme.ColorToken.accent.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            AppText(text, style: .caption)
            Button("Remove", systemImage: "xmark.circle.fill", action: onRemove)
                .buttonStyle(.plain)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.ColorToken.textSecondary)
                .labelStyle(.iconOnly)
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

	@Environment(\.privacyMode) private var isPrivacyMode
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

	var body: some View {
		VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
			AppText(title, style: .headline)

			AppSurface(style: .flat) {
				content
					.frame(maxWidth: .infinity)
			}
		}
		.fileImporter(
			isPresented: $isImporting,
			allowedContentTypes: allowedContentTypes,
			allowsMultipleSelection: allowsMultiple
		) { handleFileImport($0) }
	}

	@ViewBuilder
	private var content: some View {
		if allowsMultiple {
			multipleContent
		} else {
			singleContent
		}
	}

	@ViewBuilder
	private var singleContent: some View {
		if let url = selectedURL {
			singleMediaView(url: url)
		} else {
			emptyState
		}
	}

	@ViewBuilder
	private var multipleContent: some View {
		if selectedURLs.isEmpty {
			emptyState
		} else {
			multipleMediaView
		}
	}

	private var emptyState: some View {
		VStack(spacing: AppTheme.Spacing.medium) {
			Image(systemName: "photo")
				.font(AppTheme.Typography.metricValue)
				.foregroundStyle(AppTheme.ColorToken.textSecondary)

			Button(allowsMultiple ? "Select Files" : "Select File") {
				isImporting = true
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
				Button("Clear", systemImage: "xmark") {
					selectedURL = nil
				}
				.appButtonStyle(.bordered)

				Button("Change", systemImage: "folder") {
					isImporting = true
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
					mediaItem(url: url)
				}
			}

			HStack {
				Button("Clear All", systemImage: "xmark") {
					selectedURLs.removeAll()
				}
				.appButtonStyle(.bordered)

				Button("Add More", systemImage: "folder") {
					isImporting = true
				}
				.appButtonStyle(.bordered)
			}
		}
		.padding(AppTheme.Spacing.small)
	}

	private func mediaItem(url: URL) -> some View {
		VStack(spacing: 2) {
			mediaThumbnail(url: url)
				.frame(width: 80, height: 80)
			AppText(url.lastPathComponent, style: .caption2, color: AppTheme.ColorToken.textSecondary)
				.lineLimit(1)
		}
	}

	private func mediaThumbnail(url: URL) -> some View {
	    AsyncImage(url: url) { phase in
	        switch phase {
	        case .empty:
	            ProgressView()
	                .frame(maxWidth: .infinity, maxHeight: 200)
	        case .success(let image):
	            image
	                .resizable()
	                .scaledToFit()
	                .blur(radius: isPrivacyMode ? 20 : 0)
	                .frame(maxHeight: 200)
	        case .failure:
	            Image(systemName: "photo")
	                .resizable()
	                .scaledToFit()
	                .foregroundStyle(AppTheme.ColorToken.textSecondary)
	                .frame(maxHeight: 200)
	        @unknown default:
	            ProgressView()
	                .frame(maxWidth: .infinity, maxHeight: 200)
	        }
	    }
	}

	private func handleFileImport(_ result: Result<[URL], Error>) {
		switch result {
		case .success(let urls):
			if allowsMultiple {
				selectedURLs = urls
			} else if let first = urls.first {
				selectedURL = first
			}

		case .failure:
			break
		}
	}
}

// MARK: - Previews

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

#Preview("Media Picker") {
    @Previewable @State var url: URL?
    MediaPicker(
        title: "Media",
        selectedURL: $url
    )
    .frame(width: 400)
    .padding()
}

