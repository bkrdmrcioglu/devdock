import Foundation
import Combine

@MainActor
final class DevDockStore: ObservableObject {
    @Published var settings: AppSettings
    @Published var projects: [DevProject] = []
    @Published var selectedProjectID: UUID?
    @Published var searchText: String = ""
    @Published var sidebarFilter: SidebarFilter = .all
    @Published var isScanning: Bool = false
    @Published var showOnboarding: Bool
    @Published var showLogsFor: UUID?
    @Published var gitCache: [UUID: GitInfo] = [:]
    @Published var lastScanMessage: String = ""
    @Published var scanError: String?
    @Published var workspaceActivityMessage: String = ""
    @Published var isLaunchingWorkspace: Bool = false
    /// Project IDs whose configured port is live AND the listener cwd matches that project.
    @Published private(set) var externallyLiveProjectIDs: Set<UUID> = []
    /// Ports that are busy but could not be attributed to a single project (ambiguous).
    @Published private(set) var ambiguousBusyPorts: Set<Int> = []

    let processManager = ProcessManager()
    let licenseManager = LicenseManager()
    private var resourceTimer: Timer?
    private var portPollTimer: Timer?
    private var didAutoBootstrap = false
    private var isPollingPorts = false

    init() {
        let loaded = Persistence.load()
        self.settings = loaded
        self.projects = loaded.knownProjects
        self.showOnboarding = !loaded.hasCompletedOnboarding
        applyFavorites()
        startResourceTimer()
        startPortPolling()
    }

    /// Managed process status, or `.external` when this project's path owns the live port.
    func status(for project: DevProject) -> ProjectStatus {
        let managed = processManager.status(for: project.id)
        switch managed {
        case .running, .starting, .stopping, .error:
            return managed
        case .offline, .external:
            if externallyLiveProjectIDs.contains(project.id) {
                return .external
            }
            return .offline
        }
    }

    /// True when port is taken but not by this project's process tree / cwd.
    func isPortBusyElsewhere(for project: DevProject) -> Bool {
        guard let port = project.port else { return false }
        if status(for: project).isAlive { return false }
        return ambiguousBusyPorts.contains(port)
            || projects.contains {
                $0.id != project.id
                    && $0.port == port
                    && (processManager.status(for: $0.id) == .running
                        || externallyLiveProjectIDs.contains($0.id))
            }
    }

    var selectedProject: DevProject? {
        projects.first { $0.id == selectedProjectID }
    }

    var isPro: Bool { licenseManager.isPro }

    /// Free plan only exposes a capped project list; Pro sees everything.
    var accessibleProjects: [DevProject] {
        if isPro { return projects }
        let favorites = projects.filter(\.isFavorite)
        let rest = projects.filter { !$0.isFavorite }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Array((favorites + rest).prefix(LicenseLimits.freeProjectCap))
    }

    var lockedProjectCount: Int {
        max(0, projects.count - accessibleProjects.count)
    }

    var canUseWorkspaces: Bool { isPro }

    var filteredProjects: [DevProject] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var base = accessibleProjects

        switch sidebarFilter {
        case .all:
            break
        case .running:
            base = base.filter { status(for: $0).isAlive }
        case .favorites:
            base = base.filter(\.isFavorite)
        }

