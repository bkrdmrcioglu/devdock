import Foundation

enum ProjectStatus: String, Codable {
    case offline
    case starting
    case running
    /// Port is live but process was not started by DevDock (e.g. Terminal).
    case external
    case stopping
    case error

    var isAlive: Bool {
        switch self {
        case .running, .external, .starting, .stopping: return true
        case .offline, .error: return false
        }
    }
}

enum SidebarFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case web = "Web"
    case mobile = "Mobile"
    case api = "API"
    case running = "Running"
    case favorites = "★"

    var id: String { rawValue }

    var stackRole: Framework.StackRole? {
        switch self {
        case .web: return .web
        case .mobile: return .mobile
        case .api: return .api
        default: return nil
        }
    }
}

struct ProjectGroup: Identifiable {
    let id: String
    let role: Framework.StackRole
    let projects: [DevProject]

    var title: String { role.title }
    var systemImage: String { role.systemImage }
}

struct CustomCommand: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    /// Shell-style argv, e.g. ["npm", "run", "lint"]
    var argv: [String]

    init(id: UUID = UUID(), title: String, argv: [String]) {
        self.id = id
        self.title = title
        self.argv = argv
    }

    init?(id: UUID = UUID(), title: String, commandLine: String) {
        guard let argv = StartCommandResolver.parseUserCommand(commandLine) else { return nil }
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.argv = argv
        if self.title.isEmpty { self.title = argv.joined(separator: " ") }
    }

    var display: String {
        StartCommandResolver.display(argv)
    }
}

struct DevProject: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var path: String
    var framework: Framework
    var port: Int?
    var isFavorite: Bool
    var lastOpenedAt: Date?
    var customStartCommand: [String]?
    /// Auto-detected from package.json / framework (refreshed on scan).
    var detectedStartCommand: [String]?
    /// User-defined one-shot commands for this project.
    var customCommands: [CustomCommand]

    enum CodingKeys: String, CodingKey {
        case id, name, path, framework, port, isFavorite, lastOpenedAt
        case customStartCommand, detectedStartCommand, customCommands
    }

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        framework: Framework,
        port: Int? = nil,
        isFavorite: Bool = false,
        lastOpenedAt: Date? = nil,
        customStartCommand: [String]? = nil,
        detectedStartCommand: [String]? = nil,
        customCommands: [CustomCommand] = []
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.framework = framework
        self.port = port ?? framework.defaultPort
        self.isFavorite = isFavorite
        self.lastOpenedAt = lastOpenedAt
        self.customStartCommand = customStartCommand
        self.detectedStartCommand = detectedStartCommand ?? StartCommandResolver.resolve(
            at: path,
            framework: framework,
            port: port ?? framework.defaultPort
        )
        self.customCommands = customCommands
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        path = try c.decode(String.self, forKey: .path)
        framework = try c.decode(Framework.self, forKey: .framework)
        port = try c.decodeIfPresent(Int.self, forKey: .port)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastOpenedAt = try c.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        customStartCommand = try c.decodeIfPresent([String].self, forKey: .customStartCommand)
        detectedStartCommand = try c.decodeIfPresent([String].self, forKey: .detectedStartCommand)
        customCommands = try c.decodeIfPresent([CustomCommand].self, forKey: .customCommands) ?? []
    }

    var displayPort: String {
        guard let port else { return "—" }
        return "localhost:\(port)"
    }

    var startCommand: [String] {
        customStartCommand ?? detectedStartCommand ?? framework.startCommand
    }

    var folderName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var usesCustomStartCommand: Bool {
        customStartCommand != nil
    }
}

