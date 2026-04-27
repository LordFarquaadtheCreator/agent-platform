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
                            .foregroundColor(.accentColor)
                        Text(type(of: tools[index]).toolName)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                })
                .buttonStyle(PlainButtonStyle())
                if expandedIndices.contains(index) {
                    let json = JSONEncoderHelper.encodeToJSONString(tools[index]) ?? "{\n  \"error\": \"Unable to encode tool\"\n}"
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
            .font(.system(.body, design: .monospaced))
            .padding(4)
            .background(.secondary.opacity(0.1))
            .cornerRadius(6)
    }
}
