import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var store: DevDockStore

    var body: some View {
        let running = store.projects.filter { store.status(for: $0).isAlive }
        let managed = running.filter { store.status(for: $0) == .running }
        let external = running.filter { store.status(for: $0) == .external }
        let favorites = store.projects.filter(\.isFavorite).prefix(8)

        if store.isLaunchingWorkspace {
            Text(store.workspaceActivityMessage.isEmpty ? "Starting workspace…" : store.workspaceActivityMessage)
            Divider()
        }

        if !running.isEmpty {
            Text("Running · \(running.count)")
            ForEach(managed) { project in
                Button("● \(project.name)") {
                    reveal(project)
                }
                Button("    Stop") {
                    store.stop(project)
                }
            }
            ForEach(external) { project in
                Button("◐ \(project.name) (external)") {
                    reveal(project)
                }
                Button("    Stop Port") {
                    store.stop(project)
                }
            }
            if running.count > 1 {
                Button("Stop All Running") {
                    for project in running {
                        store.stop(project)
                    }
                }
            }
            Divider()
        }

        if !store.settings.workspaces.isEmpty {
            Text("Workspaces")
            if store.canUseWorkspaces {
                ForEach(store.settings.workspaces) { workspace in
                    let alive = store.workspaceAliveCount(workspace)
                    Button("Start \(workspace.name)") {
                        store.startWorkspace(workspace)
                    }
                    .disabled(store.isLaunchingWorkspace)
                    if alive > 0 {
                        Button("Stop \(workspace.name) (\(alive) up)") {
                            store.stopWorkspace(workspace)
                        }
                    }
                }
            } else {
                Button("Unlock Workspaces (Pro)") {
                    NSWorkspace.shared.open(LicenseLimits.buyURL)
                    activateApp()
                }
            }
            Divider()
        }

        if !favorites.isEmpty {
            Text("Favorites")
            ForEach(Array(favorites)) { project in
                Button(project.name) {
                    reveal(project)
                    store.start(project)
                }
            }
            Divider()
        }

        Button("Open DevDock") {
            activateApp()
        }

        Button("Rescan Projects") {
            store.rescan()
            activateApp()
        }

        Divider()

        Button("Quit DevDock") {
            NSApp.terminate(nil)
        }
    }

    private func reveal(_ project: DevProject) {
        store.selectedProjectID = project.id
        activateApp()
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
        // Prefer a normal window, not the status-item panel
        if let window = NSApp.windows.first(where: {
            $0.canBecomeMain && $0.level == .normal
        }) ?? NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
