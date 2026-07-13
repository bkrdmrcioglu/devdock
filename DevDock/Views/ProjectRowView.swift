import SwiftUI

struct ProjectRowView: View {
    @EnvironmentObject private var store: DevDockStore
    @EnvironmentObject private var processes: ProcessManager
    let project: DevProject

    private var status: ProjectStatus {
        store.status(for: project)
    }

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(status: status)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if project.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(DevDockTheme.warn)
                    }
                    Text(project.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DevDockTheme.chalk)
                        .lineLimit(1)
                }
                Text("\(project.framework.rawValue)  ·  \(displayPort)")
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if status == .running || status == .external {
                let health = processes.portHealth(for: project.id)
                if health != .idle {
                    Circle()
                        .fill(health == .ready ? DevDockTheme.accent : DevDockTheme.warn)
                        .frame(width: 6, height: 6)
                        .help(health.label)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button(project.isFavorite ? "Remove Favorite" : "Add Favorite") {
                store.toggleFavorite(project)
            }
            Divider()
            Button("Start") { store.start(project) }
            Button("Stop") { store.stop(project) }
            Button("Restart") { store.restart(project) }
            if project.framework.supportsHotReload {
                Button("Hot Reload") { store.hotReload(project) }
            }
            if project.framework.supportsHotRestart {
                Button("Hot Restart") { store.hotRestart(project) }
            }
            if project.framework == .flutter {
                Menu("Run on…") {
                    Button("iOS") { store.openDevice(project, platform: "ios") }
                    Button("Android") { store.openDevice(project, platform: "android") }
                    Button("Web (Chrome)") { store.openDevice(project, platform: "web") }
                    Button("macOS") { store.openDevice(project, platform: "macos") }
                    Divider()
                    Button("List Devices") { store.listFlutterDevices(project) }
                }
            }
            if project.framework.supportsClearCache {
                Button("Clear Cache + Restart") { store.restart(project, clearCache: true) }
            }
            Button("Open Browser") {
                if let port = processes.effectivePort(for: project) {
                    ExternalLauncher.openBrowser(port: port)
                }
            }
            Button("Open in Editor") { ExternalLauncher.openEditor(project.path) }
            Button("Show Logs") { store.showLogsFor = project.id }
        }
    }

    private var displayPort: String {
        guard let port = processes.effectivePort(for: project) else { return "—" }
        if let preferred = project.port,
           let bound = processes.boundPort(for: project.id),
           bound != preferred,
           status == .running || status == .starting {
            return "localhost:\(bound) (was \(preferred))"
        }
        return "localhost:\(port)"
    }
}
