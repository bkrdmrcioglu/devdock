import Foundation

enum Persistence {
    private static let key = "devdock.settings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum ExternalLauncher {
    static func openBrowser(port: Int) {
        let url = URL(string: "http://localhost:\(port)")!
        open(url)
    }

    static func openFolder(_ path: String) {
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [path])
    }

    static func openTerminal(_ path: String) {
        let script = """
        tell application "Terminal"
          activate
          do script "cd \(escaped(path)) && clear"
        end tell
        """
        Process.launchedProcess(launchPath: "/usr/bin/osascript", arguments: ["-e", script])
    }

    static func openEditor(_ path: String) {
        // Prefer Cursor, then VS Code, then default editor
        let candidates = [
            "/usr/local/bin/cursor",
            "/opt/homebrew/bin/cursor",
            "/usr/local/bin/code",
            "/opt/homebrew/bin/code",
        ]
        for bin in candidates where FileManager.default.isExecutableFile(atPath: bin) {
            Process.launchedProcess(launchPath: bin, arguments: [path])
            return
        }
        // Fallback: open with Cursor/VS Code app bundle if present
        let apps = ["Cursor", "Visual Studio Code"]
        for app in apps {
            let result = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-a", app, path])
            _ = result
            return
        }
        openFolder(path)
    }

    static func openEnvFile(_ path: String) {
        let env = (path as NSString).appendingPathComponent(".env")
        if FileManager.default.fileExists(atPath: env) {
            openEditor(env)
        } else {
            openEditor(path)
        }
    }

    private static func open(_ url: URL) {
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [url.absoluteString])
    }

    private static func escaped(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
