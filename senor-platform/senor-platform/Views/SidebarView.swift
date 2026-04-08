//
//  SidebarView.swift
//  senor-platform
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // App Title
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                Text("SenorPlatform")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(.background)

            Divider()

            // Navigation List
            List(selection: $viewModel.selectedMainView) {
                Section("Overview") {
                    NavigationLink(value: MainView.dashboard) {
                        Label("Dashboard", systemImage: MainView.dashboard.icon)
                    }
                }

                Section("Management") {
                    NavigationLink(value: MainView.agents) {
                        Label("Agents", systemImage: MainView.agents.icon)
                    }

                    NavigationLink(value: MainView.tasks) {
                        Label("Tasks", systemImage: MainView.tasks.icon)
                    }

                    NavigationLink(value: MainView.content) {
                        Label("Content", systemImage: MainView.content.icon)
                    }
                }

                Section("Workflow") {
                    NavigationLink(value: MainView.approvals) {
                        Label {
                            Text("Approvals")
                        } icon: {
                            ZStack {
                                Image(systemName: MainView.approvals.icon)
                                if viewModel.pendingApprovals.count > 0 {
                                    Text("\(viewModel.pendingApprovals.count)")
                                        .font(.caption2)
                                        .padding(4)
                                        .background(Color.red)
                                        .foregroundStyle(.white)
                                        .clipShape(Circle())
                                        .offset(x: 10, y: -10)
                                }
                            }
                        }
                    }
                }

                Section("Configuration") {
                    NavigationLink(value: MainView.settings) {
                        Label("Settings", systemImage: MainView.settings.icon)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Quick Actions
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    appState.showNewAgentSheet = true
                } label: {
                    Label("New Agent", systemImage: "plus")
                }
                .buttonStyle(.borderless)

                Button {
                    appState.showNewTaskSheet = true
                } label: {
                    Label("New Task", systemImage: "plus.square")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 200)
    }
}

#Preview("Sidebar - Empty") {
    SidebarView(viewModel: ContentViewModel())
        .environmentObject(AppState())
        .frame(width: 250)
}

#Preview("Sidebar - With Approvals") {
    let viewModel = ContentViewModel()
    viewModel.pendingApprovals = [
        ApprovalViewModel(id: "1", contentId: "1", contentTitle: "Item 1", previewImage: nil, submittedAt: Date(), agentName: "Agent 1"),
        ApprovalViewModel(id: "2", contentId: "2", contentTitle: "Item 2", previewImage: nil, submittedAt: Date(), agentName: "Agent 2")
    ]
    return SidebarView(viewModel: viewModel)
        .environmentObject(AppState())
        .frame(width: 250)
}

#Preview("Sidebar - Dark Mode") {
    SidebarView(viewModel: ContentViewModel())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
        .frame(width: 250)
}
