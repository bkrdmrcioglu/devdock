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
        case .nextjs, .react, .vue, .nestjs, .express, .unknown:
            if FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("package.json")) {
                return nodeCommand(at: path, port: port)
            }
            return framework.startCommand
        case .laravel:
            var cmd = ["php", "artisan", "serve"]
            if let port {
                cmd.append(contentsOf: ["--host=127.0.0.1", "--port=\(port)"])
            }
            return cmd
        case .django:
            if let port {
                return ["python3", "manage.py", "runserver", "127.0.0.1:\(port)"]
            }
            return ["python3", "manage.py", "runserver"]
        case .flask:
            return framework.startCommand
        case .rails:
            if let port {
                return ["bin/rails", "server", "-p", "\(port)"]
            }
            return ["bin/rails", "server"]
        case .go, .rust:
            return framework.startCommand
        }
    }

    private static func nodeCommand(at path: String, port: Int?) -> [String] {
        _ = port // PORT injected via ProcessManager environment
        let pm = PackageManager.detect(at: path)
        let scripts = packageScripts(at: path)
        let preferred = ["dev", "develop", "start", "serve"]
        let script = preferred.first { scripts.contains($0) }

        if let script {
            return pm.runPrefix + [script]
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

    /// Parse a user-entered command line into argv (simple whitespace split).
    static func parseUserCommand(_ line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        return parts.isEmpty ? nil : parts
    }

    static func display(_ command: [String]) -> String {
        command.joined(separator: " ")
    }
}
