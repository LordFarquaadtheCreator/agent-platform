import SwiftUI
import Foundation

@main
struct senor_platformApp: App {
    @StateObject private var appState = AppShellModel()

    var body: some Scene {
        Window("Senor Platform", id: "main") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: AppTheme.Layout.windowMinWidth, minHeight: AppTheme.Layout.windowMinHeight)
        }
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["senorplatform"])
        .commands {
            CommandMenu("Agents") {
                Button("New Agent") {
                    appState.present(.newAgent)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Tasks") {
                Button("New Task") {
                    appState.present(.newTask)
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Refresh") {
                    Task { await appState.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("Settings") {
                Button("Open Settings") {
                    appState.present(.settings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

