import SwiftUI

enum DevDockTheme {
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.11)
    static let panel = Color(red: 0.11, green: 0.14, blue: 0.17)
    static let panelElevated = Color(red: 0.14, green: 0.18, blue: 0.22)
    static let line = Color.white.opacity(0.08)
    static let mist = Color.white.opacity(0.62)
    static let chalk = Color.white.opacity(0.92)
    static let accent = Color(red: 0.18, green: 0.84, blue: 0.55) // mint — DevDock running
    static let external = Color(red: 1.0, green: 0.78, blue: 0.22) // amber — external running
    static let warn = Color(red: 1.0, green: 0.62, blue: 0.22)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.37)
    static let offline = Color.white.opacity(0.28)

    static let brandFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let titleFont = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let bodyFont = Font.system(size: 13, weight: .regular, design: .default)
    static let mono = Font.system(size: 12, design: .monospaced)
}

struct StatusDot: View {
    let status: ProjectStatus

    var color: Color {
        switch status {
        case .running: return DevDockTheme.accent
        case .external: return DevDockTheme.external
        case .starting, .stopping: return DevDockTheme.warn
        case .error: return DevDockTheme.danger
        case .offline: return DevDockTheme.offline
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(status == .running || status == .external ? 0.7 : 0), radius: 4)
    }
}
