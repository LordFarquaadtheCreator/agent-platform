import SwiftUI

struct ToolsHostView: View {
    // Build the tool instances from the registered tool types
    private let tools: [any AgentTool] = AgentKit.toolTypes.map { $0.init() }

    var body: some View {
        NavigationStack {
            ToolsPanelView(tools: tools)
                .navigationTitle("Tools")
        }
    }
}

#Preview {
    ToolsHostView()
}
