import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: DevDockStore
    @EnvironmentObject private var license: LicenseManager
    @Environment(\.dismiss) private var dismiss
    @State private var roots: [String] = []
    @State private var showAbout = false

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

                licenseCard

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

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppInfo.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text("Version \(AppInfo.versionLabel)")
                            .font(.system(size: 11))
                            .foregroundStyle(DevDockTheme.mist)
                    }
                    Spacer()
                    Button("About") { showAbout = true }
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(24)
        }
        .frame(width: 560, height: 620)
        .background(DevDockTheme.ink)
        .foregroundStyle(DevDockTheme.chalk)
        .onAppear { roots = store.settings.scanRoots }
        .sheet(isPresented: $showAbout) { AboutView() }
    }

    private var licenseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(license.isPro ? "DevDock Pro" : "Free plan")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text(license.isPro ? "ACTIVE" : "LIMITED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(license.isPro ? DevDockTheme.accent : DevDockTheme.warn)
            }

            Text(license.isPro
                 ? "Unlimited projects + workspaces unlocked."
                 : "Free includes \(LicenseLimits.freeProjectCap) projects. Workspaces need Pro.")
                .font(.system(size: 12))
                .foregroundStyle(DevDockTheme.mist)

            if !license.statusMessage.isEmpty {
                Text(license.statusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DevDockTheme.chalk.opacity(0.85))
            }

            if license.isPro {
                if !license.licenseKeyMasked.isEmpty {
                    Text("Key \(license.licenseKeyMasked)")
                        .font(DevDockTheme.mono)
                        .foregroundStyle(DevDockTheme.mist)
                }
                if !license.customerEmail.isEmpty {
                    Text(license.customerEmail)
                        .font(.system(size: 11))
                        .foregroundStyle(DevDockTheme.mist)
                }
                HStack {
                    Button("Deactivate") {
                        Task { await license.deactivate() }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(license.isBusy)
                    Button("Buy another seat") {
                        NSWorkspace.shared.open(LicenseLimits.buyURL)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            } else {
                TextField("Lemon Squeezy license key", text: $license.draftKey)
                    .textFieldStyle(.plain)
                    .font(DevDockTheme.mono)
                    .padding(10)
                    .background(DevDockTheme.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack {
                    Button(license.isBusy ? "Working…" : "Activate Pro") {
                        Task { await license.activate() }
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(license.isBusy || license.draftKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Buy Pro — $29") {
                        NSWorkspace.shared.open(LicenseLimits.buyURL)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
        }
        .padding(14)
        .background(DevDockTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(license.isPro ? DevDockTheme.accent.opacity(0.4) : DevDockTheme.line, lineWidth: 1)
        )
    }
}
