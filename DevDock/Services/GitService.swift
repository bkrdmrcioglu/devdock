import Foundation

struct GitInfo: Equatable {
    var branch: String
    var changed: Int
    var staged: Int
    var ahead: Int
    var behind: Int

    var summary: String {
        var parts: [String] = []
        if changed > 0 { parts.append("\(changed) changed") }
        if ahead > 0 { parts.append("\(ahead) push") }
        if behind > 0 { parts.append("\(behind) pull") }
        return parts.isEmpty ? "Clean" : parts.joined(separator: " · ")
    }
}

enum GitService {
    static func info(at path: String) -> GitInfo? {
        let gitDir = (path as NSString).appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir) else {
            return nil
        }

        let branch = run(in: path, ["rev-parse", "--abbrev-ref", "HEAD"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty else { return nil }

        // Porcelain only — avoid @{u} which errors without upstream
        let status = run(in: path, ["status", "--porcelain", "-uno"])
        let changed = status.split(whereSeparator: \.isNewline).count

        return GitInfo(branch: branch, changed: changed, staged: 0, ahead: 0, behind: 0)
    }

    private static func run(in path: String, _ args: [String]) -> String {
        let process = Process()
        let out = Pipe()
        let err = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path] + args
        process.standardOutput = out
        process.standardError = err
        process.qualityOfService = .utility
        do {
            try process.run()
            // Safety timeout via poll — never hang forever on flaky volumes
            let deadline = Date().addingTimeInterval(3)
            while process.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                process.terminate()
                return ""
            }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
