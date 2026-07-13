import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DevDockStore
    @EnvironmentObject private var processes: ProcessManager
    @State private var showWorkspaceSheet = false
    @State private var showSettings = false
    @State private var showWhatsNew = false
    /// Bumped when What’s New is dismissed so the NEW badge refreshes.
    @State private var whatsNewEpoch = 0

    var body: some View {
        ZStack {
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
            } detail: {
                if let project = store.selectedProject {
                    ProjectDetailView(project: project)
                } else {
                    emptyDetail
                }
            }
            .background(DevDockTheme.ink)
            .onAppear {
                store.bootstrapIfNeeded()
                if WhatsNew.shouldPresent {
                    showWhatsNew = true
                }
            }
            .sheet(isPresented: $showWorkspaceSheet) {
                WorkspaceEditorView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(store.licenseManager)
            }
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView(onDismiss: { whatsNewEpoch += 1 })
            }

            LogsDrawerOverlay()
                .environmentObject(store)
                .environmentObject(processes)

            CommandPaletteOverlay()
                .environmentObject(store)
                .environmentObject(processes)
        }
        .onChange(of: store.showWorkspaceEditorFromPalette) { _, open in
            if open {
                showWorkspaceSheet = true
                store.showWorkspaceEditorFromPalette = false
            }
        }
        .onChange(of: store.showWhatsNewFromPalette) { _, open in
            if open {
                showWhatsNew = true
                store.showWhatsNewFromPalette = false
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            header
            searchBar
            if let update = store.availableUpdate {
                updateBanner(update)
            }
            if !store.isPro && store.lockedProjectCount > 0 {
                upgradeBanner
            }
            if !store.settings.workspaces.isEmpty {
                workspaceStrip
            }
            if !store.recentProjects.isEmpty {
                recentStrip
            }
            projectList
            footer
        }
        .background(DevDockTheme.panel)
    }

    private var showsWhatsNewBadge: Bool {
        _ = whatsNewEpoch
        return WhatsNew.shouldPresent
    }

    private var upgradeBanner: some View {
        HStack(spacing: 8) {
            Text("+\(store.lockedProjectCount) locked · Pro unlocks all")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DevDockTheme.warn)
            Spacer()
            Button("Upgrade") { showSettings = true }
                .buttonStyle(GhostButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func updateBanner(_ update: UpdateChecker.ReleaseInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(DevDockTheme.accent)
                Text("DevDock \(update.version) available")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DevDockTheme.chalk)
                Spacer(minLength: 4)
                Button {
                    store.dismissAvailableUpdate()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DevDockTheme.mist)
                }
                .buttonStyle(.plain)
                .help("Later")
                .disabled(store.isHomebrewUpdating)
            }
            if store.isHomebrewUpdating || !store.updateCheckMessage.isEmpty {
                Text(store.isHomebrewUpdating ? "Updating via Homebrew…" : store.updateCheckMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(DevDockTheme.mist)
                    .lineLimit(2)
            }
            HStack(spacing: 8) {
                Button {
                    store.installUpdateViaHomebrew()
                } label: {
                    Text(store.isHomebrewUpdating ? "Updating…" : "Update")
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(store.isHomebrewUpdating)
                .help("Homebrew upgrade, then relaunch")
                Button("Zip") { store.openUpdateDownload() }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(store.isHomebrewUpdating)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DevDockTheme.accent.opacity(0.1))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DevDock")
                        .font(DevDockTheme.brandFont)
                        .foregroundStyle(DevDockTheme.chalk)
                    Text("All your local stacks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DevDockTheme.mist)
                }
                Spacer(minLength: 8)

                Button {
                    showWhatsNew = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text("What’s new")
                            .font(.system(size: 11, weight: .semibold))
                        if showsWhatsNewBadge {
                            Text("NEW")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DevDockTheme.ink)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(DevDockTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                    }
                    .foregroundStyle(showsWhatsNewBadge ? DevDockTheme.accent : DevDockTheme.mist)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        (showsWhatsNewBadge ? DevDockTheme.accent : DevDockTheme.mist).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Release notes & keyboard shortcuts")
            }

            HStack(spacing: 8) {
                Button {
                    store.showCommandPalette = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Commands")
                            .font(.system(size: 11, weight: .semibold))
                        ShortcutKeyCap(AppShortcuts.palette)
                    }
                    .foregroundStyle(DevDockTheme.chalk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(DevDockTheme.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Command palette \(AppShortcuts.palette)")

                Button {
                    store.rescan()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: store.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(store.isScanning ? 0.5 : 1)
                        Text("Rescan")
                            .font(.system(size: 11, weight: .semibold))
                        ShortcutKeyCap(AppShortcuts.rescan)
                    }
                    .foregroundStyle(DevDockTheme.chalk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(DevDockTheme.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Rescan project folders \(AppShortcuts.rescan)")

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DevDockTheme.mist)
                TextField("Search projects · \(AppShortcuts.palette) for commands", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(DevDockTheme.chalk)
            }
            .padding(10)
            .background(DevDockTheme.panelElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SidebarFilter.allCases) { filter in
                        let selected = store.sidebarFilter == filter
                        Button {
                            store.sidebarFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selected ? DevDockTheme.accent.opacity(0.22) : DevDockTheme.panelElevated)
                                .foregroundStyle(selected ? DevDockTheme.accent : DevDockTheme.mist)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selected ? DevDockTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                    }

                    if store.runningCount > 0 {
                        Text("\(store.runningCount) up")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(DevDockTheme.accent)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.leading, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var workspaceStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Workspaces")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DevDockTheme.mist)
                Spacer()
                if store.isLaunchingWorkspace {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let morning = store.morningRoutine {
                        Button {
                            store.startMorningRoutine()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 10))
                                Text("Morning")
                                    .font(.system(size: 11, weight: .semibold))
                                ShortcutKeyCap(AppShortcuts.morning)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DevDockTheme.warn.opacity(0.22))
                            .clipShape(Capsule())
                            .foregroundStyle(DevDockTheme.chalk)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isLaunchingWorkspace)
                        .help("Start morning routine · \(morning.name) · \(AppShortcuts.morning)")
                    }

                    ForEach(store.settings.workspaces) { workspace in
                        let alive = store.workspaceAliveCount(workspace)
                        Button {
                            store.startWorkspace(workspace)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: workspace.isMorningRoutine ? "sun.max.fill" : "square.stack.3d.up.fill")
                                    .font(.system(size: 10))
                                Text(workspace.name)
                                    .font(.system(size: 11, weight: .semibold))
                                if alive > 0 {
                                    Text("\(alive)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(DevDockTheme.accent)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DevDockTheme.panelElevated)
                            .clipShape(Capsule())
                            .foregroundStyle(DevDockTheme.chalk)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isLaunchingWorkspace)
                        .help("Start \(workspace.name)")
                        .contextMenu {
                            Button("Start all") { store.startWorkspace(workspace) }
                            Button("Stop all") { store.stopWorkspace(workspace) }
                            Button("Manage…") { showWorkspaceSheet = true }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            if !store.workspaceActivityMessage.isEmpty {
                Text(store.workspaceActivityMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(DevDockTheme.mist)
                    .padding(.horizontal, 16)
                    .lineLimit(1)
            }
        }
        .padding(.bottom, 8)
    }

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DevDockTheme.mist)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.recentProjects) { project in
                        Button {
                            store.selectedProjectID = project.id
                        } label: {
                            Text(project.name)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DevDockTheme.panelElevated)
                                .clipShape(Capsule())
                                .foregroundStyle(DevDockTheme.chalk)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
    }

    private var projectList: some View {
        Group {
            if store.isScanning && store.projects.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(store.lastScanMessage.isEmpty ? "Scanning…" : store.lastScanMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.mist)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.filteredProjects.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.lastScanMessage.isEmpty ? "No projects found" : store.lastScanMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Add Folder…") {
                        store.addScanFoldersViaPicker()
                    }
                    .buttonStyle(AccentButtonStyle())
                    Button("Open Settings") {
                        showSettings = true
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List(selection: $store.selectedProjectID) {
                    ForEach(store.filteredProjectGroups) { group in
                        Section {
                            ForEach(group.projects) { project in
                                ProjectRowView(project: project)
                                    .tag(project.id)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: group.systemImage)
                                    .font(.system(size: 10, weight: .bold))
                                Text(group.title)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                Text("\(group.projects.count)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(DevDockTheme.mist)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(DevDockTheme.mist)
                            .textCase(nil)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(DevDockTheme.panel)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                if store.canUseWorkspaces {
                    showWorkspaceSheet = true
                } else {
                    showSettings = true
                }
            } label: {
                Label(store.canUseWorkspaces ? "Workspaces" : "Workspaces (Pro)", systemImage: "square.stack.3d.up")
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(store.filteredProjects.count)/\(store.accessibleProjects.count)")
                .font(.system(size: 11))
                .foregroundStyle(DevDockTheme.mist)
            if !store.isPro {
                Text("Free")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DevDockTheme.warn)
            }

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(DevDockTheme.mist)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(DevDockTheme.line).frame(height: 1)
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 40))
                .foregroundStyle(DevDockTheme.mist)
            Text(store.projects.isEmpty ? "No projects yet" : "Select a project")
                .font(DevDockTheme.titleFont)
                .foregroundStyle(DevDockTheme.chalk)
            Text(store.lastScanMessage.isEmpty
                 ? "Add a projects folder (Browse…), then scan."
                 : store.lastScanMessage)
                .foregroundStyle(DevDockTheme.mist)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 10) {
                Button("Add Folder…") { store.addScanFoldersViaPicker() }
                    .buttonStyle(AccentButtonStyle())
                Button("Scan Now") { store.rescan() }
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("Shortcuts")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DevDockTheme.mist)
                ForEach(AppShortcuts.rows) { row in
                    HStack {
                        Text(row.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DevDockTheme.chalk)
                        Spacer()
                        ShortcutKeyCap(row.keys)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: 320)
            .background(DevDockTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 8)

            Button {
                showWhatsNew = true
            } label: {
                Label("What’s new in \(AppInfo.shortVersion)", systemImage: "sparkles")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DevDockTheme.ink)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DevDockTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DevDockTheme.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: DevDockTheme.accent.opacity(configuration.isPressed ? 0 : 0.25), radius: 8, y: 2)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
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
