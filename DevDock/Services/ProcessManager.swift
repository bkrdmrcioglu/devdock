import Foundation
import Combine

@MainActor
final class ProcessManager: ObservableObject {
    struct RuntimeState {
        var status: ProjectStatus = .offline
        var pid: Int32?
        var logs: [String] = []
        var lastError: String?
        var cpuHint: String?
        var memoryHint: String?
    }

    @Published private(set) var states: [UUID: RuntimeState] = [:]

    private var processes: [UUID: Process] = [:]
    private var readers: [UUID: [DispatchSourceRead]] = [:]

    func status(for id: UUID) -> ProjectStatus {
        states[id]?.status ?? .offline
    }

    func logs(for id: UUID) -> [String] {
        states[id]?.logs ?? []
    }

    func start(_ project: DevProject, forceKillPort: Bool = true) {
        Task { await startAsync(project, forceKillPort: forceKillPort) }
    }

    func startAsync(_ project: DevProject, forceKillPort: Bool = true) async {
        if processes[project.id] != nil {
            appendLog(project.id, "Already running.")
            return
        }

        var state = states[project.id] ?? RuntimeState()
        state.status = .starting
        state.lastError = nil
        states[project.id] = state

        if let port = project.port {
            let busy = await Task.detached(priority: .utility) {
                PortManager.isPortInUse(port)
            }.value
            if busy {
                if forceKillPort {
                    appendLog(project.id, "Port \(port) busy — killing process…")
                    await Task.detached(priority: .utility) {
                        PortManager.killPort(port)
                    }.value
                } else {
                    var failed = states[project.id] ?? RuntimeState()
                    failed.status = .error
                    failed.lastError = "Port \(port) already in use."
                    states[project.id] = failed
                    appendLog(project.id, failed.lastError!)
                    return
                }
            }
        }

        let command = project.startCommand
        guard let executable = Toolchain.resolveExecutable(command[0], path: project.path) else {
            var failed = states[project.id] ?? RuntimeState()
            failed.status = .error
            failed.lastError = "Command not found: \(command[0]) (check PATH / install tool)"
            states[project.id] = failed
            appendLog(project.id, failed.lastError!)
            return
        }

        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())

        var env = Toolchain.processEnvironment()
        if let port = project.port {
            env["PORT"] = "\(port)"
            env["APP_PORT"] = "\(port)"
        }
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.handleTermination(projectID: project.id, process: proc)
            }
        }

        do {
            try process.run()
            // Best-effort: make this pid a process group leader for cleanup
            let pid = process.processIdentifier
            setpgid(pid, pid)

            processes[project.id] = process
            var running = states[project.id] ?? RuntimeState()
            running.status = .running
            running.pid = pid
            states[project.id] = running
            appendLog(project.id, "Started: \(command.joined(separator: " ")) (pid \(pid))")
            appendLog(project.id, "PATH tool: \(executable)")
            attachReader(projectID: project.id, pipe: stdout, label: nil)
            attachReader(projectID: project.id, pipe: stderr, label: nil)
            refreshResourceHintsAsync(for: project.id)
        } catch {
            var failed = states[project.id] ?? RuntimeState()
            failed.status = .error
            failed.lastError = error.localizedDescription
            states[project.id] = failed
            appendLog(project.id, "Failed to start: \(error.localizedDescription)")
        }
    }

    func stop(_ project: DevProject) {
        Task { await stopAsync(project) }
    }

    func stopAsync(_ project: DevProject) async {
        guard let process = processes[project.id] else {
            if let port = project.port {
                appendLog(project.id, "No tracked process — freeing port \(port)…")
                await Task.detached(priority: .utility) {
                    PortManager.killPort(port)
                }.value
            }
            var state = states[project.id] ?? RuntimeState()
            state.status = .offline
            state.pid = nil
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
            if let port = project.port, PortManager.isPortInUse(port) {
                PortManager.killPort(port)
            }
        }.value

        if process.isRunning {
            process.terminate()
        }

        readers[project.id]?.forEach { $0.cancel() }
        readers[project.id] = nil
        processes[project.id] = nil

        var offline = states[project.id] ?? RuntimeState()
        offline.status = .offline
        offline.pid = nil
        offline.cpuHint = nil
        offline.memoryHint = nil
        states[project.id] = offline
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
        readers[projectID]?.forEach { $0.cancel() }
        readers[projectID] = nil
        processes[projectID] = nil
        var state = states[projectID] ?? RuntimeState()
        if state.status == .stopping {
            state.status = .offline
        } else {
            state.status = process.terminationStatus == 0 ? .offline : .error
            if process.terminationStatus != 0 {
                state.lastError = "Exited with code \(process.terminationStatus)"
            }
        }
        state.pid = nil
        state.cpuHint = nil
        state.memoryHint = nil
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
        if state.logs.count > 800 {
            state.logs.removeFirst(state.logs.count - 800)
        }
        states[id] = state
    }

    private func refreshResourceHintsAsync(for id: UUID) {
        guard let pid = states[id]?.pid else { return }
        Task {
            let output = await Task.detached(priority: .utility) {
                Self.shell(["/bin/ps", "-o", "%cpu=,rss=", "-p", "\(pid)"])
            }.value
            let parts = output.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2,
                  let cpu = Double(parts[0]),
                  let rssKb = Double(parts[1]) else { return }
            var state = states[id] ?? RuntimeState()
            state.cpuHint = String(format: "%.0f%% CPU", cpu)
            state.memoryHint = String(format: "%.0fMB RAM", rssKb / 1024)
            states[id] = state
        }
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
