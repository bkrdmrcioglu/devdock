import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var store: DevDockStore
    @EnvironmentObject private var processes: ProcessManager

    var body: some View {
        let running = store.projects.filter { store.status(for: $0).isAlive }
        let managed = running.filter { store.status(for: $0) == .running }
        let external = running.filter { store.status(for: $0) == .external }
        let favorites = store.projects.filter(\.isFavorite).prefix(8)
        let readyCount = running.filter { processes.portHealth(for: $0.id) == .ready }.count

        if store.isLaunchingWorkspace {
            Text(store.workspaceActivityMessage.isEmpty ? "Starting workspace…" : store.workspaceActivityMessage)
            Divider()
        }

        if !running.isEmpty {
            Text(readyCount > 0 ? "Running · \(running.count) · \(readyCount) ready" : "Running · \(running.count)")
            ForEach(managed) { project in
                let mark = processes.portHealth(for: project.id) == .ready ? "●" : "…"
                Button("\(mark) \(project.name)") {
                    reveal(project)
                }
                Button("    Stop") {
                    store.stop(project)
                }
            }
            ForEach(external) { project in
                let mark = processes.portHealth(for: project.id) == .ready ? "●" : "◐"
                Button("\(mark) \(project.name) (external)") {
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
            if let morning = store.morningRoutine {
                Button("☀ Morning · \(morning.name)") {
                    store.startMorningRoutine()
                }
                .disabled(store.isLaunchingWorkspace)
            }
            ForEach(store.settings.workspaces) { workspace in
                let alive = store.workspaceAliveCount(workspace)
                let prefix = workspace.isMorningRoutine ? "☀ " : ""
                Button("\(prefix)Start \(workspace.name)") {
                    store.startWorkspace(workspace)
                }
                .disabled(store.isLaunchingWorkspace)
                if alive > 0 {
                    Button("Stop \(workspace.name) (\(alive) up)") {
                        store.stopWorkspace(workspace)
                    }
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
