import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: DevDockStore
    @Environment(\.dismiss) private var dismiss
    @State private var roots: [String] = []
    @State private var showAbout = false
    @State private var showWhatsNew = false
    @State private var globalTitle = ""
    @State private var globalLine = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(GhostButtonStyle())
                }

                supportCard

                updatesCard

                automationCard

                Text("Scan folders")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DevDockTheme.mist)

                if roots.isEmpty {
                    Text("No folders yet.")
                        .foregroundStyle(DevDockTheme.mist)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(roots, id: \.self) { path in
                            HStack {
                                Text(path)
                                    .font(DevDockTheme.mono)
                                    .lineLimit(2)
                                Spacer()
                                let exists = FileManager.default.fileExists(atPath: path)
                                Text(exists ? "ok" : "missing")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(exists ? DevDockTheme.accent : DevDockTheme.danger)
                                Button {
                                    roots.removeAll { $0 == path }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(DevDockTheme.mist)
                            }
                            .padding(10)
                            .background(DevDockTheme.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                HStack {
                    Button("Add Folder…") {
                        let picked = ScanRootLocator.pickFolders(existing: roots)
                        for path in picked where !roots.contains(path) {
                            roots.append(path)
                        }
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button("Detect Disks") {
                        for path in ScanRootLocator.existingSuggestions() where !roots.contains(path) {
                            roots.append(path)
                        }
                    }
                    .buttonStyle(GhostButtonStyle())

                    Spacer()

                    Button("Save & Scan") {
                        store.updateScanRoots(roots)
                        store.rescan()
                        dismiss()
                    }
                    .buttonStyle(AccentButtonStyle())
                }

                Divider().overlay(DevDockTheme.line)

                Text("Global custom commands")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DevDockTheme.mist)
                Text("Available on every project, any framework.")
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)

                if store.settings.globalCustomCommands.isEmpty {
                    Text("None yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.mist)
                } else {
                    ForEach(store.settings.globalCustomCommands) { cmd in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cmd.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(cmd.display)
                                    .font(DevDockTheme.mono)
                                    .foregroundStyle(DevDockTheme.mist)
                            }
                            Spacer()
                            Button {
                                store.deleteGlobalCommand(cmd.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(DevDockTheme.mist)
                        }
                        .padding(10)
                        .background(DevDockTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                TextField("Title", text: $globalTitle)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(DevDockTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                TextField("Command e.g. npm run build", text: $globalLine)
                    .textFieldStyle(.plain)
                    .font(DevDockTheme.mono)
                    .padding(10)
                    .background(DevDockTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Button("Add global command") {
                    store.addGlobalCommand(title: globalTitle, commandLine: globalLine)
                    globalTitle = ""
                    globalLine = ""
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(globalLine.trimmingCharacters(in: .whitespaces).isEmpty)

                Divider().overlay(DevDockTheme.line)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppInfo.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text("Version \(AppInfo.versionLabel)")
                            .font(.system(size: 11))
                            .foregroundStyle(DevDockTheme.mist)
                    }
                    Spacer()
                    Button("What’s new") { showWhatsNew = true }
                        .buttonStyle(GhostButtonStyle())
                    Button("About") { showAbout = true }
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(24)
        }
        .frame(width: 560, height: 720)
        .background(DevDockTheme.ink)
        .foregroundStyle(DevDockTheme.chalk)
        .onAppear { roots = store.settings.scanRoots }
        .sheet(isPresented: $showAbout) { AboutView() }
        .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DevDock is free & open source")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }

            Text("All projects and workspaces are unlocked for everyone. If DevDock saves you time, consider buying a coffee.")
                .font(.system(size: 12))
                .foregroundStyle(DevDockTheme.mist)

            Button {
                NSWorkspace.shared.open(AppInfo.supportURL)
            } label: {
                Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
            }
            .buttonStyle(AccentButtonStyle())
        }
        .padding(14)
        .background(DevDockTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DevDockTheme.line, lineWidth: 1)
        )
    }

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Updates")
                .font(.system(size: 15, weight: .bold, design: .rounded))

            Text("When a newer release exists, tap Update. DevDock runs brew upgrade, quits, and opens the new app.")
                .font(.system(size: 11))
                .foregroundStyle(DevDockTheme.mist)

            HStack(spacing: 8) {
                Button {
                    store.checkForUpdates(silent: false)
                } label: {
                    if store.isCheckingUpdate {
                        Text("Checking…")
                    } else {
                        Text("Check for updates")
                    }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(store.isCheckingUpdate || store.isHomebrewUpdating)

                if store.availableUpdate != nil {
                    Button {
                        store.installUpdateViaHomebrew()
                    } label: {
                        Text(store.isHomebrewUpdating ? "Updating…" : "Update")
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(store.isHomebrewUpdating)
                    Button("Zip") { store.openUpdateDownload() }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(store.isHomebrewUpdating)
                }
            }

            if !store.updateCheckMessage.isEmpty {
                Text(store.updateCheckMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(store.availableUpdate != nil ? DevDockTheme.accent : DevDockTheme.mist)
            }

            Text("Installed \(AppInfo.versionLabel)")
                .font(.system(size: 11))
                .foregroundStyle(DevDockTheme.mist)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DevDockTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundStyle(DevDockTheme.chalk)
    }

    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Automation")
                .font(.system(size: 15, weight: .bold, design: .rounded))

            Toggle(isOn: Binding(
                get: { store.settings.notifyOnReady },
                set: { store.updateAutomationSettings(notifyOnReady: $0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notify when Ready")
                        .font(.system(size: 13, weight: .semibold))
                    Text("macOS notification when localhost answers HTTP")
                        .font(.system(size: 11))
                        .foregroundStyle(DevDockTheme.mist)
                }
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { store.settings.startMorningOnLaunch },
                set: { store.updateAutomationSettings(startMorningOnLaunch: $0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Morning on launch")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Start your morning routine when DevDock opens")
                        .font(.system(size: 11))
                        .foregroundStyle(DevDockTheme.mist)
                }
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 6) {
                Text("Idle auto-stop")
                    .font(.system(size: 13, weight: .semibold))
                Text("Stop managed stacks after quiet time (0 = off)")
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
                Picker("Minutes", selection: Binding(
                    get: { store.settings.idleAutoStopMinutes },
                    set: { store.updateAutomationSettings(idleAutoStopMinutes: $0) }
                )) {
                    Text("Off").tag(0)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("60 min").tag(60)
                    Text("120 min").tag(120)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DevDockTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundStyle(DevDockTheme.chalk)
    }
}
