import SwiftUI

protocol AgentTool {
    var id: UUID { get }
    var name: String { get }
}

struct SampleAgentTool: AgentTool, Identifiable {
    let id = UUID()
    let name: String
}

struct ToolsPanelView: View {
    let tools: [any AgentTool]

    var body: some View {
        List(tools, id: \.id) { tool in
            Text(tool.name)
        }
        .navigationTitle("Tools")
    }
}

struct ToolsHostView: View {
    enum SidebarItem: String, Identifiable, CaseIterable {
        case tools = "Tools"
        var id: String { rawValue }
    }

    @State private var selection: SidebarItem? = .tools

    let tools: [any AgentTool] = [
        SampleAgentTool(name: "Tool 1"),
        SampleAgentTool(name: "Tool 2"),
        SampleAgentTool(name: "Tool 3")
    ]

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Text(item.rawValue)
            }
            .navigationTitle("Sidebar")
        } detail: {
            if selection == .tools {
                ToolsPanelView(tools: tools)
            } else {
                Text("Select an item")
            }
        }
    }
}

#Preview {
    ToolsHostView()
}
