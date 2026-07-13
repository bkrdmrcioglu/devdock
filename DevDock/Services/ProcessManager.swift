import Foundation
import Combine

extension Notification.Name {
    static let devDockProjectReady = Notification.Name("devdock.projectReady")
}

@MainActor
final class ProcessManager: ObservableObject {
    struct RuntimeState {
        var status: ProjectStatus = .offline
        var pid: Int32?
        var logs: [String] = []
        var lastError: String?
        var cpuHint: String?
        var memoryHint: String?
        /// Actual port for this run (may differ from project.port when remapped).
        var boundPort: Int?
        /// User-facing note when preferred port was busy.
        var portNotice: String?
        /// HTTP readiness on localhost (when a host port exists).
        var portHealth: PortHealth = .idle
        /// Last log / start / input activity (for idle auto-stop).
        var lastActivityAt: Date = Date()
    }

    @Published private(set) var states: [UUID: RuntimeState] = [:]

    private var processes: [UUID: Process] = [:]
    private var readers: [UUID: [DispatchSourceRead]] = [:]
    private var stdinPipes: [UUID: Pipe] = [:]
    /// Last Flutter `-d` target chosen via Run on iOS/Android/Web/macOS.
    private var flutterDeviceByProject: [UUID: String] = [:]
    /// Last Expo/RN/Ionic device id chosen from Connected list / quick targets.
    private var metroDeviceByProject: [UUID: String] = [:]
    /// Project path for resource sampling (Flutter Runner lookup, etc.).
    private var resourcePathByProject: [UUID: String] = [:]
    private var healthTasks: [UUID: Task<Void, Never>] = [:]

    func status(for id: UUID) -> ProjectStatus {
        states[id]?.status ?? .offline
    }

    func logs(for id: UUID) -> [String] {
        states[id]?.logs ?? []
    }

    func boundPort(for id: UUID) -> Int? {
        states[id]?.boundPort
    }

    func portNotice(for id: UUID) -> String? {
        states[id]?.portNotice
    }

    func portHealth(for id: UUID) -> PortHealth {
        states[id]?.portHealth ?? .idle
    }

    func isManagedRunning(_ id: UUID) -> Bool {
        processes[id] != nil && (states[id]?.status == .running || states[id]?.status == .starting)
    }

    /// Prefer the live bound port while running; fall back to configured port.
    func effectivePort(for project: DevProject) -> Int? {
        if let bound = states[project.id]?.boundPort {
            return bound
        }
        return project.port
    }

    /// Default: remap to next free port when busy (do not kill other apps).
    func start(_ project: DevProject, forceKillPort: Bool = false, clearCache: Bool = false) {
        Task { await startAsync(project, forceKillPort: forceKillPort, clearCache: clearCache) }
    }

    func restart(_ project: DevProject, clearCache: Bool = false) {
        Task { await restartAsync(project, clearCache: clearCache) }
    }

    func restartAsync(_ project: DevProject, clearCache: Bool = false) async {
        appendLog(project.id, clearCache ? "Restarting with clear cache…" : "Restarting…")
        await stopAsync(project)
        try? await Task.sleep(nanoseconds: 350_000_000)
        await startAsync(project, clearCache: clearCache)
    }

    /// Send a key/command to the running process stdin (Metro / Flutter).
    @discardableResult
    func sendInput(_ project: DevProject, _ text: String) -> Bool {
        guard processes[project.id] != nil, let pipe = stdinPipes[project.id] else {
            appendLog(project.id, "No running process to send input.")
            return false
        }
        let payload = text.hasSuffix("\n") ? text : text + "\n"
        guard let data = payload.data(using: .utf8) else { return false }
        pipe.fileHandleForWriting.write(data)
        appendLog(project.id, "→ \(payload.trimmingCharacters(in: .newlines))")
        return true
    }

