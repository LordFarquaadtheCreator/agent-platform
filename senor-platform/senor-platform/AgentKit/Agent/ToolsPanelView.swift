import SwiftUI

#if canImport(AgentToolModule)
#else
protocol AgentTool {
    var name: String { get }
}
#endif

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
                }) {
                    HStack {
                        Image(systemName: expandedIndices.contains(index) ? "chevron.down" : "chevron.right")
                            .foregroundColor(.accentColor)
                        Text(tools[index].name)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                if expandedIndices.contains(index) {
                    MarkdownView(jsonMarkdown: ToolJSONEncoder.jsonMarkdown(from: tools[index]))
                        .padding(.leading, 24)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

fileprivate struct MarkdownView: View {
    let jsonMarkdown: String

    var body: some View {
        // Using Text with Markdown rendering for JSON display
        // This requires iOS 15+, macOS 12+ or later
        Text(.init(jsonMarkdown))
            .font(.system(.body, design: .monospaced))
            .padding(4)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(6)
    }
}

fileprivate struct ToolJSONEncoder {
    /// Produces a JSON string encoded as Markdown code block for display.
    static func jsonMarkdown(from tool: any AgentTool) -> String {
        guard let data = try? JSONEncoder().encode(AnyEncodable(tool)),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            return "```json\n{ \"error\": \"Unable to encode tool\" }\n```"
        }
        return "```json\n\(jsonString)\n```"
    }

    /// A type-erased Encodable wrapper to encode any AgentTool.
    private struct AnyEncodable: Encodable {
        private let encodeFunc: (Encoder) throws -> Void

        init(_ value: any AgentTool) {
            if let encodable = value as? Encodable {
                encodeFunc = encodable.encode
            } else {
                encodeFunc = { encoder in
                    var container = encoder.singleValueContainer()
                    try container.encode(value.name)
                }
            }
        }

        func encode(to encoder: Encoder) throws {
            try encodeFunc(encoder)
        }
    }
}
