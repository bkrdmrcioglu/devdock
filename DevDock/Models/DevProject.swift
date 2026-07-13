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
    case running = "Running"
    case favorites = "★"

    var id: String { rawValue }
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

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        framework: Framework,
        port: Int? = nil,
        isFavorite: Bool = false,
        lastOpenedAt: Date? = nil,
        customStartCommand: [String]? = nil,
        detectedStartCommand: [String]? = nil
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

    enum CodingKeys: String, CodingKey {
        case id, name, projectIDs, openBrowsers, staggerMilliseconds
    }

    init(
        id: UUID = UUID(),
        name: String,
        projectIDs: [UUID] = [],
        openBrowsers: Bool = false,
        staggerMilliseconds: Int = 600
    ) {
        self.id = id
        self.name = name
        self.projectIDs = projectIDs
        self.openBrowsers = openBrowsers
        self.staggerMilliseconds = staggerMilliseconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        projectIDs = try c.decode([UUID].self, forKey: .projectIDs)
        openBrowsers = try c.decodeIfPresent(Bool.self, forKey: .openBrowsers) ?? false
        staggerMilliseconds = try c.decodeIfPresent(Int.self, forKey: .staggerMilliseconds) ?? 600
    }
}

struct AppSettings: Codable {
    var scanRoots: [String]
    var hasCompletedOnboarding: Bool
    var favorites: [UUID]
    var workspaces: [WorkspaceProfile]
    var knownProjects: [DevProject]

    static let defaultScanRoots: [String] = ScanRootLocator.defaultSelection()

    static var `default`: AppSettings {
        AppSettings(
            scanRoots: defaultScanRoots,
            hasCompletedOnboarding: false,
            favorites: [],
            workspaces: [],
            knownProjects: []
        )
    }
}