    func hotReload(_ project: DevProject) {
        let framework = FrameworkDetector.detect(at: project.path)
        guard framework.supportsHotReload else {
            appendLog(project.id, "Hot reload not supported for \(framework.rawValue) — use Restart.")
            return
        }
        if sendInput(project, "r") {
            appendLog(project.id, "Hot reload requested.")
        }
    }

    func hotRestart(_ project: DevProject) {
        let framework = FrameworkDetector.detect(at: project.path)
        if framework.supportsHotRestart {
            if sendInput(project, "R") {
                appendLog(project.id, "Hot restart requested.")
            }
            return
        }
        // Expo/RN: full process restart is the practical equivalent
        restart(project)
    }

    func openSimulator(_ project: DevProject, platform: String) {
        let framework = FrameworkDetector.detect(at: project.path)
        if framework == .flutter {
            Task { await runFlutterOnDevice(project, platform: platform) }
            return
        }
        if framework == .expo || framework == .reactNative || framework == .ionic {
            Task { await openMetroPlatform(project, platform: platform, deviceID: nil) }
            return
        }
        // Fallback
        let key: String
        switch platform.lowercased() {
        case "ios", "i": key = "i"
        case "android", "a": key = "a"
        case "web", "w": key = "w"
        default: key = platform
        }
        if sendInput(project, key) {
            appendLog(project.id, "Open \(platform) requested.")
        }
    }

    /// Expo / RN / Ionic: force simulator/emulator (or a concrete Connected device), then Metro key.
    func openMetroPlatform(_ project: DevProject, platform: String, deviceID: String?) async {
        let key = platform.lowercased()
        switch key {
        case "ios", "i", "ios-simulator", "simulator":
            let target: MobileDevices.Device?
            if let deviceID,
               let match = MobileDevices.connectedTargets().first(where: { $0.id == deviceID }) {
                target = match
            } else {
                target = MobileDevices.preferredIOSSimulator()
            }
            guard let target else {
                failStart(
                    project.id,
                    "No iOS Simulator found. Install one in Xcode → Settings → Platforms."
                )
                return
            }
            if target.kind == .iosSimulator {
                _ = MobileDevices.prepareIOSSimulator(udid: target.id)
            }
            metroDeviceByProject[project.id] = target.id
            objectWillChange.send()
            appendLog(project.id, "iOS target → \(target.name) [\(target.id)]")
            await ensureMetroRunningThenSend(project, key: "i")

        case "android", "a", "android-emulator", "emulator":
            let target: MobileDevices.Device?
            if let deviceID,
               let match = MobileDevices.connectedTargets().first(where: { $0.id == deviceID }) {
                target = match
            } else if let preferred = MobileDevices.preferredAndroidEmulator() {
                target = preferred
            } else {
                target = nil
            }
            guard let target else {
                failStart(
                    project.id,
                    "No Android Emulator found. Create one in Android Studio → Device Manager."
                )
                return
            }
            // Quick target must never land on a physical phone
            if deviceID == nil && target.kind == .androidDevice {
                failStart(
                    project.id,
                    "No Android Emulator found (physical device ignored). Create one in Android Studio."
                )
                return
            }
            metroDeviceByProject[project.id] = target.id
            objectWillChange.send()
            appendLog(project.id, "Android target → \(target.name) [\(target.id)]")
            await ensureMetroRunningThenSend(project, key: "a", androidSerial: target.id)

        case "web", "w", "chrome":
            appendLog(project.id, "Web target → browser")
            await ensureMetroRunningThenSend(project, key: "w")

        default:
            if sendInput(project, key) {
                appendLog(project.id, "Open \(platform) requested.")
            }
        }
    }

    func openMetroDevice(_ project: DevProject, device: MobileDevices.Device) async {
        switch device.kind {
        case .iosSimulator, .iosDevice:
            await openMetroPlatform(project, platform: "ios", deviceID: device.id)
        case .androidEmulator, .androidDevice:
            await openMetroPlatform(project, platform: "android", deviceID: device.id)
        }
    }

