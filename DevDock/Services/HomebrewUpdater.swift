import Foundation
import AppKit

/// Runs Homebrew cask upgrade (with brew update), then relaunches `/Applications/DevDock.app`.
enum HomebrewUpdater {
    struct Result {
        let ok: Bool
        let message: String
        let log: String
        let appURL: URL?
    }

    static var brewPath: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var applicationsAppURL: URL {
        URL(fileURLWithPath: "/Applications/DevDock.app")
    }

    static func resolveInstalledApp() -> URL? {
        let apps = applicationsAppURL
        if isRunnableApp(at: apps) { return apps }

        for root in ["/opt/homebrew/Caskroom/devdock", "/usr/local/Caskroom/devdock"] {
            guard let versions = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            let sorted = versions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
            for version in sorted {
                let candidate = URL(fileURLWithPath: root)
                    .appendingPathComponent(version)
                    .appendingPathComponent("DevDock.app")
                if isRunnableApp(at: candidate) { return candidate }
            }
        }
        return nil
    }

    private static func isRunnableApp(at url: URL) -> Bool {
        let binary = url.appendingPathComponent("Contents/MacOS/DevDock")
        let resolved = url.resolvingSymlinksInPath()
        let resolvedBinary = resolved.appendingPathComponent("Contents/MacOS/DevDock")
        return FileManager.default.isExecutableFile(atPath: binary.path)
            || FileManager.default.isExecutableFile(atPath: resolvedBinary.path)
    }

    /// Refresh taps, then `brew upgrade --cask` (falls back to install if not present).
    static func upgradeCask() async -> Result {
        guard let brew = brewPath else {
            return Result(
                ok: false,
                message: "Homebrew not found. Install from https://brew.sh or use Zip.",
                log: "",
                appURL: nil
            )
        }

        let update = await runBrew(brew, args: ["update"])
        let upgrade = await runBrew(brew, args: ["upgrade", "--cask", "bkrdmrcioglu/devdock/devdock"])
        var log = [update.log, upgrade.log].filter { !$0.isEmpty }.joined(separator: "\n---\n")
        var status = upgrade.status

        let upgraded =
            upgrade.status == 0
            || upgrade.log.lowercased().contains("already installed")
            || upgrade.log.lowercased().contains("up-to-date")
            || upgrade.log.lowercased().contains("was successfully upgraded")

        if !upgraded {
            let install = await runBrew(brew, args: ["install", "--cask", "bkrdmrcioglu/devdock/devdock"])
            log += "\n---\n" + install.log
            status = install.status
        }

        let app = resolveInstalledApp()
        if let app, status == 0 || upgraded {
            return Result(ok: true, message: "Updated. Relaunching…", log: log, appURL: app)
        }
        if let app, FileManager.default.fileExists(atPath: app.path) {
            return Result(ok: true, message: "Ready. Relaunching…", log: log, appURL: app)
        }
        return Result(
            ok: false,
            message: "brew finished but DevDock.app missing in /Applications (status \(status)). Try Zip.",
            log: log,
            appURL: nil
        )
    }

    private static func runBrew(_ brew: String, args: [String]) async -> (status: Int32, log: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brew)
        process.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_ANALYTICS"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        let brewBin = URL(fileURLWithPath: brew).deletingLastPathComponent().path
        let path = env["PATH"] ?? "/usr/bin:/bin"
        if !path.split(separator: ":").map(String.init).contains(brewBin) {
            env["PATH"] = "\(brewBin):\(path)"
        }
        process.environment = env

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do { try process.run() }
        catch {
            return (1, error.localizedDescription)
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                cont.resume()
            }
        }

        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let log = (stdout + "\n" + stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus, log)
    }

    @MainActor
    static func scheduleRelaunch(appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appPath = appURL.resolvingSymlinksInPath().path
        let scriptPath = NSTemporaryDirectory() + "devdock-relaunch-\(pid).sh"
        let body = """
        #!/bin/bash
        for _ in $(seq 1 100); do
          if ! kill -0 \(pid) 2>/dev/null; then break; fi
          sleep 0.15
        done
        sleep 0.4
        /usr/bin/open -n "\(appPath)"
        rm -f "\(scriptPath)"
        """
        do {
            try body.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
        } catch {
            NSWorkspace.shared.open(appURL)
            NSApp.terminate(nil)
            return
        }

        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/bash")
        helper.arguments = [scriptPath]
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice
        do { try helper.run() } catch { NSWorkspace.shared.open(appURL) }
        NSApp.terminate(nil)
    }
}
