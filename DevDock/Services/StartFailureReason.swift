import Foundation

/// Short, user-facing reason when Start / device open fails.
enum StartFailureReason {
    static func summarize(from logs: [String], fallback: String?) -> String {
        let blob = logs.suffix(40).joined(separator: "\n").lowercased()

        if blob.contains("command not found")
            || blob.contains("no such file or directory")
            || blob.contains("(check path / install tool)") {
            return "Command not found — check PATH / install the tool"
        }
        if blob.contains("eaddrinuse")
            || blob.contains("address already in use")
            || blob.contains("port") && (blob.contains("busy") || blob.contains("in use")) {
            return "Port busy — another process is using it"
        }
        if blob.contains("no ios simulator")
            || blob.contains("no android emulator")
            || blob.contains("no devices")
            || blob.contains("device not found")
            || blob.contains("unable to find a destination")
            || blob.contains("could not resolve flutter device") {
            return "No device / simulator available"
        }
        if blob.contains("permission denied") {
            return "Permission denied"
        }
        if let fallback, !fallback.isEmpty {
            return shortLine(fallback)
        }
        return "Start failed — check logs"
    }

    static func shortLine(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 96 { return trimmed }
        return String(trimmed.prefix(93)) + "…"
    }
}
