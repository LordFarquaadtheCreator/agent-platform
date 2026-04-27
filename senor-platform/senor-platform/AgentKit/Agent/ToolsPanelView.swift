import SwiftUI


struct ToolsPanelView: View {
    let tools: [any AgentTool]

    @State private var expandedIndices: Set<Int> = []

    var body: some View {
        List(tools.indices, id: \.self) { index in
            Section {
                Button(action: {
                    if expandedIndices.contains(index) {
                        expandedIndices.remove(index)
                    } else {
                        expandedIndices.insert(index)
                    }
                }, label: {
                    HStack {
                        Image(systemName: expandedIndices.contains(index) ? "chevron.down" : "chevron.right")
                            .foregroundStyle(AppTheme.ColorToken.accent)
                        Text(type(of: tools[index]).toolName)
                            .foregroundStyle(AppTheme.ColorToken.textPrimary)
                        Spacer()
                    }
                })
                .buttonStyle(PlainButtonStyle())
                if expandedIndices.contains(index) {
                    let json = JSONEncoderHelper.encodeToJSONString(tools[index])
                    ?? "{\"error\": \"Unable to encode tool\"}"
                    MarkdownView(jsonMarkdown: JSONEncoderHelper.jsonCodeBlock(json))
                        .padding(.leading, 24)
                }
            }
        }
#if os(macOS)
        .listStyle(.plain)
#else
        .listStyle(.insetGrouped)
#endif
    }
}

private struct MarkdownView: View {
    let jsonMarkdown: String

    var body: some View {
        // Using Text with Markdown rendering for JSON display
        // This requires iOS 15+, macOS 12+ or later
        Text(.init(jsonMarkdown))
            .font(AppTheme.Typography.monospace)
            .padding(AppTheme.Spacing.xSmall)
            .background(AppTheme.ColorToken.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
    }
}
