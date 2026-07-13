import Foundation

struct WorkspaceSuggestion: Identifiable, Hashable {
    let id: UUID
    let name: String
    let projectIDs: [UUID]
    let memberNames: [String]
    let parentPath: String
    /// e.g. "API + Web + Mobile"
    let roleSummary: String

    init(
        name: String,
        projectIDs: [UUID],
        memberNames: [String],
        parentPath: String,
        roleSummary: String
    ) {
        self.id = UUID()
        self.name = name
        self.projectIDs = projectIDs
        self.memberNames = memberNames
        self.parentPath = parentPath
        self.roleSummary = roleSummary
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
            if existing.contains(where: { Set($0.projectIDs) == idSet }) { continue }

            let folderNames = members.map { URL(fileURLWithPath: $0.path).lastPathComponent.lowercased() }
            let roleHits = folderNames.filter { name in
                roleHints.contains(where: { name == $0 || name.contains($0) })
            }

            let stackRoles = Set(members.map(\.framework.stackRole).filter { $0 != .other })
            let distinctFrameworks = Set(members.map(\.framework))

            // Prefer complementary stacks: web+api, mobile+api, web+mobile, or all three
            let complementary = stackRoles.contains(.api) && (stackRoles.contains(.web) || stackRoles.contains(.mobile))
                || (stackRoles.contains(.web) && stackRoles.contains(.mobile))

            let looksLikeStack = complementary
                || roleHits.count >= 2
                || (members.count >= 2 && distinctFrameworks.count >= 2)

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
                    parentPath: parent,
                    roleSummary: roleSummary(for: members)
                )
            )
        }

        return suggestions.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func roleSummary(for members: [DevProject]) -> String {
        var labels: [String] = []
        let roles = Set(members.map(\.framework.stackRole))
            if roles.contains(.api) { labels.append("API") }
            if roles.contains(.web) { labels.append("Web") }
            if roles.contains(.mobile) { labels.append("Mobile") }
            if roles.contains(.desktop) { labels.append("Desktop") }
        if labels.isEmpty {
            let frameworks = Array(Set(members.map(\.framework.rawValue))).sorted()
            return frameworks.prefix(3).joined(separator: " · ")
        }
        return labels.joined(separator: " + ")
    }
}
