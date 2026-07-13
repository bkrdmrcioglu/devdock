import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: DevDockStore
    @State private var selected: Set<String> = []
    @State private var suggestions: [String] = []
    @State private var customPath: String = ""

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

            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("DevDock")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(DevDockTheme.chalk)
                    Text("All your local projects. One click away.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DevDockTheme.mist)
                    Text("Pick the folders that contain your projects. External disks with a Projeler/Projects folder are detected automatically.")
                        .font(.system(size: 13))
                        .foregroundStyle(DevDockTheme.mist.opacity(0.85))
                        .padding(.top, 4)
                }

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
                .frame(maxHeight: 280)

                HStack(spacing: 8) {
                    TextField("Or paste a path (~/… or /Volumes/…)", text: $customPath)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(DevDockTheme.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Button("Add") {
                        addCustomPath()
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button("Browse…") {
                        browse()
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                HStack {
                    Text("\(selected.count) selected")
                        .font(.system(size: 11))
                        .foregroundStyle(DevDockTheme.mist)
                    Spacer()
                    Button("Start Scanning") {
                        store.completeOnboarding(selectedRoots: Array(selected).sorted())
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(selected.isEmpty)
                }

                Spacer(minLength: 12)
            }
            .padding(48)
            .frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            suggestions = ScanRootLocator.existingSuggestions()
            let defaults = ScanRootLocator.defaultSelection()
            selected = Set(defaults.isEmpty ? suggestions : defaults)
        }
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
