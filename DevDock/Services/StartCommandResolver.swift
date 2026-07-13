import Foundation

enum PackageManager: String {
    case npm, pnpm, yarn, bun

    var runPrefix: [String] {
        switch self {
        case .npm: return ["npm", "run"]
        case .pnpm: return ["pnpm", "run"]
        case .yarn: return ["yarn", "run"]
        case .bun: return ["bun", "run"]
        }
    }

    static func detect(at path: String) -> PackageManager {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        if fm.fileExists(atPath: url.appendingPathComponent("bun.lockb").path)
            || fm.fileExists(atPath: url.appendingPathComponent("bun.lock").path) {
            return .bun
        }
        if fm.fileExists(atPath: url.appendingPathComponent("pnpm-lock.yaml").path) {
            return .pnpm
        }
        if fm.fileExists(atPath: url.appendingPathComponent("yarn.lock").path) {
            return .yarn
        }
        return .npm
    }
}

enum StartCommandResolver {
    static func resolve(at path: String, framework: Framework, port: Int?) -> [String] {
        switch framework {
        case .expo, .reactNative:
            return metroCommand(at: path, framework: framework, port: port)

        case .laravel:
            var cmd = ["php", "artisan", "serve"]
            if let port {
                cmd.append(contentsOf: ["--host=127.0.0.1", "--port=\(port)"])
            }
            return cmd

        case .symfony:
            var cmd = ["symfony", "server:start", "--no-tls"]
            if let port {
                cmd.append(contentsOf: ["--port=\(port)"])
            }
            return cmd

        case .django:
            if let port {
                return ["python3", "manage.py", "runserver", "127.0.0.1:\(port)"]
            }
            return ["python3", "manage.py", "runserver"]

        case .fastapi:
            let p = port ?? 8000
            return ["uvicorn", "main:app", "--reload", "--host", "127.0.0.1", "--port", "\(p)"]

        case .flask:
            return framework.startCommand

        case .rails:
            if let port {
                return ["bin/rails", "server", "-p", "\(port)"]
            }
            return ["bin/rails", "server"]

        case .spring:
            if FileManager.default.isExecutableFile(atPath: (path as NSString).appendingPathComponent("mvnw")) {
                return ["./mvnw", "spring-boot:run"]
            }
            if FileManager.default.isExecutableFile(atPath: (path as NSString).appendingPathComponent("gradlew")) {
                return ["./gradlew", "bootRun"]
            }
            return ["mvn", "spring-boot:run"]

        case .dotnet:
            return ["dotnet", "run"]

        case .phoenix:
            return ["mix", "phx.server"]

        case .flutter:
            return FlutterDevices.flutterBaseCommand(at: path) + ["run"]

        case .swift:
            return SwiftProjectStart.command(at: path)

        case .kotlin:
            return AndroidKotlinStart.command(at: path)

        case .go, .rust:
            return framework.startCommand

        case .tauri:
            if FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("package.json")) {
                return nodeCommand(at: path, preferredScripts: ["tauri", "dev", "start"])
            }
            return ["cargo", "tauri", "dev"]

        default:
            // All node-family + unknown with package.json
            if FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("package.json")) {
                return nodeCommand(at: path, preferredScripts: ["dev", "develop", "start", "serve"])
            }
            return framework.startCommand
        }
    }

    private static func metroCommand(at path: String, framework: Framework, port: Int?) -> [String] {
        let pm = PackageManager.detect(at: path)
        let scripts = packageScripts(at: path)
        let preferred = ["start", "dev", "android", "ios"]
        let script = preferred.first { scripts.contains($0) } ?? "start"
        let portValue = port ?? framework.defaultPort ?? 8081
        return pm.runPrefix + [script, "--", "--port", "\(portValue)"]
    }

    private static func nodeCommand(at path: String, preferredScripts: [String]) -> [String] {
        let pm = PackageManager.detect(at: path)
        let scripts = packageScripts(at: path)
        let script = preferredScripts.first { scripts.contains($0) } ?? preferredScripts.first ?? "dev"
        if scripts.contains(script) || script == "dev" {
            // Prefer an existing script; fall back to first preferred name
            let chosen = preferredScripts.first { scripts.contains($0) } ?? "dev"
            return pm.runPrefix + [chosen]
        }
        return pm.runPrefix + ["dev"]
    }

    private static func packageScripts(at path: String) -> Set<String> {
        let url = URL(fileURLWithPath: path).appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: Any] else {
            return []
        }
        return Set(scripts.keys)
    }

    private static func firstMatch(in path: String, suffixes: [String]) -> String? {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: path) else { return nil }
        for suffix in suffixes {
            if let name = items.first(where: { $0.hasSuffix(suffix) }) {
                return (path as NSString).appendingPathComponent(name)
            }
        }
        return nil
    }

    static func parseUserCommand(_ line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        return parts.isEmpty ? nil : parts
    }

    static func display(_ command: [String]) -> String {
        command.joined(separator: " ")
    }

    static func applying(port: Int, to command: [String]) -> [String] {
        guard !command.isEmpty else { return command }
        var result = command
        var i = 0
        while i < result.count {
            let arg = result[i]
            if arg.hasPrefix("--port=") {
                result[i] = "--port=\(port)"
            } else if arg == "--port" || arg == "-p", i + 1 < result.count {
                result[i + 1] = "\(port)"
                i += 1
            } else if arg.contains(":") {
                let parts = arg.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2, Int(parts[1]) != nil {
                    result[i] = "\(parts[0]):\(port)"
                }
            }
            i += 1
        }
        return result
    }

    static func ensuringPortArgument(port: Int, command: [String]) -> [String] {
        if command.contains(where: { $0 == "--port" || $0.hasPrefix("--port=") }) {
            return applying(port: port, to: command)
        }
        var result = command
        let packageManagers: Set<String> = ["npm", "pnpm", "yarn", "bun"]
        if let first = result.first, packageManagers.contains(first) {
            if !result.contains("--") {
                result.append("--")
            }
            result.append(contentsOf: ["--port", "\(port)"])
        } else {
            result.append(contentsOf: ["--port", "\(port)"])
        }
        return result
    }

    /// Expo/Metro clear cache: `expo start -c` / `--clear`.
    static func ensuringClearCache(command: [String]) -> [String] {
        if command.contains("-c") || command.contains("--clear") {
            return command
        }
        var result = command
        let packageManagers: Set<String> = ["npm", "pnpm", "yarn", "bun"]
        if let first = result.first, packageManagers.contains(first) {
            if !result.contains("--") {
                result.append("--")
            }
            result.append("--clear")
        } else {
            result.append("--clear")
        }
        return result
    }

    /// `flutter run -d <id>` — replaces any existing device flag.
    static func ensuringFlutterDevice(_ deviceID: String, command: [String]) -> [String] {
        var result = strippingFlutterDevice(from: command)
        if result.isEmpty {
            result = ["flutter", "run"]
        }
        result.append(contentsOf: ["-d", deviceID])
        return result
    }

    /// Web only: pin `--web-port` so DevDock’s port remap works with Chrome.
    static func ensuringFlutterWebPort(_ port: Int, command: [String]) -> [String] {
        var result = command
        if let idx = result.firstIndex(of: "--web-port"), idx + 1 < result.count {
            result[idx + 1] = "\(port)"
            return result
        }
        if let idx = result.firstIndex(where: { $0.hasPrefix("--web-port=") }) {
            result[idx] = "--web-port=\(port)"
            return result
        }
        result.append(contentsOf: ["--web-port", "\(port)"])
        return result
    }

    static func ensuringFlutterPurgeCache(command: [String]) -> [String] {
        if command.contains("--purge-persistent-cache") {
            return command
        }
        return command + ["--purge-persistent-cache"]
    }

    private static func strippingFlutterDevice(from command: [String]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < command.count {
            let arg = command[i]
            if arg == "-d" || arg == "--device-id" {
                i += 2
                continue
            }
            if arg.hasPrefix("--device-id=") {
                i += 1
                continue
            }
            result.append(arg)
            i += 1
        }
        return result
    }
}