struct WorkspaceProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var projectIDs: [UUID]
    /// Open each project's localhost URL after start.
    var openBrowsers: Bool
    /// Stagger delay between starts (ms) so ports/boot don't collide as hard.
    var staggerMilliseconds: Int
    /// Mark as the one-tap “morning routine” stack (only one at a time).
    var isMorningRoutine: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, projectIDs, openBrowsers, staggerMilliseconds, isMorningRoutine
    }

    init(
        id: UUID = UUID(),
        name: String,
        projectIDs: [UUID] = [],
        openBrowsers: Bool = false,
        staggerMilliseconds: Int = 600,
        isMorningRoutine: Bool = false
    ) {
        self.id = id
        self.name = name
        self.projectIDs = projectIDs
        self.openBrowsers = openBrowsers
        self.staggerMilliseconds = staggerMilliseconds
        self.isMorningRoutine = isMorningRoutine
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        projectIDs = try c.decode([UUID].self, forKey: .projectIDs)
        openBrowsers = try c.decodeIfPresent(Bool.self, forKey: .openBrowsers) ?? false
        staggerMilliseconds = try c.decodeIfPresent(Int.self, forKey: .staggerMilliseconds) ?? 600
        isMorningRoutine = try c.decodeIfPresent(Bool.self, forKey: .isMorningRoutine) ?? false
    }
}

struct AppSettings: Codable {
    var scanRoots: [String]
    var hasCompletedOnboarding: Bool
    var favorites: [UUID]
    var workspaces: [WorkspaceProfile]
    var knownProjects: [DevProject]
    /// Commands available on every project (all frameworks).
    var globalCustomCommands: [CustomCommand]
    /// Notify when localhost HTTP becomes ready.
    var notifyOnReady: Bool
    /// Start morning routine once when DevDock opens.
    var startMorningOnLaunch: Bool
    /// Auto-stop managed processes after N minutes with no log activity (0 = off).
    var idleAutoStopMinutes: Int

    enum CodingKeys: String, CodingKey {
        case scanRoots, hasCompletedOnboarding, favorites, workspaces, knownProjects, globalCustomCommands
        case notifyOnReady, startMorningOnLaunch, idleAutoStopMinutes
    }

    static let defaultScanRoots: [String] = ScanRootLocator.defaultSelection()

    static var `default`: AppSettings {
        AppSettings(
            scanRoots: defaultScanRoots,
            hasCompletedOnboarding: false,
            favorites: [],
            workspaces: [],
            knownProjects: [],
            globalCustomCommands: [],
            notifyOnReady: true,
            startMorningOnLaunch: false,
            idleAutoStopMinutes: 0
        )
    }

    init(
        scanRoots: [String],
        hasCompletedOnboarding: Bool,
        favorites: [UUID],
        workspaces: [WorkspaceProfile],
        knownProjects: [DevProject],
        globalCustomCommands: [CustomCommand] = [],
        notifyOnReady: Bool = true,
        startMorningOnLaunch: Bool = false,
        idleAutoStopMinutes: Int = 0
    ) {
        self.scanRoots = scanRoots
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.favorites = favorites
        self.workspaces = workspaces
        self.knownProjects = knownProjects
        self.globalCustomCommands = globalCustomCommands
        self.notifyOnReady = notifyOnReady
        self.startMorningOnLaunch = startMorningOnLaunch
        self.idleAutoStopMinutes = idleAutoStopMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scanRoots = try c.decodeIfPresent([String].self, forKey: .scanRoots) ?? Self.defaultScanRoots
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        favorites = try c.decodeIfPresent([UUID].self, forKey: .favorites) ?? []
        workspaces = try c.decodeIfPresent([WorkspaceProfile].self, forKey: .workspaces) ?? []
        knownProjects = try c.decodeIfPresent([DevProject].self, forKey: .knownProjects) ?? []
        globalCustomCommands = try c.decodeIfPresent([CustomCommand].self, forKey: .globalCustomCommands) ?? []
        notifyOnReady = try c.decodeIfPresent(Bool.self, forKey: .notifyOnReady) ?? true
        startMorningOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .startMorningOnLaunch) ?? false
        idleAutoStopMinutes = try c.decodeIfPresent(Int.self, forKey: .idleAutoStopMinutes) ?? 0
    }
}
