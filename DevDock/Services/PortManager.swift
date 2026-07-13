import Foundation

enum PortManager {
    static func isPortInUse(_ port: Int) -> Bool {
        !pids(on: port).isEmpty
    }

    static func pids(on port: Int) -> [Int32] {
        let output = shell(["/usr/sbin/lsof", "-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"])
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// Working directories of processes listening on `port` (and parents/children).
    static func listenerWorkingDirectories(on port: Int) -> [String] {
        let ids = pids(on: port)
        guard !ids.isEmpty else { return [] }
        var dirs = Set<String>()
        for pid in ids {
            collectWorkingDirectories(from: pid, into: &dirs, depth: 0)
        }
        return Array(dirs)
    }

    /// Pick the best project path that owns a listener cwd.
    static func bestMatchingProjectPath(cwds: [String], candidates: [String]) -> String? {
        guard !cwds.isEmpty, !candidates.isEmpty else { return nil }
        var best: (path: String, score: Int)?
        for cwd in cwds {
            let standardizedCwd = (cwd as NSString).standardizingPath
            for candidate in candidates {
                let path = (candidate as NSString).standardizingPath
                let score: Int
                if standardizedCwd == path {
                    score = 10_000 + path.count
                } else if standardizedCwd.hasPrefix(path + "/") {
                    score = 5_000 + path.count
                } else if path.hasPrefix(standardizedCwd + "/") {
                    score = 1_000 + standardizedCwd.count
                } else {
                    continue
                }
                if best == nil || score > best!.score {
                    best = (path, score)
                }
            }
        }
        return best?.path
    }

    /// Kill listeners on port. Safe to call off the main thread.
    @discardableResult
    static func killPort(_ port: Int) -> Bool {
        let ids = pids(on: port)
        guard !ids.isEmpty else { return false }
        for pid in ids {
            kill(pid, SIGTERM)
        }
        let deadline = Date().addingTimeInterval(0.6)
        while Date() < deadline {
            if pids(on: port).isEmpty { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        for pid in pids(on: port) {
            kill(pid, SIGKILL)
        }
        return true
    }

    /// Recursively terminate a process and its descendants (npm → node, etc.).
    static func killProcessTree(pid: Int32) {
        let children = childPIDs(of: pid)
        for child in children {
            killProcessTree(pid: child)
        }
        kill(pid, SIGTERM)
        Thread.sleep(forTimeInterval: 0.2)
        kill(pid, SIGKILL)
    }

    private static func collectWorkingDirectories(from pid: Int32, into dirs: inout Set<String>, depth: Int) {
        guard depth < 4 else { return }
        if let cwd = workingDirectory(of: pid) {
            dirs.insert(cwd)
        }
        if let parent = parentPID(of: pid), parent > 1 {
            collectWorkingDirectories(from: parent, into: &dirs, depth: depth + 1)
        }
        for child in childPIDs(of: pid) {
            collectWorkingDirectories(from: child, into: &dirs, depth: depth + 1)
        }
    }

    private static func workingDirectory(of pid: Int32) -> String? {
        let output = shell(["/usr/sbin/lsof", "-a", "-p", "\(pid)", "-d", "cwd", "-Fn"])
        for line in output.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("n"), line.count > 1 {
                let path = String(line.dropFirst())
                if path.hasPrefix("/") {
                    return (path as NSString).standardizingPath
                }
            }
        }
        return nil
    }

    private static func parentPID(of pid: Int32) -> Int32? {
        let output = shell(["/bin/ps", "-o", "ppid=", "-p", "\(pid)"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Int32(output)
    }

    private static func childPIDs(of pid: Int32) -> [Int32] {
        let output = shell(["/usr/bin/pgrep", "-P", "\(pid)"])
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func shell(_ args: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.environment = Toolchain.processEnvironment()
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(3)
            while process.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning { process.terminate() }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
