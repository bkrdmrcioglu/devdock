import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DevDockStore
    @EnvironmentObject private var processes: ProcessManager
    @State private var showWorkspaceSheet = false
    @State private var showSettings = false

    var body: some View {
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
        .sheet(item: Binding(
            get: { store.showLogsFor.flatMap { id in store.projects.first { $0.id == id } } },
            set: { store.showLogsFor = $0?.id }
        )) { project in
            LogsView(project: project)
                .environmentObject(processes)
                .frame(minWidth: 640, minHeight: 420)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            header
            searchBar
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DevDock")
                    .font(DevDockTheme.brandFont)
                    .foregroundStyle(DevDockTheme.chalk)
                Text("All your local stacks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DevDockTheme.mist)
            }
            Spacer()
            Button {
                store.rescan()
            } label: {
                Image(systemName: store.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .opacity(store.isScanning ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DevDockTheme.mist)
            .help("Rescan project folders")
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DevDockTheme.mist)
                TextField("Search projects", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(DevDockTheme.chalk)
            }
            .padding(10)
            .background(DevDockTheme.panelElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 6) {
                ForEach(SidebarFilter.allCases) { filter in
                    let selected = store.sidebarFilter == filter
                    Button {
                        store.sidebarFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 11, weight: .semibold))
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
                }
                Spacer()
                if store.runningCount > 0 {
                    Text("\(store.runningCount) up")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DevDockTheme.accent)
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
                    ForEach(store.settings.workspaces) { workspace in
                        let alive = store.workspaceAliveCount(workspace)
                        Button {
                            store.startWorkspace(workspace)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.stack.3d.up.fill")
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
                    ForEach(store.filteredProjects) { project in
                        ProjectRowView(project: project)
                            .tag(project.id)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
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
        VStack(spacing: 12) {
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
            .padding(.top, 8)
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
