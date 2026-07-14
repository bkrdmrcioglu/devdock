import SwiftUI

/// Suite chrome trail — hint · Upgrade/Pro · sparkles · settings (32×32).
/// Keep this identical across DevCheck / DevMail / DevSQL / DevDock.
struct SuiteChromeTrail: View {
    var hint: String? = nil
    var isPro: Bool
    var showsWhatsNewBadge: Bool
    var showSettingsButton: Bool = true
    let accent: Color
    let warn: Color
    let mist: Color
    let ink: Color
    let elevated: Color
    var onUpgrade: () -> Void
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

            if isPro {
                Text("Pro")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.14))
                    .clipShape(Capsule())
            } else {
                Button(action: onUpgrade) {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Upgrade")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(warn)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(warn.opacity(0.14))
                    .overlay(Capsule().stroke(warn.opacity(0.35), lineWidth: 1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .layoutPriority(2)
                .help("Unlock Pro in Settings")
            }

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
                .help("Settings & license")
            }
        }
    }
}
