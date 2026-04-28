import SwiftUI

// MARK: - App Input Field

struct AppInputField: View {
    let title: String?
    let placeholder: String
    @Binding var text: String
    let isMultiline: Bool
    let isSecure: Bool
    let height: CGFloat?
    init(
        title: String?,
        placeholder: String,
        text: Binding<String>,
        isMultiline: Bool = false,
        isSecure: Bool = false,
        height: CGFloat? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.isMultiline = isMultiline
        self.isSecure = isSecure
        self.height = height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
			if title != nil {
				AppText(title!, style: .headline)
					.padding(.horizontal, AppTheme.Spacing.xSmall)
			}
			
			
            inputField
                .padding(.horizontal, AppTheme.Spacing.xSmall)
                .padding(.vertical, AppTheme.Spacing.xSmall)
                .background(AppTheme.ColorToken.sectionBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
        }
    }

    @ViewBuilder
    private var inputField: some View {
        if isSecure {
            // swiftlint:disable:next unlabeled_input_field
            SecureField(placeholder, text: $text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if isMultiline {
            multilineField
        } else {
            singleLineField
        }
    }

    private var singleLineField: some View {
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

// MARK: - App Tag Input

struct AppTagInput: View {
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
            // swiftlint:disable:next unlabeled_input_field
            TextField("Add tag...", text: $currentInput)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit(addTag)

            Button("Add Tag", systemImage: "plus.circle.fill") {
                addTag()
            }
            .appButtonStyle(.plain)
            .foregroundStyle(AppTheme.ColorToken.accent)
            .disabled(currentInput.isEmpty)
            .labelStyle(.iconOnly)
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

// MARK: - Previews

#Preview("Field") {
    @Previewable @State var text = ""
    AppInputField(
        title: "Post Title",
        placeholder: "Enter title",
        text: $text
    )
    .padding()
}

#Preview("Empty Title") {
	@Previewable @State var text = ""
	AppInputField(
		title: nil,
		placeholder: "Enter title",
		text: $text
	)
	.padding()
}

#Preview("Field Multiline") {
    @Previewable @State var text = ""
    AppInputField(
        title: "Description",
        placeholder: "Enter description",
        text: $text,
        isMultiline: true,
        height: 100
    )
    .padding()
}

#Preview("Field Secure") {
    @Previewable @State var text = ""
    AppInputField(
        title: "Password",
        placeholder: "Enter password",
        text: $text,
        isSecure: true
    )
    .padding()
}

#Preview("Tag Input") {
    @Previewable @State var tags = ["art", "digital", "wip"]
    AppTagInput(
        title: "Tags",
        tags: $tags
    )
    .padding()
}

