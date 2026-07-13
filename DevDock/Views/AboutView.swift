import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showWhatsNew = false

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

            VStack(spacing: 6) {
                Text(AppInfo.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DevDockTheme.chalk)
                Text(AppInfo.tagline)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DevDockTheme.mist)
            }

            VStack(spacing: 4) {
                Text("Version \(AppInfo.versionLabel)")
                    .font(DevDockTheme.mono)
                    .foregroundStyle(DevDockTheme.chalk)
                Text(AppInfo.copyright)
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                aboutRow("Scan & detect", "Find local projects automatically")
                aboutRow("Start / Stop", "Run stacks without opening Terminal")
                aboutRow("Workspaces", "Launch API + web + admin together")
                aboutRow("Menu bar", "Control running projects from anywhere")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DevDockTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                Button("What’s new") { showWhatsNew = true }
                    .buttonStyle(GhostButtonStyle())
                Button("Close") { dismiss() }
                    .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(28)
        .frame(width: 420)
        .background(DevDockTheme.ink)
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView()
        }
    }

    private func aboutRow(_ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(DevDockTheme.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DevDockTheme.chalk)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
            }
        }
    }
}