        let filtered: [DevProject]
        if q.isEmpty {
            filtered = base
        } else {
            filtered = base.filter {
                $0.name.localizedCaseInsensitiveContains(q)
                    || $0.framework.rawValue.localizedCaseInsensitiveContains(q)
                    || $0.path.localizedCaseInsensitiveContains(q)
            }
        }
        return filtered.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            let a = status(for: $0).isAlive
            let b = status(for: $1).isAlive
            if a != b { return a && !b }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var recentProjects: [DevProject] {
        projects
            .filter { $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(6)
            .map { $0 }
    }

    var runningCount: Int {
        projects.filter { status(for: $0).isAlive }.count
    }

    /// Called once when main UI appears — fixes empty/wrong scan roots.
    func bootstrapIfNeeded() {
        guard !didAutoBootstrap else { return }
        didAutoBootstrap = true

        let normalized = Array(Set(settings.scanRoots.map(ScanRootLocator.expandPath))).sorted()
        if normalized.isEmpty {
            settings.scanRoots = ScanRootLocator.defaultSelection()
        } else {
            // Keep configured roots even if a volume is currently unmounted
            settings.scanRoots = normalized
            let online = normalized.filter { FileManager.default.fileExists(atPath: $0) }
            if online.isEmpty {
                let discovered = ScanRootLocator.defaultSelection()
                for path in discovered where !settings.scanRoots.contains(path) {
                    settings.scanRoots.append(path)
                }
                settings.scanRoots.sort()
            }
        }

        if settings.scanRoots.isEmpty {
            lastScanMessage = "No scan folders yet — add one to continue."
            persist()
            return
        }

        persist()
        if projects.isEmpty {
            rescan()
        } else {
            let offline = settings.scanRoots.filter { !FileManager.default.fileExists(atPath: $0) }
            if !offline.isEmpty {
                lastScanMessage = "\(projects.count) cached · \(offline.count) folder(s) offline"
            }
        }
    }

    func completeOnboarding(selectedRoots: [String]) {
        let roots = selectedRoots.map(ScanRootLocator.expandPath)
        let existing = roots.filter { FileManager.default.fileExists(atPath: $0) }
        settings.scanRoots = existing.isEmpty ? ScanRootLocator.defaultSelection() : existing
        settings.hasCompletedOnboarding = true
        showOnboarding = false
        persist()
        rescan()
    }

    func addScanFoldersViaPicker() {
        let picked = ScanRootLocator.pickFolders(existing: settings.scanRoots)
        guard !picked.isEmpty else { return }
        var roots = Set(settings.scanRoots.map(ScanRootLocator.expandPath))
        picked.forEach { roots.insert($0) }
        settings.scanRoots = roots.sorted()
        persist()
        rescan()
    }

    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        scanError = nil
        lastScanMessage = "Scanning…"

        let configured = settings.scanRoots.map(ScanRootLocator.expandPath)
        var roots = configured.filter { FileManager.default.fileExists(atPath: $0) }
        let offlineRoots = configured.filter { !FileManager.default.fileExists(atPath: $0) }

        if roots.isEmpty {
            let discovered = ScanRootLocator.defaultSelection()
            for path in discovered where !settings.scanRoots.contains(path) {
                settings.scanRoots.append(path)
            }
            settings.scanRoots.sort()
            persist()
            roots = settings.scanRoots.filter { FileManager.default.fileExists(atPath: $0) }
        }

        if roots.isEmpty {
            isScanning = false
            lastScanMessage = offlineRoots.isEmpty
                ? "No folders to scan. Add a projects folder."
                : "Scan folders offline (disk unmounted?). Keeping \(projects.count) cached project(s)."
            return
        }

        let existing = projects
        let rootCopy = roots
        let offlineCopy = offlineRoots
        Task(priority: .userInitiated) {
            let found = await Task.detached(priority: .userInitiated) {
                ProjectScanner().scan(roots: rootCopy, existing: existing)
            }.value

            mergeScanResults(found, offlineRoots: offlineCopy)
            isScanning = false
            if found.isEmpty && projects.isEmpty {
                lastScanMessage = "No projects found in \(rootCopy.count) folder(s)."
            } else if !offlineCopy.isEmpty {
                lastScanMessage = "Found \(found.count) · kept offline cache · \(offlineCopy.count) folder(s) missing"
            } else {
                lastScanMessage = "Found \(projects.count) project(s)."
            }
            await refreshGitAsync()
        }
    }

