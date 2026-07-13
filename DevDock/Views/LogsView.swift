import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var processes: ProcessManager
    @Environment(\.dismiss) private var dismiss
    let project: DevProject

    private var logs: [String] {
        processes.logs(for: project.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Logs")
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.mist)
                }
                Spacer()
                Button("Clear") { processes.clearLogs(for: project.id) }
                    .buttonStyle(GhostButtonStyle())
                Button("Close") { dismiss() }
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(16)
            .background(DevDockTheme.panel)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(DevDockTheme.mono)
                                .foregroundStyle(logColor(line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(16)
                }
                .background(DevDockTheme.ink)
                .onChange(of: logs.count) { _, _ in
                    if let last = logs.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
        .background(DevDockTheme.ink)
    }

    private func logColor(_ line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("failed") {
            return DevDockTheme.danger
        }
        if lower.contains("warn") {
            return DevDockTheme.warn
        }
        if lower.contains("started") || lower.contains("ready") || lower.contains("compiled") {
            return DevDockTheme.accent
        }
        return DevDockTheme.chalk.opacity(0.85)
    }
}
