import SwiftUI
import AppKit

enum DevDockTheme {
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.11)
    static let panel = Color(red: 0.11, green: 0.14, blue: 0.17)
    static let panelElevated = Color(red: 0.14, green: 0.18, blue: 0.22)
    static let line = Color.white.opacity(0.08)
    static let mist = Color.white.opacity(0.55)
    static let chalk = Color.white.opacity(0.92)
    static let accent = Color(red: 0.18, green: 0.84, blue: 0.55)
    static let external = Color(red: 1.0, green: 0.78, blue: 0.22)
    static let warn = Color(red: 1.0, green: 0.62, blue: 0.22)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.37)
    static let offline = Color.white.opacity(0.28)

    static let brandFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let titleFont = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let bodyFont = Font.system(size: 13, weight: .regular, design: .default)
    static let mono = Font.system(size: 12, design: .monospaced)
}


struct BrandMark: View {
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 7

    var body: some View {
        Image(nsImage: Self.resolvedImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DevDockTheme.line, lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    static var resolvedImage: NSImage {
        NSImage(named: "Logo")
            ?? NSImage(named: NSImage.applicationIconName)
            ?? NSApplication.shared.applicationIconImage
    }
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

/// Section label with optional SF Symbol — clearer hierarchy than tiny ALL-CAPS alone.
struct DetailSectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var accent: Color = DevDockTheme.warn

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            }
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(DevDockTheme.chalk)
                .tracking(0.3)
            Spacer(minLength: 0)
        }
    }
}

struct ShortcutKeyCap: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(DevDockTheme.chalk.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(DevDockTheme.ink.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(DevDockTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// App-level keyboard shortcuts (shown in UI + What’s New).
enum AppShortcuts {
    static let palette = "⌘K"
    static let rescan = "⌘⇧R"
    static let morning = "⌘⇧M"
    static let stopAll = "⌘⇧."

    struct Row: Identifiable {
        let id: String
        let title: String
        let keys: String
        let detail: String
    }

    static let rows: [Row] = [
        Row(id: "palette", title: "Command palette", keys: palette, detail: "Search projects & actions"),
        Row(id: "rescan", title: "Rescan folders", keys: rescan, detail: "Refresh project list"),
        Row(id: "morning", title: "Morning routine", keys: morning, detail: "Start your marked workspace"),
        Row(id: "stop", title: "Stop all running", keys: stopAll, detail: "Stop every live stack"),
    ]
}

/// Command / device tile: icon + label + optional keyboard shortcut capsule.
struct CommandTile: View {
    let title: String
    var systemImage: String
    var shortcut: String? = nil
    var emphasized: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(emphasized ? DevDockTheme.ink : DevDockTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        (emphasized ? DevDockTheme.accent : DevDockTheme.accent.opacity(0.14))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(DevDockTheme.chalk)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let shortcut {
                    ShortcutKeyCap(shortcut)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(DevDockTheme.panelElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DevDockTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct IconGhostButtonStyle: ButtonStyle {
    var systemImage: String

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            configuration.label
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DevDockTheme.chalk)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(DevDockTheme.panelElevated.opacity(configuration.isPressed ? 0.7 : 1))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DevDockTheme.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