    func toggleFavorite(_ project: DevProject) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].isFavorite.toggle()
        if projects[idx].isFavorite {
            if !settings.favorites.contains(project.id) {
                settings.favorites.append(project.id)
            }
        } else {
            settings.favorites.removeAll { $0 == project.id }
        }
        persist()
    }

    func start(_ project: DevProject) {
        markOpened(project)
        Task {
            await processManager.startAsync(project)
            if processManager.status(for: project.id) == .error {
                showLogsFor = project.id
            }
        }
    }

    func stop(_ project: DevProject) {
        Task {
            // External (Terminal/Docker) processes: free the port; managed: stop our tree
            if status(for: project) == .external, let port = project.port {
                await Task.detached(priority: .utility) {
                    PortManager.killPort(port)
                }.value
                externallyLiveProjectIDs.remove(project.id)
                objectWillChange.send()
            } else {
                await processManager.stopAsync(project)
            }
        }
    }

    func setCustomStartCommand(_ project: DevProject, commandLine: String?) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        if let commandLine,
           let parsed = StartCommandResolver.parseUserCommand(commandLine) {
            projects[idx].customStartCommand = parsed
        } else {
            projects[idx].customStartCommand = nil
        }
        persist()
        objectWillChange.send()
    }

    func startWorkspace(_ workspace: WorkspaceProfile) {
        guard canUseWorkspaces else {
            workspaceActivityMessage = "Workspaces require DevDock Pro"
            return
        }
        let members = workspace.projectIDs.compactMap { id in projects.first(where: { $0.id == id }) }
        guard !members.isEmpty else {
            workspaceActivityMessage = "\(workspace.name): no matching projects (rescan?)"
            return
        }

        Task {
            isLaunchingWorkspace = true
            workspaceActivityMessage = "Starting \(workspace.name)…"
            let delayNs = UInt64(max(0, workspace.staggerMilliseconds)) * 1_000_000
            var started = 0
            var skipped = 0

            for (index, project) in members.enumerated() {
                let current = status(for: project)
                if current == .running || current == .starting {
                    skipped += 1
                    workspaceActivityMessage = "\(workspace.name): \(project.name) already up"
                } else {
                    workspaceActivityMessage = "\(workspace.name): starting \(project.name)…"
                    markOpened(project)
                    await processManager.startAsync(project)
                    if processManager.status(for: project.id) == .error {
                        showLogsFor = project.id
                    } else {
                        started += 1
                        if workspace.openBrowsers, let port = project.port {
                            // Give the server a brief moment before opening
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            ExternalLauncher.openBrowser(port: port)
                        }
                    }
                }
                if index < members.count - 1, delayNs > 0 {
                    try? await Task.sleep(nanoseconds: delayNs)
                }
            }

            isLaunchingWorkspace = false
            workspaceActivityMessage = "\(workspace.name): started \(started)"
                + (skipped > 0 ? ", skipped \(skipped)" : "")
            objectWillChange.send()
        }
    }

    func stopWorkspace(_ workspace: WorkspaceProfile) {
        let members = workspace.projectIDs.compactMap { id in projects.first(where: { $0.id == id }) }
        guard !members.isEmpty else { return }
        Task {
            workspaceActivityMessage = "Stopping \(workspace.name)…"
            for project in members where status(for: project).isAlive {
                if status(for: project) == .external, let port = project.port {
                    await Task.detached(priority: .utility) {
                        PortManager.killPort(port)
                    }.value
                    externallyLiveProjectIDs.remove(project.id)
                } else {
                    await processManager.stopAsync(project)
                }
            }
            workspaceActivityMessage = "\(workspace.name): stopped"
            objectWillChange.send()
        }
    }

    func workspaceMemberNames(_ workspace: WorkspaceProfile) -> [String] {
        workspace.projectIDs.compactMap { id in
            projects.first(where: { $0.id == id })?.name
        }
    }

    func workspaceAliveCount(_ workspace: WorkspaceProfile) -> Int {
        workspace.projectIDs.reduce(0) { count, id in
            guard let project = projects.first(where: { $0.id == id }) else { return count }
            return count + (status(for: project).isAlive ? 1 : 0)
        }
    }

    func addWorkspace(name: String, projectIDs: [UUID], openBrowsers: Bool = false) {
        guard canUseWorkspaces else {
            workspaceActivityMessage = "Workspaces require DevDock Pro"
            return
        }
        settings.workspaces.append(
            WorkspaceProfile(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                projectIDs: projectIDs,
                openBrowsers: openBrowsers
            )
        )
        persist()
    }

    func applyWorkspaceSuggestion(_ suggestion: WorkspaceSuggestion, openBrowsers: Bool = true) {
        guard canUseWorkspaces else {
            workspaceActivityMessage = "Workspaces require DevDock Pro"
            return
        }
        let idSet = Set(suggestion.projectIDs)
        if settings.workspaces.contains(where: { Set($0.projectIDs) == idSet }) {
            workspaceActivityMessage = "\(suggestion.name) already exists"
            return
        }
        addWorkspace(name: suggestion.name, projectIDs: suggestion.projectIDs, openBrowsers: openBrowsers)
        workspaceActivityMessage = "Added workspace \(suggestion.name)"
    }

    var workspaceSuggestions: [WorkspaceSuggestion] {
        WorkspaceSuggester.suggest(from: projects, existing: settings.workspaces)
    }

    func updateWorkspace(_ workspace: WorkspaceProfile) {
        guard let idx = settings.workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        settings.workspaces[idx] = workspace
        persist()
    }

    func deleteWorkspace(_ workspace: WorkspaceProfile) {
        settings.workspaces.removeAll { $0.id == workspace.id }
        persist()
    }

    func killPort(for project: DevProject) {
        guard let port = project.port else { return }
        Task {
            await Task.detached(priority: .utility) {
                PortManager.killPort(port)
            }.value
            objectWillChange.send()
        }
    }

    func refreshGit() {
        Task { await refreshGitAsync() }
    }

    func refreshGitAsync() async {
        let snapshot = await MainActor.run { projects.map { ($0.id, $0.path) } }
        var cache: [UUID: GitInfo] = [:]
        for (id, path) in snapshot {
            let info = await Task.detached(priority: .utility) {
                GitService.info(at: path)
            }.value
            if let info {
                cache[id] = info
            }
        }
        await MainActor.run {
            self.gitCache = cache
        }
    }

    func updateScanRoots(_ roots: [String]) {
        settings.scanRoots = roots.map(ScanRootLocator.expandPath).filter { !$0.isEmpty }
        persist()
    }

    private func mergeScanResults(_ found: [DevProject], offlineRoots: [String] = []) {
        let favoriteSet = Set(settings.favorites)
        var byPath: [String: DevProject] = [:]

        // Preserve projects that live under currently offline roots (e.g. unmounted external disk)
        for project in projects {
            if offlineRoots.contains(where: { project.path.hasPrefix($0) }) {
                byPath[project.path] = project
            }
        }

        for project in found {
            var p = project
            if let old = projects.first(where: { $0.path == p.path }) {
                p.id = old.id
                p.lastOpenedAt = old.lastOpenedAt
                p.customStartCommand = old.customStartCommand
                p.isFavorite = old.isFavorite || favoriteSet.contains(old.id)
            } else {
                p.isFavorite = favoriteSet.contains(p.id)
            }
            byPath[p.path] = p
        }

        let merged = byPath.values.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        projects = merged
        settings.knownProjects = merged
        settings.favorites = merged.filter(\.isFavorite).map(\.id)
        if selectedProjectID == nil || !merged.contains(where: { $0.id == selectedProjectID }) {
            selectedProjectID = merged.first?.id
        }
        persist()
    }

    private func applyFavorites() {
        let fav = Set(settings.favorites)
        for i in projects.indices {
            projects[i].isFavorite = fav.contains(projects[i].id)
        }
    }

    private func markOpened(_ project: DevProject) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].lastOpenedAt = Date()
        settings.knownProjects = projects
        persist()
    }

    private func persist() {
        settings.knownProjects = projects
        Persistence.save(settings)
    }

    private func startResourceTimer() {
        // Lightweight UI tick for managed running indicators only — no shell work here.
        resourceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let anyRunning = self.projects.contains {
                    self.processManager.status(for: $0.id) == .running
                }
                if anyRunning {
                    self.objectWillChange.send()
                }
            }
        }
    }

    private func startPortPolling() {
        // Immediate check, then every 2s so Terminal-started servers show up quickly
        Task { await refreshLivePorts() }
        portPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshLivePorts()
            }
        }
    }

    func refreshLivePorts() async {
        guard !isPollingPorts else { return }
        isPollingPorts = true
        defer { isPollingPorts = false }

        let snapshot: [(id: UUID, path: String, port: Int)] = projects.compactMap { project in
            guard let port = project.port else { return nil }
            return (project.id, project.path, port)
        }
        guard !snapshot.isEmpty else {
            if !externallyLiveProjectIDs.isEmpty { externallyLiveProjectIDs = [] }
            if !ambiguousBusyPorts.isEmpty { ambiguousBusyPorts = [] }
            return
        }

        // Skip ports already owned by a DevDock-managed process
        let managedPorts: Set<Int> = Set(projects.compactMap { project -> Int? in
            guard processManager.status(for: project.id) == .running else { return nil }
            return project.port
        })

        let result = await Task.detached(priority: .utility) { () -> (Set<UUID>, Set<Int>) in
            var liveIDs = Set<UUID>()
            var ambiguous = Set<Int>()

            let ports = Set(snapshot.map(\.port))
            for port in ports {
                if managedPorts.contains(port) { continue }
                guard PortManager.isPortInUse(port) else { continue }

                let candidates = snapshot.filter { $0.port == port }
                let cwds = PortManager.listenerWorkingDirectories(on: port)
                let paths = candidates.map(\.path)

                if let matchedPath = PortManager.bestMatchingProjectPath(cwds: cwds, candidates: paths),
                   let match = candidates.first(where: {
                       ($0.path as NSString).standardizingPath == (matchedPath as NSString).standardizingPath
                   }) {
                    liveIDs.insert(match.id)
                } else {
                    // Port is busy but we can't safely attribute it to one project
                    ambiguous.insert(port)
                }
            }
            return (liveIDs, ambiguous)
        }.value

        if result.0 != externallyLiveProjectIDs || result.1 != ambiguousBusyPorts {
            externallyLiveProjectIDs = result.0
            ambiguousBusyPorts = result.1
            objectWillChange.send()
        }
    }
}
