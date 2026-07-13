import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What’s new")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DevDockTheme.chalk)
                    Text("DevDock \(AppInfo.shortVersion) · full changelog")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DevDockTheme.mist)
                }
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(WhatsNew.releases) { release in
                        releaseBlock(release)
                    }

                    shortcutsBlock
                }
            }
            .frame(maxHeight: 420)

            HStack {
                Spacer()
                Button("Got it") {
                    WhatsNew.markSeen()
                    onDismiss?()
                    dismiss()
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(DevDockTheme.ink)
    }

    private func releaseBlock(_ release: WhatsNew.Release) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("v\(release.version)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(DevDockTheme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DevDockTheme.accent)
                    .clipShape(Capsule())
                if release.version == WhatsNew.releases.first?.version {
                    Text("Latest")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DevDockTheme.accent)
                }
                Spacer()
            }

            ForEach(release.items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DevDockTheme.accent)
                        .frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DevDockTheme.chalk)
                        Text(item.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(DevDockTheme.mist)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DevDockTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var shortcutsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard shortcuts")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(DevDockTheme.chalk)

            ForEach(AppShortcuts.rows) { row in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DevDockTheme.chalk)
                        Text(row.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(DevDockTheme.mist)
                    }
                    Spacer(minLength: 8)
                    ShortcutKeyCap(row.keys)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DevDockTheme.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DevDockTheme.accent.opacity(0.35), lineWidth: 1)
        )
    }
}
