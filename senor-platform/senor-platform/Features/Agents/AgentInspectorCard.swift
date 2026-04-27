import SwiftUI

struct AgentInspectorCard: View {
    let agent: Agent

    var body: some View {
        AppCard {
            AppVStack(spacing: .medium, alignment: .leading) {
                AppText(agent.displayName, style: .title3)
                AppStatusPill(
                    title: agent.status.displayName,
                    color: StatusColor.from(agent.status.rawValue).swiftUIColor
                )
                AppDivider()
                LabeledContent("Tasks", value: "\(agent.taskCount)")
                LabeledContent("Created", value: agent.createdAt.formatted())
                LabeledContent("Updated", value: agent.updatedAt.formatted())
            }
        }
    }
}
