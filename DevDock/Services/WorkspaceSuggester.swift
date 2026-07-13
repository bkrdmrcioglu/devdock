import Foundation

struct WorkspaceSuggestion: Identifiable, Hashable {
    let id: UUID
    let name: String
    let projectIDs: [UUID]
    let memberNames: [String]
    let parentPath: String

    init(name: String, projectIDs: [UUID], memberNames: [String], parentPath: String) {
        self.id = UUID()
        self.name = name
        self.projectIDs = projectIDs
        self.memberNames = memberNames
        self.parentPath = parentPath
    }
}

enum WorkspaceSuggester {
    private static let roleHints: [String] = [
        "backend", "frontend", "web", "mobile", "api", "admin",
        "server", "client", "app", "site", "worker", "cms",
    ]

    /// Suggest workspaces from sibling projects under the same parent folder.
    static func suggest(from projects: [DevProject], existing: [WorkspaceProfile]) -> [WorkspaceSuggestion] {
        let existingSets = Set(existing.map { Set($0.projectIDs) })
        var byParent: [String: [DevProject]] = [:]

        for project in projects {
            let parent = (project.path as NSString).deletingLastPathComponent
            byParent[parent, default: []].append(project)
        }

        var suggestions: [WorkspaceSuggestion] = []

        for (parent, members) in byParent {
            guard members.count >= 2 else { continue }

            let ids = members.map(\.id)
            let idSet = Set(ids)
            if existingSets.contains(idSet) { continue }
            // Also skip if an existing workspace already covers the same parent set loosely
            if existing.contains(where: { Set($0.projectIDs) == idSet }) { continue }

            let folderNames = members.map { URL(fileURLWithPath: $0.path).lastPathComponent.lowercased() }
            let roleHits = folderNames.filter { name in
                roleHints.contains(where: { name == $0 || name.contains($0) })
            }
            // Need at least 2 role-like siblings OR 2+ projects with different ports/frameworks
            let distinctFrameworks = Set(members.map(\.framework))
            let looksLikeStack = roleHits.count >= 2 || (members.count >= 2 && distinctFrameworks.count >= 2)
            guard looksLikeStack else { continue }

            let parentName = URL(fileURLWithPath: parent).lastPathComponent
            let suggestionName = "\(parentName) Stack"
            let memberNames = members
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map(\.name)

            suggestions.append(
                WorkspaceSuggestion(
                    name: suggestionName,
                    projectIDs: ids,
                    memberNames: memberNames,
                    parentPath: parent
                )
            )
        }

        return suggestions.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
