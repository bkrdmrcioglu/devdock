import SwiftUI
import AppKit

struct LogsView: View {
    @EnvironmentObject private var processes: ProcessManager
    let project: DevProject
    var onClose: () -> Void

    @State private var tab: LogTab = .all
    @State private var copyFlash = false

    private var logs: [String] {
        processes.logs(for: project.id)
    }

    private var errorLines: [String] {
        logs.filter { LogLineKind.classify($0) == .error }
    }

    private var warningLines: [String] {
        logs.filter { LogLineKind.classify($0) == .warning }
    }

    private var visibleLines: [String] {
        switch tab {
        case .all: return logs
        case .errors: return errorLines
        case .warnings: return warningLines
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().overlay(DevDockTheme.line)
            logList
        }
        .background(DevDockTheme.ink)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DevDockTheme.accent)
                .frame(width: 30, height: 30)
                .background(DevDockTheme.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(DevDockTheme.chalk)
                    .lineLimit(1)
                Text(headerSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DevDockTheme.mist)
            }

            Spacer(minLength: 0)

            Button {
                copyVisibleLogs()
            } label: {
                Label(copyFlash ? "Copied" : "Copy", systemImage: copyFlash ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(visibleLines.isEmpty)
            .help("Copy \(tab.title.lowercased()) to clipboard")

            Button {
                processes.clearLogs(for: project.id)
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(GhostButtonStyle())

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DevDockTheme.mist)
                    .frame(width: 28, height: 28)
                    .background(DevDockTheme.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Close logs")
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(DevDockTheme.panel)
    }

    private var headerSubtitle: String {
        switch tab {
        case .all: return "Live logs"
        case .errors: return "\(errorLines.count) error line\(errorLines.count == 1 ? "" : "s")"
        case .warnings: return "\(warningLines.count) warning line\(warningLines.count == 1 ? "" : "s")"
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(LogTab.allCases) { item in
                logTabButton(item)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DevDockTheme.panel.opacity(0.85))
    }

    private func logTabButton(_ item: LogTab) -> some View {
        let count: Int = {
            switch item {
            case .all: return logs.count
            case .errors: return errorLines.count
            case .warnings: return warningLines.count
            }
        }()
        let selected = tab == item

        return Button {
            tab = item
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 10, weight: .bold))
                Text(item.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(selected ? item.accent.opacity(0.22) : DevDockTheme.ink.opacity(0.45))
                    .clipShape(Capsule())
            }
            .foregroundStyle(selected ? item.accent : DevDockTheme.mist)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? item.accent.opacity(0.12) : DevDockTheme.panelElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? item.accent.opacity(0.45) : DevDockTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if visibleLines.isEmpty {
                        emptyState
                    }
                    ForEach(Array(visibleLines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(DevDockTheme.mono)
                            .foregroundStyle(color(for: line))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
                .padding(16)
            }
            .background(DevDockTheme.ink)
            .onChange(of: visibleLines.count) { _, _ in
                guard tab == .all || tab == .errors || tab == .warnings else { return }
                if let last = visibleLines.indices.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .onChange(of: tab) { _, _ in
                if let last = visibleLines.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emptyTitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(DevDockTheme.chalk)
            Text(emptySubtitle)
                .font(.system(size: 12))
                .foregroundStyle(DevDockTheme.mist)
        }
        .padding(.top, 8)
    }

    private var emptyTitle: String {
        switch tab {
        case .all: return "No output yet"
        case .errors: return "No errors"
        case .warnings: return "No warnings"
        }
    }

    private var emptySubtitle: String {
        switch tab {
        case .all: return "Start the project or run a command."
        case .errors: return "Error lines will show up here automatically."
        case .warnings: return "Warning lines will show up here automatically."
        }
    }

    private func color(for line: String) -> Color {
        switch LogLineKind.classify(line) {
        case .error: return DevDockTheme.danger
        case .warning: return DevDockTheme.warn
        case .success: return DevDockTheme.accent
        case .normal: return DevDockTheme.chalk.opacity(0.85)
        }
    }

    private func copyVisibleLogs() {
        let text = visibleLines.joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copyFlash = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            copyFlash = false
        }
    }
}

private enum LogTab: String, CaseIterable, Identifiable {
    case all
    case errors
    case warnings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .errors: return "Errors"
        case .warnings: return "Warnings"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .errors: return "xmark.octagon.fill"
        case .warnings: return "exclamationmark.triangle.fill"
        }
    }

    var accent: Color {
        switch self {
        case .all: return DevDockTheme.accent
        case .errors: return DevDockTheme.danger
        case .warnings: return DevDockTheme.warn
        }
    }
}

private enum LogLineKind {
    case error, warning, success, normal

    static func classify(_ line: String) -> LogLineKind {
        let lower = line.lowercased()

        if lower.range(of: #"\b(error|errors|failed|failure|exception|fatal|crash)\b"#, options: .regularExpression) != nil
            || lower.contains("error domain=")
            || lower.contains("❌")
            || lower.contains("unable to find")
            || lower.contains("nsosstatuserrordomain") {
            return .error
        }

        if lower.range(of: #"\b(warn|warning|deprecated)\b"#, options: .regularExpression) != nil
            || lower.contains("⚠️")
            || lower.contains("warning:") {
            return .warning
        }

        if lower.contains("started") || lower.contains("ready") || lower.contains("compiled")
            || lower.contains("build done") || lower.contains("✓") {
            return .success
        }

        return .normal
    }
}

/// Right-edge off-canvas drawer for project logs.
struct LogsDrawerOverlay: View {
    @EnvironmentObject private var store: DevDockStore
    @EnvironmentObject private var processes: ProcessManager

    private var project: DevProject? {
        guard let id = store.showLogsFor else { return nil }
        return store.projects.first { $0.id == id }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if let project {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .onTapGesture {
                        close()
                    }
                    .transition(.opacity)

                LogsView(project: project, onClose: close)
                    .environmentObject(processes)
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .background(DevDockTheme.ink)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(DevDockTheme.line)
                            .frame(width: 1)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 28, x: -8, y: 0)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: store.showLogsFor)
    }

    private var drawerWidth: CGFloat {
        460
    }

    private func close() {
        store.showLogsFor = nil
    }
}
