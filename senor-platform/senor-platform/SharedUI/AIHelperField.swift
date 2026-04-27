import SwiftUI

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
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppText(title, style: .headline)
            
            VStack(spacing: 0) {
                if isMultiline {
                    TextEditor(text: $text)
                        .font(AppTheme.Typography.body)
                        .frame(height: height ?? 120)
                        .padding(AppTheme.Spacing.small)
                } else {
                    TextField(placeholder, text: $text)
                        .font(AppTheme.Typography.body)
                        .padding(AppTheme.Spacing.small)
                }
                
                aiHelperBar
            }
            .background(AppTheme.ColorToken.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
        }
    }
    
    private var aiHelperBar: some View {
        HStack {
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
            
            Button {
                ToastManager.shared.show(message: "TODO: IMPLEMENT")
            } label: {
                AppText("Generate with AI", style: .caption, color: AppTheme.ColorToken.accent)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .background(AppTheme.ColorToken.cardBackground)
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
                aiHelperBar
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
            
            Button {
                addTag()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.ColorToken.accent)
            }
            .buttonStyle(.plain)
            .disabled(currentInput.isEmpty)
        }
    }
    
    private var aiHelperBar: some View {
        HStack {
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
            
            Button {
                ToastManager.shared.show(message: "TODO: IMPLEMENT")
            } label: {
                AppText("Generate tags with AI", style: .caption, color: AppTheme.ColorToken.accent)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .background(AppTheme.ColorToken.cardBackground)
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

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Media Picker

struct MediaPicker: View {
    let title: String
    @Binding var selectedURL: URL?
    let onPick: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppText(title, style: .headline)
            
            AppSurface(style: .flat) {
                VStack(spacing: AppTheme.Spacing.medium) {
                    if let url = selectedURL {
                        selectedMediaView(url: url)
                    } else {
                        emptyState
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.ColorToken.textSecondary)
            
            Button {
                onPick()
            } label: {
                Label("Select File", systemImage: "folder")
            }
            .appButtonStyle(.bordered)
        }
        .padding(AppTheme.Spacing.large)
    }
    
    private func selectedMediaView(url: URL) -> some View {
        VStack(spacing: AppTheme.Spacing.small) {
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
            
            AppText(url.lastPathComponent, style: .caption, color: AppTheme.ColorToken.textSecondary)
            
            HStack {
                Button {
                    selectedURL = nil
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
                .appButtonStyle(.bordered)
                
                Button {
                    onPick()
                } label: {
                    Label("Change", systemImage: "folder")
                }
                .appButtonStyle(.bordered)
            }
        }
        .padding(AppTheme.Spacing.small)
    }
}
