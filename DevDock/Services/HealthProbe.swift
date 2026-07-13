import Foundation

/// Lightweight localhost readiness check (any HTTP response = server is up).
enum HealthProbe {
    static func httpReachable(port: Int) async -> Bool {
        guard port > 0, port < 65536,
              let url = URL(string: "http://127.0.0.1:\(port)/") else {
            return false
        }

        var request = URLRequest(url: url, timeoutInterval: 1.25)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("DevDock-Health/1", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response is HTTPURLResponse
        } catch {
            // Connection refused / timeout → not ready yet.
            return false
        }
    }
}

enum PortHealth: Equatable {
    /// No host port to probe (e.g. Flutter device run).
    case idle
    /// Process up; waiting for HTTP.
    case waiting
    /// HTTP answered on localhost.
    case ready

    var label: String {
        switch self {
        case .idle: return "—"
        case .waiting: return "Waiting…"
        case .ready: return "Ready"
        }
    }
}
