import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var store: DevDockStore
    @EnvironmentObject private var processes: ProcessManager
    let project: DevProject
    @State private var portBusy = false
    @State private var editingCommand = false
    @State private var commandDraft = ""

    private var liveProject: DevProject {
        store.projects.first(where: { $0.id == project.id }) ?? project
    }

    private var status: ProjectStatus {
        store.status(for: liveProject)
    }

    private var runtime: ProcessManager.RuntimeState? {
        processes.states[project.id]
    }

    private var git: GitInfo? {
        store.gitCache[project.id]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                actions
                metaGrid
                startCommandEditor
                if liveProject.framework == .laravel {
                    laravelTools
                }
                if ["Next.js", "React", "Vue", "NestJS", "Express"].contains(liveProject.framework.rawValue) {
                    nodeTools
                }
                pathBlock
            }
            .padding(28)
        }
        .background(
            ZStack {
                DevDockTheme.ink
                RadialGradient(
                    colors: [Color(hex: liveProject.framework.accentHex).opacity(0.18), .clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        )
        .onAppear {
            refreshPortBusy()
            commandDraft = StartCommandResolver.display(liveProject.startCommand)
        }
        .onChange(of: status) { _, newStatus in
            refreshPortBusy()
            if newStatus == .error {
                store.showLogsFor = project.id
            }
        }
        .onChange(of: project.id) { _, _ in
            refreshPortBusy()
            commandDraft = StartCommandResolver.display(liveProject.startCommand)
            editingCommand = false
        }
    }

    private func refreshPortBusy() {
        switch status {
        case .running, .external, .starting, .stopping:
            portBusy = false
        case .offline, .error:
            portBusy = store.isPortBusyElsewhere(for: liveProject)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                StatusDot(status: status)
                Text(statusLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DevDockTheme.mist)
                Spacer()
                Button {
                    store.toggleFavorite(liveProject)
                } label: {
                    Image(systemName: liveProject.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(liveProject.isFavorite ? DevDockTheme.warn : DevDockTheme.mist)
                }
                .buttonStyle(.plain)
            }

            Text(liveProject.name)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(DevDockTheme.chalk)

            HStack(spacing: 10) {
                Text(liveProject.framework.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DevDockTheme.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(liveProject.displayPort)
                    .font(DevDockTheme.mono)
                    .foregroundStyle(DevDockTheme.mist)

                if portBusy {
                    Text("Port used elsewhere")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DevDockTheme.warn)
                }

                if let runtime, let cpu = runtime.cpuHint, let mem = runtime.memoryHint, status == .running {
                    Text("\(cpu) · \(mem)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DevDockTheme.mist)
                }

                if status == .external {
                    Text("via Terminal / other app")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DevDockTheme.external)
                }
            }
            .foregroundStyle(DevDockTheme.chalk)

            if let err = runtime?.lastError, status == .error {
                HStack(spacing: 8) {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.danger)
                    Button("View Logs") { store.showLogsFor = project.id }
                        .buttonStyle(GhostButtonStyle())
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if status == .running || status == .external || status == .starting || status == .stopping {
                Button(status == .stopping ? "Stopping…" : (status == .external ? "Stop Port" : "Stop")) {
                    store.stop(liveProject)
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(status == .stopping)
            } else {
                Button("Start") { store.start(liveProject) }
                    .buttonStyle(AccentButtonStyle())
            }

            if let port = liveProject.port {
                Button("Open") { ExternalLauncher.openBrowser(port: port) }
                    .buttonStyle(GhostButtonStyle())
            }

            Button("Logs") { store.showLogsFor = project.id }
                .buttonStyle(GhostButtonStyle())

            if portBusy {
                Button("Kill Port") { store.killPort(for: liveProject) }
                    .buttonStyle(GhostButtonStyle())
            }

            Spacer()

            Menu {
                Button("Open in Editor") { ExternalLauncher.openEditor(liveProject.path) }
                Button("Open Folder") { ExternalLauncher.openFolder(liveProject.path) }
                Button("Open Terminal") { ExternalLauncher.openTerminal(liveProject.path) }
                Button("Edit .env") { ExternalLauncher.openEnvFile(liveProject.path) }
            } label: {
                Label("Open…", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .foregroundStyle(DevDockTheme.mist)
        }
    }

    private var metaGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            metaCard(title: "Git") {
                if let git {
                    Text(git.branch)
                        .font(DevDockTheme.mono)
                        .foregroundStyle(DevDockTheme.chalk)
                    Text(git.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.mist)
                } else {
                    Text("Not a git repo")
                        .foregroundStyle(DevDockTheme.mist)
                }
            }

            metaCard(title: "Health") {
                HStack(spacing: 8) {
                    StatusDot(status: status)
                    Text(statusLabel)
                        .foregroundStyle(DevDockTheme.chalk)
                }
            }
        }
    }

    private var startCommandEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("START COMMAND")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DevDockTheme.mist)
                if liveProject.usesCustomStartCommand {
                    Text("custom")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DevDockTheme.warn)
                }
                Spacer()
                if editingCommand {
                    Button("Cancel") {
                        editingCommand = false
                        commandDraft = StartCommandResolver.display(liveProject.startCommand)
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button("Save") {
                        store.setCustomStartCommand(liveProject, commandLine: commandDraft)
                        editingCommand = false
                    }
                    .buttonStyle(AccentButtonStyle())
                } else {
                    Button("Edit") {
                        commandDraft = StartCommandResolver.display(liveProject.startCommand)
                        editingCommand = true
                    }
                    .buttonStyle(GhostButtonStyle())
                    if liveProject.usesCustomStartCommand {
                        Button("Reset") {
                            store.setCustomStartCommand(liveProject, commandLine: nil)
                            commandDraft = StartCommandResolver.display(
                                liveProject.detectedStartCommand
                                    ?? liveProject.framework.startCommand
                            )
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }
            }

            if editingCommand {
                TextField("e.g. npm run dev", text: $commandDraft)
                    .textFieldStyle(.plain)
                    .font(DevDockTheme.mono)
                    .padding(10)
                    .background(DevDockTheme.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text(StartCommandResolver.display(liveProject.startCommand))
                    .font(DevDockTheme.mono)
                    .foregroundStyle(DevDockTheme.chalk)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DevDockTheme.panel.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var laravelTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Laravel")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DevDockTheme.mist)
            HStack(spacing: 8) {
                artisanButton("migrate", ["php", "artisan", "migrate"])
                artisanButton("seed", ["php", "artisan", "db:seed"])
                artisanButton("fresh", ["php", "artisan", "migrate:fresh", "--seed"])
            }
        }
    }

    private var nodeTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Node")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DevDockTheme.mist)
            HStack(spacing: 8) {
                oneShotButton("npm install", ["npm", "install"])
                oneShotButton("npm update", ["npm", "update"])
                oneShotButton("npm audit", ["npm", "audit"])
            }
        }
    }

    private var pathBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Path")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DevDockTheme.mist)
            Text(liveProject.path)
                .font(DevDockTheme.mono)
                .foregroundStyle(DevDockTheme.chalk)
                .textSelection(.enabled)
        }
    }

    private func metaCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DevDockTheme.mist)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DevDockTheme.panel.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DevDockTheme.line, lineWidth: 1)
        )
    }

    private func artisanButton(_ title: String, _ cmd: [String]) -> some View {
        oneShotButton(title, cmd)
    }

    private func oneShotButton(_ title: String, _ cmd: [String]) -> some View {
        Button(title) {
            runOneShot(cmd)
        }
        .buttonStyle(GhostButtonStyle())
    }

    private func runOneShot(_ cmd: [String]) {
        let id = liveProject.id
        let path = liveProject.path
        processes.note(id, "one-shot: \(cmd.joined(separator: " "))")
        guard let executable = Toolchain.resolveExecutable(cmd[0], path: path) else {
            processes.note(id, "Command not found: \(cmd[0])")
            store.showLogsFor = id
            return
        }
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(cmd.dropFirst())
        process.environment = Toolchain.processEnvironment()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                for line in text.split(whereSeparator: \.isNewline).prefix(40) {
                    processes.note(id, String(line))
                }
                processes.note(id, "one-shot exited (\(proc.terminationStatus))")
            }
        }
        do {
            try process.run()
            store.showLogsFor = id
        } catch {
            processes.note(id, "one-shot failed: \(error.localizedDescription)")
            store.showLogsFor = id
        }
    }

    private var statusLabel: String {
        switch status {
        case .offline: return "Offline"
        case .starting: return "Starting"
        case .running: return "Running"
        case .external: return "Running (external)"
        case .stopping: return "Stopping"
        case .error: return "Error"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (100, 100, 100)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
