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
                Text("\(project.framework.rawValue)  ·  \(project.displayPort)")
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
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
            Button("Open Browser") {
                if let port = project.port { ExternalLauncher.openBrowser(port: port) }
            }
            Button("Open in Editor") { ExternalLauncher.openEditor(project.path) }
            Button("Show Logs") { store.showLogsFor = project.id }
        }
    }
}
