import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var store: DevDockStore
    @EnvironmentObject private var processes: ProcessManager
    let project: DevProject
    @State private var portBusy = false
    @State private var editingCommand = false
    @State private var commandDraft = ""
    @State private var newCmdTitle = ""
    @State private var newCmdLine = ""
    @State private var addingCommand = false
    @State private var addAsGlobal = false
    @State private var flutterDevices: [FlutterDevices.Device] = []
    @State private var flutterDevicesLoading = false
    @State private var flutterDeviceLoadToken = UUID()
    @State private var metroDevices: [MobileDevices.Device] = []
    @State private var metroDevicesLoading = false
    @State private var metroDeviceLoadToken = UUID()
    @State private var portListeners: [PortManager.Listener] = []
    @State private var dependencyIssuesList: [DependencyIssue] = []
    @State private var fixingDependencyID: String?

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
            VStack(alignment: .leading, spacing: 22) {
                hero
                dependencyIssues
                portPanel
                actions
                runtimeTools
                metaGrid
                startCommandEditor
                customCommandsSection
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
            refreshFlutterDevicesIfNeeded()
            refreshMetroDevicesIfNeeded()
            refreshPortListeners()
            refreshDependencyIssues()
        }
        .onChange(of: status) { _, newStatus in
            refreshPortBusy()
            refreshPortListeners()
            if newStatus == .error {
                store.showLogsFor = project.id
            }
        }
        .onChange(of: project.id) { _, _ in
            refreshPortBusy()
            commandDraft = StartCommandResolver.display(liveProject.startCommand)
            editingCommand = false
            flutterDevices = []
            metroDevices = []
            refreshFlutterDevicesIfNeeded()
            refreshMetroDevicesIfNeeded()
            refreshPortListeners()
            refreshDependencyIssues()
        }
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            refreshFlutterDevicesIfNeeded(force: true, silent: true)
            refreshMetroDevicesIfNeeded(force: true, silent: true)
            refreshPortListeners()
        }
    }

    private func refreshPortListeners() {
        guard let port = processes.effectivePort(for: liveProject) ?? liveProject.port else {
            portListeners = []
            return
        }
        let p = port
        Task {
            let list = await Task.detached(priority: .utility) {
                PortManager.listeners(on: p)
            }.value
            await MainActor.run { portListeners = list }
        }
    }

    private func refreshDependencyIssues() {
        let path = liveProject.path
        let fw = FrameworkDetector.detect(at: path)
        Task {
            let issues = await Task.detached(priority: .utility) {
                DependencyIssue.detect(at: path, framework: fw)
            }.value
            await MainActor.run { dependencyIssuesList = issues }
        }
    }

    @ViewBuilder
    private var dependencyIssues: some View {
        if !dependencyIssuesList.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                DetailSectionHeader(title: "Dependencies", systemImage: "shippingbox", accent: DevDockTheme.warn)
                ForEach(dependencyIssuesList) { issue in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DevDockTheme.warn)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DevDockTheme.chalk)
                            Text(issue.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(DevDockTheme.mist)
                        }
                        Spacer(minLength: 8)
                        Button {
                            fixingDependencyID = issue.id
                            store.fixDependency(issue, for: liveProject)
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                refreshDependencyIssues()
                                fixingDependencyID = nil
                            }
                        } label: {
                            Text(fixingDependencyID == issue.id ? "Fixing…" : "Fix")
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(fixingDependencyID != nil)
                    }
                    .padding(12)
                    .background(DevDockTheme.warn.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var portPanel: some View {
        let port = processes.effectivePort(for: liveProject) ?? liveProject.port
        if let port {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    DetailSectionHeader(title: "Port \(port)", systemImage: "network", accent: DevDockTheme.accent)
                    Spacer()
                    if !portListeners.isEmpty {
                        Button {
                            store.killPort(for: liveProject)
                            refreshPortListeners()
                            refreshPortBusy()
                        } label: {
                            Label("Kill", systemImage: "bolt.horizontal.circle")
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }

                if portListeners.isEmpty {
                    Text(status.isAlive ? "No LISTEN process found yet…" : "Port is free")
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.mist)
                } else {
                    ForEach(portListeners) { listener in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(listener.name) · pid \(listener.pid)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(DevDockTheme.chalk)
                                Text(listener.command)
                                    .font(DevDockTheme.mono)
                                    .foregroundStyle(DevDockTheme.mist)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(DevDockTheme.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
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

    private var displayPortLabel: String {
        guard let port = processes.effectivePort(for: liveProject) else { return "—" }
        if let preferred = liveProject.port,
           let bound = processes.boundPort(for: liveProject.id),
           bound != preferred {
            return "localhost:\(bound) · preferred \(preferred)"
        }
        return "localhost:\(port)"
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    StatusDot(status: status)
                    Text(statusLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(DevDockTheme.mist)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(DevDockTheme.panelElevated)
                .clipShape(Capsule())

                Spacer()

                Button {
                    store.toggleFavorite(liveProject)
                } label: {
                    Image(systemName: liveProject.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(liveProject.isFavorite ? DevDockTheme.warn : DevDockTheme.mist)
                        .frame(width: 32, height: 32)
                        .background(DevDockTheme.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(liveProject.isFavorite ? "Remove favorite" : "Add favorite")
            }

            Text(liveProject.name)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(DevDockTheme.chalk)

            HStack(spacing: 8) {
                let fw = liveProject.framework
                let accent = Color(hex: fw.accentHex)
                Text(fw.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(fw.accentNeedsLightLabel ? DevDockTheme.chalk : accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent.opacity(fw.accentNeedsLightLabel ? 0.32 : 0.18))
                    .clipShape(Capsule())

                Label(displayPortLabel, systemImage: "network")
                    .font(DevDockTheme.mono)
                    .foregroundStyle(DevDockTheme.mist)

                if status == .running || status == .external || status == .starting {
                    let health = processes.portHealth(for: liveProject.id)
                    if health != .idle {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(health == .ready ? DevDockTheme.accent : DevDockTheme.warn)
                                .frame(width: 7, height: 7)
                            Text(health.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(health == .ready ? DevDockTheme.accent : DevDockTheme.warn)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((health == .ready ? DevDockTheme.accent : DevDockTheme.warn).opacity(0.14))
                        .clipShape(Capsule())
                    }
                }

                if let notice = processes.portNotice(for: liveProject.id),
                   status == .running || status == .starting {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DevDockTheme.warn)
                        .lineLimit(1)
                } else if portBusy {
                    Label("Port used elsewhere", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
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

            if let err = runtime?.lastError, status == .error {
                let reason = StartFailureReason.summarize(from: runtime?.logs ?? [], fallback: err)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(DevDockTheme.danger)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reason)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DevDockTheme.danger)
                        if reason != err {
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundStyle(DevDockTheme.mist)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 8)
                    Button("Logs") { store.showLogsFor = project.id }
                        .buttonStyle(GhostButtonStyle())
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DevDockTheme.danger.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if status == .running || status == .external || status == .starting || status == .stopping {
                Button {
                    store.stop(liveProject)
                } label: {
                    Label(
                        status == .stopping ? "Stopping…" : (status == .external ? "Stop Port" : "Stop"),
                        systemImage: "stop.fill"
                    )
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(status == .stopping)

                if status == .running {
                    Button {
                        store.restart(liveProject)
                    } label: {
                        Label("Restart", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            } else {
                Button {
                    store.start(liveProject)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(AccentButtonStyle())
            }

            if let port = processes.effectivePort(for: liveProject) {
                Button {
                    ExternalLauncher.openBrowser(port: port)
                } label: {
                    Label("Open", systemImage: "safari")
                }
                .buttonStyle(GhostButtonStyle())
            }

            Button {
                store.showLogsFor = project.id
            } label: {
                Label("Logs", systemImage: "text.alignleft")
            }
            .buttonStyle(GhostButtonStyle())

            if portBusy {
                Button {
                    store.killPort(for: liveProject)
                } label: {
                    Label("Kill Port", systemImage: "bolt.horizontal.circle")
                }
                .buttonStyle(GhostButtonStyle())
            }

            Spacer()

            Menu {
                Button("Open in Editor", systemImage: "chevron.left.forwardslash.chevron.right") {
                    ExternalLauncher.openEditor(liveProject.path)
                }
                Button("Open in DevCheck", systemImage: "checkmark.shield") {
                    ExternalLauncher.openDevCheck(liveProject.path)
                }
                Button("Open Folder", systemImage: "folder") {
                    ExternalLauncher.openFolder(liveProject.path)
                }
                Button("Open Terminal", systemImage: "terminal") {
                    ExternalLauncher.openTerminal(liveProject.path)
                }
                Button("Edit .env", systemImage: "doc.text") {
                    ExternalLauncher.openEnvFile(liveProject.path)
                }
            } label: {
                Label("Open", systemImage: "ellipsis.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DevDockTheme.chalk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(DevDockTheme.panelElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DevDockTheme.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var runtimeTools: some View {
        let fw = FrameworkDetector.detect(at: liveProject.path)
        let running = status == .running
        let helpers = StackRuntimeCatalog.helpers(for: fw, at: liveProject.path)
        let port = processes.effectivePort(for: liveProject)

        return VStack(alignment: .leading, spacing: 14) {
            DetailSectionHeader(title: "Runtime", systemImage: "bolt.fill", accent: DevDockTheme.accent)

            HStack(spacing: 8) {
                Button {
                    store.restart(liveProject)
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(!(running || status == .error || status == .offline))

                if fw.supportsClearCache {
                    Button {
                        store.restart(liveProject, clearCache: true)
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                if let port {
                    Button {
                        ExternalLauncher.openBrowser(port: port)
                    } label: {
                        Label("Open Browser", systemImage: "safari")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }

            if fw == .expo || fw == .reactNative || fw == .ionic {
                expoGoCommands(running: running)
            } else if fw == .flutter {
                flutterCommands(running: running)
            }

            if !helpers.isEmpty {
                DetailSectionHeader(
                    title: StackRuntimeCatalog.sectionTitle,
                    systemImage: "square.stack.3d.up",
                    accent: DevDockTheme.warn
                )
                .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 8)], spacing: 8) {
                    ForEach(helpers) { helper in
                        CommandTile(title: helper.title, systemImage: helper.systemImage) {
                            runOneShot(helper.argv)
                        }
                    }
                }

                Text("Runs once in this folder — output appears in Logs.")
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
            } else if fw != .expo && fw != .reactNative && fw != .ionic && fw != .flutter {
                Text(runtimeHint(for: fw))
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
            }
        }
        .padding(16)
        .background(DevDockTheme.panel.opacity(0.65))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DevDockTheme.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func expoGoCommands(running: Bool) -> some View {
        let selectedID = processes.selectedMetroDeviceID(for: liveProject.id)
        let fw = FrameworkDetector.detect(at: liveProject.path)
        let title = fw == .ionic ? "Ionic" : (fw == .reactNative ? "React Native" : "Expo Go")

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                DetailSectionHeader(title: "Connected devices", systemImage: "iphone.and.arrow.forward", accent: DevDockTheme.warn)
                Spacer()
                Button {
                    refreshMetroDevicesIfNeeded(force: true)
                } label: {
                    Label(metroDevicesLoading ? "Scanning…" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(metroDevicesLoading)
            }

            if metroDevicesLoading && metroDevices.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Looking for simulators / emulators…")
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.mist)
                }
                .padding(.vertical, 4)
            } else if metroDevices.isEmpty {
                Text("No booted devices yet — use a Quick target below, or open Simulator and Refresh.")
                    .font(.system(size: 12))
                    .foregroundStyle(DevDockTheme.mist)
            } else {
                VStack(spacing: 8) {
                    ForEach(metroDevices) { device in
                        metroDeviceRow(device, selected: selectedID == device.id, running: running)
                    }
                }
            }

            DetailSectionHeader(title: "Quick targets", systemImage: "bolt.horizontal", accent: DevDockTheme.warn)
                .padding(.top, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 8)], spacing: 8) {
                CommandTile(title: "iOS Simulator", systemImage: "apple.logo", emphasized: true) {
                    store.openDevice(liveProject, platform: "ios")
                }
                CommandTile(title: "Android Emulator", systemImage: "smartphone", emphasized: true) {
                    store.openDevice(liveProject, platform: "android")
                }
                CommandTile(title: "Web", systemImage: "globe", emphasized: true) {
                    store.openDevice(liveProject, platform: "web")
                }
            }

            Text("Simulator / Emulator shortcuts never pick a physical phone. Connected rows open that exact target.")
                .font(.system(size: 11))
                .foregroundStyle(DevDockTheme.mist)

            DetailSectionHeader(title: title, systemImage: "iphone", accent: DevDockTheme.warn)
                .padding(.top, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 8)], spacing: 8) {
                CommandTile(title: "Reload app", systemImage: "arrow.clockwise", shortcut: "r") {
                    store.hotReload(liveProject)
                }
                CommandTile(title: "Toggle menu", systemImage: "line.3.horizontal", shortcut: "m") {
                    store.sendRuntimeKey(liveProject, "m")
                }
                CommandTile(title: "Open debugger", systemImage: "ant", shortcut: "j") {
                    store.sendRuntimeKey(liveProject, "j")
                }
                CommandTile(title: "Dev build", systemImage: "hammer", shortcut: "s") {
                    store.sendRuntimeKey(liveProject, "s")
                }
                CommandTile(title: "Open in editor", systemImage: "chevron.left.forwardslash.chevron.right", shortcut: "o") {
                    ExternalLauncher.openEditor(liveProject.path)
                }
                CommandTile(title: "Show commands", systemImage: "questionmark.circle", shortcut: "?") {
                    store.sendRuntimeKey(liveProject, "?")
                }
            }
            .disabled(!running)
            .opacity(running ? 1 : 0.45)

            if !running {
                Text("Start the project first — or tap a device / quick target to start Metro and open it.")
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
            }
        }
    }

    private func metroDeviceRow(_ device: MobileDevices.Device, selected: Bool, running: Bool) -> some View {
        Button {
            store.runOnMetroDevice(liveProject, device: device)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: device.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? DevDockTheme.ink : DevDockTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(selected ? DevDockTheme.accent : DevDockTheme.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DevDockTheme.chalk)
                        .lineLimit(1)
                    Text(device.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(DevDockTheme.mist)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if selected && running {
                    Text("Active")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(DevDockTheme.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DevDockTheme.accent)
                        .clipShape(Capsule())
                } else if selected {
                    Text("Selected")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(DevDockTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DevDockTheme.accent.opacity(0.14))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DevDockTheme.mist)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DevDockTheme.panelElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? DevDockTheme.accent.opacity(0.55) : DevDockTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func refreshMetroDevicesIfNeeded(force: Bool = false, silent: Bool = false) {
        let fw = FrameworkDetector.detect(at: liveProject.path)
        guard fw == .expo || fw == .reactNative || fw == .ionic else {
            metroDevices = []
            return
        }
        if metroDevicesLoading { return }
        if !force && !metroDevices.isEmpty { return }

        if !silent || metroDevices.isEmpty {
            metroDevicesLoading = true
        }
        let token = UUID()
        metroDeviceLoadToken = token

        Task {
            let devices = await Task.detached(priority: silent ? .utility : .userInitiated) {
                MobileDevices.connectedTargets()
            }.value
            await MainActor.run {
                guard metroDeviceLoadToken == token else { return }
                metroDevices = devices
                metroDevicesLoading = false
            }
        }
    }

    private func flutterCommands(running: Bool) -> some View {
        let selectedID = processes.selectedFlutterDeviceID(for: liveProject.id)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                DetailSectionHeader(title: "Connected devices", systemImage: "iphone.and.arrow.forward", accent: DevDockTheme.warn)
                Spacer()
                Button {
                    refreshFlutterDevicesIfNeeded(force: true)
                } label: {
                    Label(flutterDevicesLoading ? "Scanning…" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(flutterDevicesLoading)
            }

            if flutterDevicesLoading && flutterDevices.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Looking for Flutter devices…")
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.mist)
                }
                .padding(.vertical, 4)
            } else if flutterDevices.isEmpty {
                Text("No booted devices yet — use a shortcut below, or open Simulator and Refresh.")
                    .font(.system(size: 12))
                    .foregroundStyle(DevDockTheme.mist)
            } else {
                VStack(spacing: 8) {
                    ForEach(flutterDevices) { device in
                        flutterDeviceRow(
                            device,
                            selected: selectedID == device.id,
                            running: running
                        )
                    }
                }
            }

            DetailSectionHeader(title: "Quick targets", systemImage: "bolt.horizontal", accent: DevDockTheme.warn)
                .padding(.top, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 8)], spacing: 8) {
                CommandTile(title: "iOS Simulator", systemImage: "apple.logo", emphasized: true) {
                    store.openDevice(liveProject, platform: "ios")
                }
                CommandTile(title: "Android Emulator", systemImage: "smartphone", emphasized: true) {
                    store.openDevice(liveProject, platform: "android")
                }
                CommandTile(title: "Chrome", systemImage: "globe", emphasized: true) {
                    store.openDevice(liveProject, platform: "web")
                }
                CommandTile(title: "macOS", systemImage: "desktopcomputer", emphasized: true) {
                    store.openDevice(liveProject, platform: "macos")
                }
            }

            Text("Shortcuts use flutter run -d ios/android/chrome/macos (can boot a simulator). Connected rows target an exact device id.")
                .font(.system(size: 11))
                .foregroundStyle(DevDockTheme.mist)

            DetailSectionHeader(title: "Flutter tool", systemImage: "hammer.fill", accent: DevDockTheme.warn)
                .padding(.top, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 8)], spacing: 8) {
                CommandTile(title: "Hot reload", systemImage: "flame", shortcut: "r") {
                    store.hotReload(liveProject)
                }
                CommandTile(title: "Hot restart", systemImage: "arrow.triangle.2.circlepath", shortcut: "R") {
                    store.hotRestart(liveProject)
                }
                CommandTile(title: "Performance overlay", systemImage: "gauge.with.dots.needle.33percent", shortcut: "p") {
                    store.sendRuntimeKey(liveProject, "p")
                }
                CommandTile(title: "Debug paint", systemImage: "paintpalette", shortcut: "P") {
                    store.sendRuntimeKey(liveProject, "P")
                }
                CommandTile(title: "Widget inspector", systemImage: "cube.transparent", shortcut: "i") {
                    store.sendRuntimeKey(liveProject, "i")
                }
                CommandTile(title: "Toggle platform", systemImage: "switch.2", shortcut: "o") {
                    store.sendRuntimeKey(liveProject, "o")
                }
                CommandTile(title: "Verbose logging", systemImage: "text.bubble", shortcut: "v") {
                    store.sendRuntimeKey(liveProject, "v")
                }
                CommandTile(title: "Show commands", systemImage: "questionmark.circle", shortcut: "h") {
                    store.sendRuntimeKey(liveProject, "h")
                }
                CommandTile(title: "Detach", systemImage: "eject", shortcut: "d") {
                    store.sendRuntimeKey(liveProject, "d")
                }
                CommandTile(title: "Quit app", systemImage: "xmark.circle", shortcut: "q") {
                    store.sendRuntimeKey(liveProject, "q")
                }
            }
            .disabled(!running)
            .opacity(running ? 1 : 0.45)

            Text(running
                 ? "Tap another device or shortcut to switch targets. Tool tiles send keys to live flutter run."
                 : "Pick a connected device or a quick target to start.")
                .font(.system(size: 11))
                .foregroundStyle(DevDockTheme.mist)
        }
    }

    private func flutterDeviceRow(_ device: FlutterDevices.Device, selected: Bool, running: Bool) -> some View {
        Button {
            store.runOnFlutterDevice(liveProject, deviceID: device.id, label: device.name)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: device.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? DevDockTheme.ink : DevDockTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(selected ? DevDockTheme.accent : DevDockTheme.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DevDockTheme.chalk)
                        .lineLimit(1)
                    Text(device.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(DevDockTheme.mist)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if selected && running {
                    Text("Running")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(DevDockTheme.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DevDockTheme.accent)
                        .clipShape(Capsule())
                } else if selected {
                    Text("Selected")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(DevDockTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DevDockTheme.accent.opacity(0.14))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DevDockTheme.mist)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DevDockTheme.panelElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? DevDockTheme.accent.opacity(0.55) : DevDockTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func refreshFlutterDevicesIfNeeded(force: Bool = false, silent: Bool = false) {
        let fw = FrameworkDetector.detect(at: liveProject.path)
        guard fw == .flutter else {
            flutterDevices = []
            return
        }
        if flutterDevicesLoading { return }
        if !force && !flutterDevices.isEmpty { return }

        if !silent || flutterDevices.isEmpty {
            flutterDevicesLoading = true
        }
        let path = liveProject.path
        let token = UUID()
        flutterDeviceLoadToken = token

        Task {
            let devices = await Task.detached(priority: silent ? .utility : .userInitiated) {
                FlutterDevices.available(at: path)
            }.value
            await MainActor.run {
                guard flutterDeviceLoadToken == token else { return }
                flutterDevices = devices
                flutterDevicesLoading = false
            }
        }
    }

    private func runtimeHint(for fw: Framework) -> String {
        if fw.isNodeFamily {
            return "Web/API stacks hot-reload in the browser — Restart rebuilds the process."
        }
        return "Restart stops and starts the process cleanly."
    }

    private var metaGrid: some View {
        let health = processes.portHealth(for: liveProject.id)
        let healthTitle: String = {
            if status == .running || status == .external || status == .starting {
                return health == .idle ? statusLabel : health.label
            }
            return statusLabel
        }()
        let healthTint: Color = {
            if health == .ready { return DevDockTheme.accent }
            if health == .waiting { return DevDockTheme.warn }
            if status == .external { return DevDockTheme.external }
            if status == .error { return DevDockTheme.danger }
            if status == .running { return DevDockTheme.accent }
            return DevDockTheme.mist
        }()

        return HStack(spacing: 10) {
            metaChip(
                icon: "arrow.triangle.branch",
                title: git?.branch ?? "No git",
                subtitle: git?.summary ?? "Not a repository"
            )
            metaChip(
                icon: health == .ready ? "heart.fill" : "heart",
                title: healthTitle,
                subtitle: health == .idle ? "Process" : "HTTP",
                tint: healthTint
            )
        }
    }

    private func metaChip(icon: String, title: String, subtitle: String, tint: Color = DevDockTheme.accent) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(DevDockTheme.chalk)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DevDockTheme.panel.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DevDockTheme.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var startCommandEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DetailSectionHeader(title: "Start command", systemImage: "terminal", accent: DevDockTheme.mist)
                if liveProject.usesCustomStartCommand {
                    Text("custom")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DevDockTheme.warn)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(DevDockTheme.warn.opacity(0.15))
                        .clipShape(Capsule())
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
                    Button {
                        commandDraft = StartCommandResolver.display(liveProject.startCommand)
                        editingCommand = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DevDockTheme.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var customCommandsSection: some View {
        let commands = store.allCommands(for: liveProject)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                DetailSectionHeader(title: "Custom commands", systemImage: "command", accent: DevDockTheme.mist)
                Spacer()
                Button(addingCommand ? "Cancel" : "Add") {
                    addingCommand.toggle()
                    if !addingCommand {
                        newCmdTitle = ""
                        newCmdLine = ""
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }

            Text("Project-only or Global (all frameworks). Runs as one-shot in this folder.")
                .font(.system(size: 11))
                .foregroundStyle(DevDockTheme.mist)

            if commands.isEmpty && !addingCommand {
                Text("No custom commands yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(DevDockTheme.mist)
            }

            if !commands.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(commands) { cmd in
                        let isGlobal = store.settings.globalCustomCommands.contains(where: { $0.id == cmd.id })
                        HStack(spacing: 8) {
                            Button(cmd.title) { runOneShot(cmd.argv) }
                                .buttonStyle(GhostButtonStyle())
                            Text(cmd.display)
                                .font(DevDockTheme.mono)
                                .foregroundStyle(DevDockTheme.mist)
                                .lineLimit(1)
                            if isGlobal {
                                Text("global")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(DevDockTheme.warn)
                            }
                            Spacer()
                            Button {
                                if isGlobal {
                                    store.deleteGlobalCommand(cmd.id)
                                } else {
                                    store.deleteProjectCommand(liveProject, commandID: cmd.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(DevDockTheme.mist)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if addingCommand {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Title (e.g. Lint)", text: $newCmdTitle)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(DevDockTheme.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    TextField("Command (e.g. npm run lint)", text: $newCmdLine)
                        .textFieldStyle(.plain)
                        .font(DevDockTheme.mono)
                        .padding(10)
                        .background(DevDockTheme.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Toggle("Available for all projects / frameworks", isOn: $addAsGlobal)
                        .toggleStyle(.checkbox)
                        .foregroundStyle(DevDockTheme.mist)

                    Button("Save command") {
                        let title = newCmdTitle
                        let line = newCmdLine
                        if addAsGlobal {
                            store.addGlobalCommand(title: title, commandLine: line)
                        } else {
                            store.addProjectCommand(liveProject, title: title, commandLine: line)
                        }
                        newCmdTitle = ""
                        newCmdLine = ""
                        addingCommand = false
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(newCmdLine.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var pathBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            DetailSectionHeader(title: "Path", systemImage: "folder", accent: DevDockTheme.mist)
            Text(liveProject.path)
                .font(DevDockTheme.mono)
                .foregroundStyle(DevDockTheme.chalk)
                .textSelection(.enabled)
        }
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
