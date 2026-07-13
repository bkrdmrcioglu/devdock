import SwiftUI

@main
struct DevDockApp: App {
    @StateObject private var store = DevDockStore()
    @State private var showAbout = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(store.processManager)
                .environmentObject(store.licenseManager)
                .frame(minWidth: 980, minHeight: 620)
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About DevDock") {
                    showAbout = true
                }
            }
            CommandMenu("Projects") {
                Button("Command Palette") {
                    store.showCommandPalette = true
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Rescan Folders") {
                    store.rescan()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("Stop All Running") {
                    for project in store.projects where store.status(for: project).isAlive {
                        store.stop(project)
                    }
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])
            }

            CommandMenu("Workspaces") {
                if store.morningRoutine != nil {
                    Button("Start Morning Routine") {
                        store.startMorningRoutine()
                    }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                    Divider()
                }
                ForEach(store.settings.workspaces) { workspace in
                    Button("Start \(workspace.name)") {
                        store.startWorkspace(workspace)
                    }
                }
                if store.settings.workspaces.isEmpty {
                    Text("No workspaces yet")
                }
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(store.processManager)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: store.runningCount > 0 ? "shippingbox.fill" : "shippingbox")
                if store.runningCount > 0 {
                    Text("\(store.runningCount)")
                } else if store.isLaunchingWorkspace {
                    Text("…")
                }
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct RootView: View {
    @EnvironmentObject private var store: DevDockStore

    var body: some View {
        Group {
            if store.showOnboarding {
                OnboardingView()
            } else {
                ContentView()
            }
        }
        .background(DevDockTheme.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