    func selectedMetroDeviceID(for projectID: UUID) -> String? {
        metroDeviceByProject[projectID]
    }

    private func ensureMetroRunningThenSend(
        _ project: DevProject,
        key: String,
        androidSerial: String? = nil
    ) async {
        if processes[project.id] == nil {
            appendLog(project.id, "Starting Metro / Expo first…")
            await startAsync(project)
            // Give bundler a moment before device open keys
            try? await Task.sleep(nanoseconds: 1_800_000_000)
        }
        if let androidSerial {
            // Hint for tools that honor ANDROID_SERIAL; Expo/RN adb usually picks first device —
            // we still log the chosen serial so users can verify.
            appendLog(project.id, "ANDROID_SERIAL=\(androidSerial)")
        }
        if sendInput(project, key) {
            appendLog(project.id, "Sent Metro key '\(key)'.")
        }
    }

    /// Restart (or start) Flutter with `flutter run -d <device>`.
    func runFlutterOnDevice(_ project: DevProject, platform: String) async {
        let path = project.path
        let resolved = await Task.detached(priority: .userInitiated) {
            FlutterDevices.resolve(platform: platform, at: path)
        }.value

        guard let resolved else {
            let hint: String
            switch platform.lowercased() {
            case "ios", "i", "ios-simulator", "simulator":
                hint = "No iOS Simulator found. Install one in Xcode → Settings → Platforms."
            case "android", "a", "android-emulator", "emulator":
                hint = "No Android Emulator found. Create one in Android Studio → Device Manager."
            default:
                hint = "Could not resolve Flutter device for \(platform)."
            }
            failStart(project.id, hint)
            return
        }

        await runFlutterOnDeviceID(project, deviceID: resolved.id, label: resolved.label)
    }

    /// Start / restart on an exact device id from `flutter devices`.
    func runFlutterOnDeviceID(_ project: DevProject, deviceID: String, label: String) async {
        flutterDeviceByProject[project.id] = deviceID
        objectWillChange.send()
        appendLog(project.id, "Flutter target → \(label) [\(deviceID)]")
        await restartAsync(project)
    }

    func selectedFlutterDeviceID(for projectID: UUID) -> String? {
        flutterDeviceByProject[projectID]
    }

    func listFlutterDevices(_ project: DevProject) {
        let path = project.path
        Task {
            let lines = await Task.detached(priority: .utility) {
                FlutterDevices.summaryLines(at: path)
            }.value
            appendLog(project.id, "Flutter devices:")
            for line in lines {
                appendLog(project.id, line)
            }
        }
    }

