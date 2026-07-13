import SwiftUI

struct CommandPaletteOverlay: View {
    @EnvironmentObject private var store: DevDockStore
    @EnvironmentObject private var processes: ProcessManager
    @State private var query = ""
    @FocusState private var queryFocused: Bool

    var body: some View {
        ZStack {
            if store.showCommandPalette {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DevDockTheme.mist)
                        TextField("Search projects or actions…", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .medium))
                            .focused($queryFocused)
                            .onSubmit { runTopHit() }
                        ShortcutKeyCap(AppShortcuts.palette)
                        ShortcutKeyCap("esc")
                    }
                    .padding(14)

                    Divider().overlay(DevDockTheme.line)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            sectionLabel("Actions")
                            ForEach(filteredActions) { action in
                                paletteRow(
                                    icon: action.icon,
                                    title: action.title,
                                    subtitle: action.subtitle,
                                    shortcut: action.shortcut,
                                    tint: action.tint
                                ) {
                                    action.run()
                                    close()
                                }
                            }

                            if !filteredProjects.isEmpty {
                                sectionLabel("Projects · Enter to open / Start")
                                ForEach(filteredProjects) { project in
                                    let st = store.status(for: project)
                                    let health = processes.portHealth(for: project.id)
                                    paletteRow(
                                        icon: "shippingbox",
                                        title: project.name,
                                        subtitle: projectSubtitle(project, status: st, health: health),
                                        shortcut: nil,
                                        tint: DevDockTheme.accent
                                    ) {
                                        store.selectedProjectID = project.id
                                        if st == .offline || st == .error {
                                            store.start(project)
                                        }
                                        close()
                                    }
                                }
                            }

                            if filteredActions.isEmpty && filteredProjects.isEmpty {
                                Text("No matches")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DevDockTheme.mist)
                                    .padding(16)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 360)
                }
                .frame(width: 520)
                .background(DevDockTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DevDockTheme.line, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 28, y: 12)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: store.showCommandPalette)
        .onChange(of: store.showCommandPalette) { _, open in
            if open {
                query = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    queryFocused = true
                }
            }
        }
        .onExitCommand {
            if store.showCommandPalette { close() }
        }
    }

    private struct PaletteAction: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let shortcut: String?
        let icon: String
        let tint: Color
        let run: () -> Void
    }

    private var filteredActions: [PaletteAction] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all: [PaletteAction] = [
            PaletteAction(
                id: "updates",
                title: "Check for Updates",
                subtitle: store.availableUpdate.map { "\($0.version) available" } ?? "GitHub Releases",
                shortcut: nil,
                icon: "arrow.down.circle",
                tint: DevDockTheme.accent
            ) { store.checkForUpdates(silent: false) },
            PaletteAction(
                id: "rescan",
                title: "Rescan Folders",
                subtitle: "Refresh scanned project folders",
                shortcut: AppShortcuts.rescan,
                icon: "arrow.clockwise",
                tint: DevDockTheme.accent
            ) { store.rescan() },
            PaletteAction(
                id: "morning",
                title: "Start Morning Routine",
                subtitle: store.morningRoutine.map(\.name) ?? "Mark one in Workspaces",
                shortcut: AppShortcuts.morning,
                icon: "sun.max.fill",
                tint: DevDockTheme.warn
            ) { store.startMorningRoutine() },
            PaletteAction(
                id: "stop-all",
                title: "Stop All Running",
                subtitle: "Stop every live stack",
                shortcut: AppShortcuts.stopAll,
                icon: "stop.fill",
                tint: DevDockTheme.danger
            ) {
                for project in store.projects where store.status(for: project).isAlive {
                    store.stop(project)
                }
            },
            PaletteAction(
                id: "workspaces",
                title: "Manage Workspaces…",
                subtitle: "Group stacks · morning routine",
                shortcut: nil,
                icon: "square.stack.3d.up",
                tint: DevDockTheme.mist
            ) { store.showWorkspaceEditorFromPalette = true },
            PaletteAction(
                id: "whats-new",
                title: "What’s new",
                subtitle: "Release notes & shortcuts",
                shortcut: nil,
                icon: "sparkles",
                tint: DevDockTheme.accent
            ) { store.showWhatsNewFromPalette = true },
        ]

        guard !q.isEmpty else { return all }
        return all.filter {
            $0.title.lowercased().contains(q)
                || $0.subtitle.lowercased().contains(q)
                || ($0.shortcut?.lowercased().contains(q) ?? false)
        }
    }

    private var filteredProjects: [DevProject] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = store.projects
        guard !q.isEmpty else {
            return Array(base.prefix(12))
        }
        return base.filter {
            $0.name.lowercased().contains(q)
                || $0.framework.rawValue.lowercased().contains(q)
                || $0.path.lowercased().contains(q)
        }.prefix(20).map { $0 }
    }

    private func projectSubtitle(_ project: DevProject, status: ProjectStatus, health: PortHealth) -> String {
        var parts = [project.framework.rawValue, status.rawValue]
        if status == .running || status == .external {
            parts.append(health.label)
        }
        if let port = processes.effectivePort(for: project) {
            parts.append(":\(port)")
        }
        return parts.joined(separator: " · ")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DevDockTheme.mist)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private func paletteRow(
        icon: String,
        title: String,
        subtitle: String,
        shortcut: String?,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DevDockTheme.chalk)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(DevDockTheme.mist)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let shortcut {
                    ShortcutKeyCap(shortcut)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func runTopHit() {
        if let action = filteredActions.first {
            action.run()
            close()
            return
        }
        if let project = filteredProjects.first {
            store.selectedProjectID = project.id
            let st = store.status(for: project)
            if st == .offline || st == .error {
                store.start(project)
            }
            close()
        }
    }

    private func close() {
        store.showCommandPalette = false
        query = ""
    }
}
