import Foundation

enum Toolchain {
    private static var cachedLoginPATH: String?
    private static let lock = NSLock()

    /// PATH suitable for GUI apps (Finder / Xcode launch), not just Terminal.
    static func enrichedPATH() -> String {
        var parts: [String] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let preferred = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "\(home)/.local/bin",
            "\(home)/.yarn/bin",
            "\(home)/.fnm/current/bin",
            "\(home)/.volta/bin",
            "\(home)/Library/Application Support/fnm/aliases/default/bin",
            "\(home)/.asdf/shims",
            "\(home)/.phpenv/shims",
            "\(home)/.rbenv/shims",
            "\(home)/.pyenv/shims",
            "\(home)/.cargo/bin",
            "\(home)/go/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]

        parts.append(contentsOf: preferred)
        parts.append(contentsOf: nvmBinDirs(home: home))

        if let login = loginShellPATH() {
            parts.append(contentsOf: login.split(separator: ":").map(String.init))
        }

        if let current = ProcessInfo.processInfo.environment["PATH"] {
            parts.append(contentsOf: current.split(separator: ":").map(String.init))
        }

        var seen = Set<String>()
        var unique: [String] = []
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            unique.append(trimmed)
        }
        return unique.joined(separator: ":")
    }

    static func processEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = enrichedPATH()
        env["HOME"] = env["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        // Help Node/npm when launched outside a login shell
        if env["NPM_CONFIG_YES"] == nil {
            env["NPM_CONFIG_UPDATE_NOTIFIER"] = "false"
        }
        return env
    }

    static func resolveExecutable(_ command: String, path: String? = nil) -> String? {
        if command.hasPrefix("/") {
            return FileManager.default.isExecutableFile(atPath: command) ? command : nil
        }
        if command.contains("/") {
            // Relative binary like bin/rails
            if let path {
                let full = (path as NSString).appendingPathComponent(command)
                if FileManager.default.isExecutableFile(atPath: full) { return full }
            }
            return command
        }

        let pathEnv = path.map { _ in enrichedPATH() } ?? enrichedPATH()
        for dir in pathEnv.split(separator: ":") {
            let candidate = "\(dir)/\(command)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func loginShellPATH() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cachedLoginPATH { return cachedLoginPATH }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", "printenv PATH"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(2)
            while process.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                process.terminate()
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let value = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let value, !value.isEmpty {
                cachedLoginPATH = value
                return value
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func nvmBinDirs(home: String) -> [String] {
        let versions = "\(home)/.nvm/versions/node"
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: versions) else {
            return []
        }
        return names
            .sorted()
            .reversed()
            .prefix(3)
            .map { "\(versions)/\($0)/bin" }
    }
}