    func startAsync(_ project: DevProject, forceKillPort: Bool = false, clearCache: Bool = false) async {
        if processes[project.id] != nil {
            appendLog(project.id, "Already running.")
            return
        }

        var state = states[project.id] ?? RuntimeState()
        state.status = .starting
        state.lastError = nil
        state.boundPort = nil
        state.portNotice = nil
        state.portHealth = .idle
        states[project.id] = state

        // Re-detect at start so stale React/3000 cache cannot break Expo/RN.
        let path = project.path
        let detected = await Task.detached(priority: .utility) { () -> (Framework, Int?, [String]) in
            let framework = FrameworkDetector.detect(at: path)
            let port = FrameworkDetector.detectPort(at: path, framework: framework)
            let command = StartCommandResolver.resolve(at: path, framework: framework, port: port)
            return (framework, port, command)
        }.value

        let framework = detected.0
        let baseCommand = project.customStartCommand ?? detected.2
        let flutterDeviceID = flutterDeviceByProject[project.id]
        let flutterIsWeb = framework == .flutter && flutterDeviceIsWeb(flutterDeviceID)
        // Flutter mobile/desktop don't bind a fixed host port — only Chrome/web needs one.
        let preferredPort: Int? = {
            if framework == .flutter {
                return flutterIsWeb ? (detected.1 ?? project.port ?? 8080) : nil
            }
            return detected.1 ?? project.port
        }()

        if framework != project.framework || preferredPort != project.port {
            appendLog(
                project.id,
                "Detected \(framework.rawValue)"
                    + (preferredPort.map { " · localhost:\($0)" } ?? "")
            )
        }

        var effectivePort = preferredPort
        if let preferred = preferredPort {
            let busy = await Task.detached(priority: .utility) {
                PortManager.isPortInUse(preferred)
            }.value
            if busy {
                if forceKillPort {
                    appendLog(project.id, "Port \(preferred) busy — killing process…")
                    await Task.detached(priority: .utility) {
                        PortManager.killPort(preferred)
                    }.value
                    effectivePort = preferred
                } else {
                    let free = await Task.detached(priority: .utility) {
                        PortManager.nextFreePort(preferred: preferred)
                    }.value
                    guard let free else {
                        failStart(project.id, "Port \(preferred) busy and no free port nearby.")
                        return
                    }
                    effectivePort = free
                    if free != preferred {
                        let notice = "Port \(preferred) is busy — starting on \(free)."
                        var noted = states[project.id] ?? RuntimeState()
                        noted.portNotice = notice
                        states[project.id] = noted
                        appendLog(project.id, "⚠️ \(notice)")
                    }
                }
            }
        }

        let command: [String]
        if framework == .flutter {
            var flutterCmd = baseCommand
            if let deviceID = flutterDeviceByProject[project.id] {
                flutterCmd = StartCommandResolver.ensuringFlutterDevice(deviceID, command: flutterCmd)
            }
            if clearCache {
                flutterCmd = StartCommandResolver.ensuringFlutterPurgeCache(command: flutterCmd)
            }
            // Chrome/web: honor remapped port via --web-port
            if let effectivePort, flutterIsWeb {
                flutterCmd = StartCommandResolver.ensuringFlutterWebPort(effectivePort, command: flutterCmd)
            }
            command = flutterCmd
        } else if let effectivePort {
            if framework.usesMetroBundler {
                var metro = StartCommandResolver.ensuringPortArgument(port: effectivePort, command: baseCommand)
                if clearCache {
                    metro = StartCommandResolver.ensuringClearCache(command: metro)
                }
                command = metro
            } else {
                command = StartCommandResolver.applying(port: effectivePort, to: baseCommand)
            }
        } else if clearCache, framework.usesMetroBundler {
            command = StartCommandResolver.ensuringClearCache(command: baseCommand)
        } else {
            command = baseCommand
        }

        guard let executable = Toolchain.resolveExecutable(command[0], path: project.path) else {
            failStart(project.id, "Command not found: \(command[0]) (check PATH / install tool)")
            return
        }

        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())

