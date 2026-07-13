import SwiftUI

/// ~30s first-run: pick scan root → know Rescan → mobile Simulator tip.
struct OnboardingView: View {
    @EnvironmentObject private var store: DevDockStore
    @State private var step = 0
    @State private var selected: Set<String> = []
    @State private var suggestions: [String] = []
    @State private var customPath: String = ""

    private let totalSteps = 3

    var body: some View {
        ZStack {
            DevDockTheme.ink.ignoresSafeArea()
            RadialGradient(
                colors: [DevDockTheme.accent.opacity(0.15), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("DevDock")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(DevDockTheme.chalk)
                    Text(stepTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DevDockTheme.chalk)
                    Text(stepSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(DevDockTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                }

                stepDots

                Group {
                    switch step {
                    case 0: rootsStep
                    case 1: rescanStep
                    default: mobileStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack {
                    if step > 0 {
                        Button("Back") { withAnimation { step -= 1 } }
                            .buttonStyle(GhostButtonStyle())
                    }
                    Spacer()
                    if step < totalSteps - 1 {
                        Button("Continue") { withAnimation { step += 1 } }
                            .buttonStyle(AccentButtonStyle())
                            .disabled(step == 0 && selected.isEmpty)
                    } else {
                        Button("Get started") {
                            WhatsNew.markSeen()
                            store.completeOnboarding(selectedRoots: Array(selected).sorted())
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(selected.isEmpty)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(44)
            .frame(maxWidth: 720)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            suggestions = ScanRootLocator.existingSuggestions()
            let defaults = ScanRootLocator.defaultSelection()
            selected = Set(defaults.isEmpty ? suggestions : defaults)
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "1 · Add a scan root"
        case 1: return "2 · Rescan when folders change"
        default: return "3 · Mobile? Use Simulator"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 0:
            return "Pick the folders that contain your projects (~30 seconds). External disks with Projeler/Projects are detected automatically."
        case 1:
            return "After setup, use the refresh button in the sidebar (or ⌘⇧R) anytime you add a repo. DevDock also rescans on launch."
        default:
            return "For Flutter / Expo / React Native, pick an iOS Simulator or Android Emulator from Quick targets — physical devices stay in Connected devices."
        }
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? DevDockTheme.accent : DevDockTheme.mist.opacity(0.35))
                    .frame(width: i == step ? 22 : 8, height: 6)
            }
            Spacer()
            Text("\(step + 1)/\(totalSteps)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DevDockTheme.mist)
        }
    }

    private var rootsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if suggestions.isEmpty {
                Text("No common project folders found. Use Browse to choose one.")
                    .font(.system(size: 12))
                    .foregroundStyle(DevDockTheme.warn)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { path in
                        Toggle(isOn: Binding(
                            get: { selected.contains(path) },
                            set: { on in
                                if on { selected.insert(path) } else { selected.remove(path) }
                            }
                        )) {
                            Text(path)
                                .font(DevDockTheme.mono)
                                .foregroundStyle(DevDockTheme.chalk)
                                .lineLimit(2)
                        }
                        .toggleStyle(.checkbox)
                        .padding(12)
                        .background(DevDockTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .frame(maxHeight: 240)

            HStack(spacing: 8) {
                TextField("Or paste a path (~/… or /Volumes/…)", text: $customPath)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(DevDockTheme.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Button("Add") { addCustomPath() }
                    .buttonStyle(GhostButtonStyle())
                Button("Browse…") { browse() }
                    .buttonStyle(GhostButtonStyle())
            }

            Text("\(selected.count) selected")
                .font(.system(size: 11))
                .foregroundStyle(DevDockTheme.mist)
        }
    }

    private var rescanStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            tipCard(
                icon: "arrow.clockwise",
                title: "Sidebar Rescan",
                body: "Click the circular arrow next to DevDock when you clone a new project or plug in a disk."
            )
            tipCard(
                icon: "keyboard",
                title: "Keyboard",
                body: "⌘⇧R runs Rescan Folders from anywhere in the app."
            )
            tipCard(
                icon: "shippingbox",
                title: "Then Start",
                body: "Select a project and hit Start — no Terminal window required."
            )
        }
    }

    private var mobileStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            tipCard(
                icon: "iphone",
                title: "Quick targets = simulators",
                body: "iOS Simulator / Android Emulator shortcuts never pick a physical phone by mistake."
            )
            tipCard(
                icon: "cable.connector",
                title: "Connected devices",
                body: "Plugged-in phones and tablets appear under Connected devices — choose one explicitly to run there."
            )
            tipCard(
                icon: "square.stack.3d.up",
                title: "Morning routine (later)",
                body: "Group API + web into a workspace and mark it as your morning stack for one-tap launch."
            )
        }
    }

    private func tipCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DevDockTheme.accent)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DevDockTheme.chalk)
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(DevDockTheme.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DevDockTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func addCustomPath() {
        let path = ScanRootLocator.expandPath(customPath)
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return }
        if !suggestions.contains(path) {
            suggestions.insert(path, at: 0)
        }
        selected.insert(path)
        customPath = ""
    }

    private func browse() {
        let picked = ScanRootLocator.pickFolders(existing: Array(selected))
        for path in picked {
            if !suggestions.contains(path) {
                suggestions.insert(path, at: 0)
            }
            selected.insert(path)
        }
    }
}
