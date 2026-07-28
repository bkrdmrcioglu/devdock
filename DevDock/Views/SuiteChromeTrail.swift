import SwiftUI

/// Suite chrome trail — hint · support · sparkles · settings (32×32).
struct SuiteChromeTrail: View {
    var hint: String? = nil
    var showsWhatsNewBadge: Bool
    var showSettingsButton: Bool = true
    let accent: Color
    let warn: Color
    let mist: Color
    let ink: Color
    let elevated: Color
    var onSupport: () -> Void
    var onWhatsNew: () -> Void
    var onSettings: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            if let hint, !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(mist.opacity(0.85))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ink.opacity(0.35))
                    .clipShape(Capsule())
            }

            Button(action: onSupport) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(mist)
                    .frame(width: 32, height: 32)
                    .background(elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Support DevDock — Buy Me a Coffee")

            Button(action: onWhatsNew) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(showsWhatsNewBadge ? accent : mist)
                        .frame(width: 32, height: 32)
                        .background(showsWhatsNewBadge ? accent.opacity(0.16) : elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if showsWhatsNewBadge {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("What’s New")

            if showSettingsButton {
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(mist)
                        .frame(width: 32, height: 32)
                        .background(elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("Settings")
            }
        }
    }
}