        var env = Toolchain.processEnvironment()
        if let effectivePort {
            env["PORT"] = "\(effectivePort)"
            env["APP_PORT"] = "\(effectivePort)"
            env["HOST"] = env["HOST"] ?? "127.0.0.1"
            if framework.usesMetroBundler {
                env["RCT_METRO_PORT"] = "\(effectivePort)"
                env["EXPO_NO_TELEMETRY"] = "1"
                // Do NOT set CI=1 — stdin needed for reload / i / a shortcuts.
            }
            if framework == .vite {
                env["VITE_PORT"] = "\(effectivePort)"
            }
        }
        process.environment = env

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        stdinPipes[project.id] = stdin

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.handleTermination(projectID: project.id, process: proc)
            }
        }

        do {
            try process.run()
            let pid = process.processIdentifier
            setpgid(pid, pid)

            processes[project.id] = process
            var running = states[project.id] ?? RuntimeState()
            running.status = .running
            running.pid = pid
            running.boundPort = effectivePort
            running.portHealth = effectivePort == nil ? .idle : .waiting
            states[project.id] = running
            appendLog(project.id, "Started: \(command.joined(separator: " ")) (pid \(pid))")
            if let effectivePort {
                appendLog(project.id, "Listening intent: localhost:\(effectivePort)")
                beginHealthProbe(for: project.id, port: effectivePort)
            }
            appendLog(project.id, "PATH tool: \(executable)")
            attachReader(projectID: project.id, pipe: stdout, label: nil)
            attachReader(projectID: project.id, pipe: stderr, label: nil)
            resourcePathByProject[project.id] = project.path
            refreshResourceHintsAsync(for: project.id)
        } catch {
            stdinPipes[project.id] = nil
            failStart(project.id, "Failed to start: \(error.localizedDescription)")
        }
    }

    /// Mark error + one-line reason (UI opens log drawer via status change).
    private func failStart(_ projectID: UUID, _ reason: String) {
        cancelHealthProbe(projectID)
        var failed = states[projectID] ?? RuntimeState()
        failed.status = .error
        failed.lastError = StartFailureReason.shortLine(reason)
        failed.boundPort = nil
        failed.pid = nil
        failed.portHealth = .idle
        states[projectID] = failed
        appendLog(projectID, reason)
    }

    /// Keep probing while a managed or external stack should answer on `port`.
    func ensureHealthProbe(for projectID: UUID, port: Int?, alive: Bool) {
        guard alive, let port else {
            cancelHealthProbe(projectID)
            if var state = states[projectID], state.portHealth != .idle {
                state.portHealth = .idle
                states[projectID] = state
            }
            return
        }
        if healthTasks[projectID] != nil { return }
        if states[projectID] == nil {
            var state = RuntimeState()
            state.boundPort = port
            state.portHealth = .waiting
            states[projectID] = state
        } else if var state = states[projectID] {
            if state.portHealth == .idle {
                state.portHealth = .waiting
                state.boundPort = state.boundPort ?? port
                states[projectID] = state
            }
        }
        beginHealthProbe(for: projectID, port: port)
    }

    /// Block until HTTP ready (or timeout). Used by workspace browser open.
    func waitUntilReady(_ projectID: UUID, timeoutSeconds: Double = 18) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if states[projectID]?.portHealth == .ready { return true }
            if status(for: projectID) == .error { return false }
            if healthTasks[projectID] == nil, states[projectID]?.portHealth != .waiting {
                return states[projectID]?.portHealth == .ready
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return states[projectID]?.portHealth == .ready
    }

    private func beginHealthProbe(for projectID: UUID, port: Int) {
        cancelHealthProbe(projectID)
        if var state = states[projectID], state.portHealth == .idle {
            state.portHealth = .waiting
            states[projectID] = state
        }

        healthTasks[projectID] = Task { [weak self] in
            var announcedReady = false
            // Fast poll until ready (~90s), then slow confirm.
            for _ in 0..<90 {
                if Task.isCancelled { return }
                let ok = await HealthProbe.httpReachable(port: port)
                await MainActor.run {
                    guard let self, var state = self.states[projectID] else { return }
                    if ok {
                        if state.portHealth != .ready {
                            state.portHealth = .ready
                            state.lastActivityAt = Date()
                            self.states[projectID] = state
                            if !announcedReady {
                                announcedReady = true
                                self.appendLog(projectID, "Ready · http://localhost:\(port)")
                                NotificationCenter.default.post(
                                    name: .devDockProjectReady,
                                    object: nil,
                                    userInfo: [
                                        "projectID": projectID.uuidString,
                                        "port": port,
                                    ]
                                )
                            }
                        }
                    } else if state.portHealth != .ready {
                        state.portHealth = .waiting
                        self.states[projectID] = state
                    }
                }
                if announcedReady { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { return }
                let ok = await HealthProbe.httpReachable(port: port)
                await MainActor.run {
                    guard let self, var state = self.states[projectID] else { return }
                    let next: PortHealth = ok ? .ready : .waiting
                    if state.portHealth != next {
                        state.portHealth = next
                        self.states[projectID] = state
                        if next == .ready {
                            self.appendLog(projectID, "Ready again · http://localhost:\(port)")
                        } else {
                            self.appendLog(projectID, "HTTP not responding on :\(port)")
                        }
                    }
                }
            }
        }
    }

    private func cancelHealthProbe(_ projectID: UUID) {
        healthTasks[projectID]?.cancel()
        healthTasks[projectID] = nil
    }

    func stop(_ project: DevProject) {
        Task { await stopAsync(project) }
    }

    func stopAsync(_ project: DevProject) async {
        cancelHealthProbe(project.id)
        let portToFree = effectivePort(for: project)

        guard let process = processes[project.id] else {
            if let portToFree {
                appendLog(project.id, "No tracked process — freeing port \(portToFree)…")
                await Task.detached(priority: .utility) {
                    PortManager.killPort(portToFree)
                }.value
            }
            var state = states[project.id] ?? RuntimeState()
            state.status = .offline
            state.pid = nil
            state.boundPort = nil
            state.portNotice = nil
            state.portHealth = .idle
            states[project.id] = state
            return
        }

        var state = states[project.id] ?? RuntimeState()
        state.status = .stopping
        states[project.id] = state
        appendLog(project.id, "Stopping…")

        let pid = process.processIdentifier
        await Task.detached(priority: .userInitiated) {
            // Kill process group if we became leader; also walk the tree
            kill(-pid, SIGTERM)
            PortManager.killProcessTree(pid: pid)
            Thread.sleep(forTimeInterval: 0.4)
            if let portToFree, PortManager.isPortInUse(portToFree) {
                PortManager.killPort(portToFree)
            }
        }.value

        if process.isRunning {
            process.terminate()
        }

        readers[project.id]?.forEach { $0.cancel() }
        readers[project.id] = nil
        processes[project.id] = nil
        stdinPipes[project.id] = nil

        var offline = states[project.id] ?? RuntimeState()
        offline.status = .offline
        offline.pid = nil
        offline.cpuHint = nil
        offline.memoryHint = nil
        offline.boundPort = nil
        offline.portNotice = nil
        states[project.id] = offline
        resourcePathByProject[project.id] = nil
        appendLog(project.id, "Stopped.")
    }

    func clearLogs(for id: UUID) {
        guard var state = states[id] else { return }
        state.logs = []
        states[id] = state
    }

    func note(_ id: UUID, _ message: String) {
        appendLog(id, message)
    }

    private func handleTermination(projectID: UUID, process: Process) {
        // stopAsync may have already cleaned up
        guard processes[projectID] != nil || states[projectID]?.status == .running
                || states[projectID]?.status == .starting else {
            return
        }
        cancelHealthProbe(projectID)
        readers[projectID]?.forEach { $0.cancel() }
        readers[projectID] = nil
        processes[projectID] = nil
        stdinPipes[projectID] = nil
        resourcePathByProject[projectID] = nil
        var state = states[projectID] ?? RuntimeState()
        if state.status == .stopping {
            state.status = .offline
        } else {
            state.status = process.terminationStatus == 0 ? .offline : .error
            if process.terminationStatus != 0 {
                state.lastError = StartFailureReason.summarize(
                    from: state.logs,
                    fallback: "Exited with code \(process.terminationStatus)"
                )
            }
        }
        state.pid = nil
        state.cpuHint = nil
        state.memoryHint = nil
        state.boundPort = nil
        state.portNotice = nil
        state.portHealth = .idle
        states[projectID] = state
        appendLog(projectID, "Process exited (\(process.terminationStatus))")
    }

    private func attachReader(projectID: UUID, pipe: Pipe, label: String?) {
        let handle = pipe.fileHandleForReading
        let source = DispatchSource.makeReadSource(fileDescriptor: handle.fileDescriptor, queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            let lines = chunk.split(whereSeparator: \.isNewline).map(String.init)
            Task { @MainActor in
                for line in lines where !line.isEmpty {
                    let prefix = label.map { "[\($0)] " } ?? ""
                    self?.appendLog(projectID, prefix + line)
                }
            }
        }
        source.setCancelHandler {
            try? handle.close()
        }
        source.resume()
        var list = readers[projectID] ?? []
        list.append(source)
        readers[projectID] = list
    }

    private func appendLog(_ id: UUID, _ line: String) {
        var state = states[id] ?? RuntimeState()
        let stamp = Self.timeFormatter.string(from: Date())
        state.logs.append("[\(stamp)] \(line)")
        state.lastActivityAt = Date()
        if state.logs.count > 800 {
            state.logs.removeFirst(state.logs.count - 800)
        }
        states[id] = state
    }

    func touchActivity(for id: UUID) {
        guard var state = states[id] else { return }
        state.lastActivityAt = Date()
        states[id] = state
    }

    func lastActivity(for id: UUID) -> Date? {
        states[id]?.lastActivityAt
    }

    /// Run a one-shot fix command (npm install, flutter pub get, …) with logs.
    func runFixCommand(_ project: DevProject, command: [String], title: String) async {
        appendLog(project.id, "Fix · \(title)…")
        guard let executable = Toolchain.resolveExecutable(command[0], path: project.path) else {
            appendLog(project.id, "Command not found: \(command[0]) (check PATH / install tool)")
            return
        }

        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())
        process.environment = Toolchain.processEnvironment()

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            attachReader(projectID: project.id, pipe: stdout, label: "fix")
            attachReader(projectID: project.id, pipe: stderr, label: "fix")
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .utility).async {
                    process.waitUntilExit()
                    cont.resume()
                }
            }
            appendLog(project.id, "Fix finished (\(process.terminationStatus)): \(title)")
        } catch {
            appendLog(project.id, "Fix failed: \(error.localizedDescription)")
        }
    }

    /// Refresh CPU/RAM for every managed running process (tree + related app processes).
    func refreshAllResourceHints() {
        for (id, state) in states where state.status == .running || state.status == .starting {
            refreshResourceHintsAsync(for: id)
        }
    }

    private func refreshResourceHintsAsync(for id: UUID) {
        guard let pid = states[id]?.pid else { return }
        let flutterDevice = flutterDeviceByProject[id]
        let metroDevice = metroDeviceByProject[id]
        let projectPath = resourcePathByProject[id]

        Task {
            let sample = await Task.detached(priority: .utility) {
                Self.aggregateResources(
                    rootPID: pid,
                    flutterDeviceID: flutterDevice,
                    metroDeviceID: metroDevice,
                    projectPath: projectPath
                )
            }.value
            guard let sample else { return }
            var state = states[id] ?? RuntimeState()
            guard state.status == .running || state.status == .starting else { return }
            state.cpuHint = String(format: "%.0f%% CPU", sample.cpu)
            state.memoryHint = sample.memoryMB >= 100
                ? String(format: "%.0fMB RAM", sample.memoryMB)
                : String(format: "%.1fMB RAM", sample.memoryMB)
            states[id] = state
        }
    }

    private struct ResourceSample {
        var cpu: Double
        var memoryMB: Double
    }

    /// Sum CPU / RSS across the managed process tree/group and related Simulator apps.
    nonisolated private static func aggregateResources(
        rootPID: Int32,
        flutterDeviceID: String?,
        metroDeviceID: String?,
        projectPath: String?
    ) -> ResourceSample? {
        var pids = Set<Int32>()
        collectDescendants(of: rootPID, into: &pids, depth: 0)
        pids.insert(rootPID)

        if let pgid = processGroupID(of: rootPID) {
            for member in processGroupMembers(pgid) {
                pids.insert(member)
            }
        }

        // Flutter / Expo iOS: include the app process inside the Simulator (not a child of flutter/metro).
        let simDevice = [flutterDeviceID, metroDeviceID]
            .compactMap { $0 }
            .first { $0.count >= 20 && $0.contains("-") }
        if let simDevice {
            for pid in simulatorAppPIDs(deviceUDID: simDevice, projectPath: projectPath) {
                pids.insert(pid)
            }
        }

        var totalCPU = 0.0
        var totalRSSKb = 0.0
        var any = false
        for pid in pids {
            guard let row = samplePID(pid) else { continue }
            totalCPU += row.cpu
            totalRSSKb += row.rssKb
            any = true
        }
        guard any else { return nil }
        return ResourceSample(cpu: totalCPU, memoryMB: totalRSSKb / 1024)
    }

    nonisolated private static func collectDescendants(of pid: Int32, into set: inout Set<Int32>, depth: Int) {
        guard depth < 8 else { return }
        let children = shell(["/usr/bin/pgrep", "-P", "\(pid)"])
            .split(whereSeparator: \.isNewline)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
        for child in children where set.insert(child).inserted {
            collectDescendants(of: child, into: &set, depth: depth + 1)
        }
    }

    nonisolated private static func processGroupID(of pid: Int32) -> Int32? {
        let output = shell(["/bin/ps", "-o", "pgid=", "-p", "\(pid)"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Int32(output)
    }

    nonisolated private static func processGroupMembers(_ pgid: Int32) -> [Int32] {
        shell(["/bin/ps", "-o", "pid=", "-g", "\(pgid)"])
            .split(whereSeparator: \.isNewline)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    nonisolated private static func samplePID(_ pid: Int32) -> (cpu: Double, rssKb: Double)? {
        let output = shell(["/bin/ps", "-o", "%cpu=,rss=", "-p", "\(pid)"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = output.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 2,
              let cpu = Double(parts[0]),
              let rss = Double(parts[1]) else { return nil }
        return (cpu, rss)
    }

    /// Find user app processes hosted in a booted Simulator device.
    nonisolated private static func simulatorAppPIDs(deviceUDID: String, projectPath: String?) -> [Int32] {
        let needle = "/CoreSimulator/Devices/\(deviceUDID)/"
        let projectToken = projectPath.map { URL(fileURLWithPath: $0).lastPathComponent.lowercased() }
        let output = shell(["/bin/ps", "-axo", "pid=,command="])
        var result: [Int32] = []

        for line in output.split(whereSeparator: \.isNewline) {
            let raw = String(line)
            guard raw.contains(needle), raw.contains(".app/") else { continue }
            // Skip obvious system processes inside the sim
            let lower = raw.lowercased()
            if lower.contains("springboard.app")
                || lower.contains("backboardd")
                || lower.contains("axassetsd")
                || lower.contains("search.framework") {
                continue
            }

            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard let space = trimmed.firstIndex(of: " ") else { continue }
            let pidStr = String(trimmed[..<space]).trimmingCharacters(in: .whitespaces)
            guard let pid = Int32(pidStr) else { continue }

            let isRunner = lower.contains("runner.app/runner")
            let isExpoGo = lower.contains("expo go.app") || lower.contains("expogo.app")
            let matchesProject: Bool = {
                guard let projectToken, !projectToken.isEmpty else { return false }
                return lower.contains(projectToken)
            }()

            // Prefer the app binary itself (…/Something.app/Something), not helpers.
            let isAppBinary = raw.range(of: #"/[^/]+\.app/[^/\s]+$"#, options: .regularExpression) != nil
                || lower.contains("runner.app/runner")

            if isRunner || isExpoGo || matchesProject || (isAppBinary && lower.contains("/containers/bundle/application/")) {
                result.append(pid)
            }
        }
        return result
    }

    private func flutterDeviceIsWeb(_ deviceID: String?) -> Bool {
        guard let deviceID else { return false }
        let id = deviceID.lowercased()
        return id == "chrome" || id == "web" || id == "edge" || id.contains("web-javascript")
    }

    nonisolated private static func shell(_ args: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
