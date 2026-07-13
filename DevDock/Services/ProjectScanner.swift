import Foundation

struct ProjectScanner {
    private let maxDepth = 4
    private let skipNames: Set<String> = [
        "node_modules", ".git", "vendor", "Pods", "DerivedData",
        ".build", "dist", "build", ".next", "target", "venv", ".venv",
        "Carthage", "Coverage", "__pycache__", ".turbo", ".cache",
        ".yarn", ".pnpm-store", "coverage",
    ]

    /// Child folder names that usually hold real apps inside a monorepo.
    private let monorepoChildHints: Set<String> = [
        "apps", "packages", "services", "backend", "frontend", "web", "mobile",
        "api", "admin", "server", "client", "app", "site", "docs",
    ]

    func scan(roots: [String], existing: [DevProject] = []) -> [DevProject] {
        let existingByPath = Dictionary(uniqueKeysWithValues: existing.map { ($0.path, $0) })
        var found: [DevProject] = []
        var seen = Set<String>()

        for root in roots {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            scanDirectory(
                root,
                scanRoot: root,
                depth: 0,
                existingByPath: existingByPath,
                found: &found,
                seen: &seen
            )
        }

        return found.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func scanDirectory(
        _ path: String,
        scanRoot: String,
        depth: Int,
        existingByPath: [String: DevProject],
        found: inout [DevProject],
        seen: inout Set<String>
    ) {
        guard depth <= maxDepth else { return }
        guard !seen.contains(path) else { return }
        seen.insert(path)

        let projectRoot = isProjectRoot(path)
        let monorepo = projectRoot && isMonorepoRoot(path)

        if projectRoot {
            // Pure package roots always register. Monorepo roots only if they have a real start script.
            if !monorepo || shouldIncludeMonorepoRoot(path) {
                appendProject(
                    at: path,
                    scanRoot: scanRoot,
                    existingByPath: existingByPath,
                    found: &found
                )
            }
            // Non-monorepo leaf: stop descending (avoid node tooling noise)
            if !monorepo {
                return
            }
        }

        guard depth < maxDepth else { return }

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else { return }
        for name in contents {
            if name.hasPrefix(".") && name != ".env" { continue }
            if skipNames.contains(name) { continue }
            let child = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: child, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            // Inside monorepo, prefer known app folders first but still scan all non-skipped dirs
            scanDirectory(
                child,
                scanRoot: scanRoot,
                depth: depth + 1,
                existingByPath: existingByPath,
                found: &found,
                seen: &seen
            )
        }
    }

    private func appendProject(
        at path: String,
        scanRoot: String,
        existingByPath: [String: DevProject],
        found: inout [DevProject]
    ) {
        let framework = FrameworkDetector.detect(at: path)
        let port = FrameworkDetector.detectPort(at: path, framework: framework)
        let command = StartCommandResolver.resolve(at: path, framework: framework, port: port)
        let displayName = projectDisplayName(path: path, scanRoot: scanRoot)

        if let existing = existingByPath[path] {
            var updated = existing
            updated.name = displayName
            updated.framework = framework
            updated.port = port
            updated.detectedStartCommand = command
            found.append(updated)
        } else {
            found.append(
                DevProject(
                    name: displayName,
                    path: path,
                    framework: framework,
                    port: port,
                    detectedStartCommand: command
                )
            )
        }
    }

    /// e.g. `studio/web` instead of many duplicate `web` rows.
    private func projectDisplayName(path: String, scanRoot: String) -> String {
        let root = (scanRoot as NSString).standardizingPath
        let full = (path as NSString).standardizingPath
        var relative = full
        if full.hasPrefix(root + "/") {
            relative = String(full.dropFirst(root.count + 1))
        }
        let parts = relative.split(separator: "/").map(String.init)
        if parts.count >= 2 {
            return "\(parts[parts.count - 2])/\(parts[parts.count - 1])"
        }
        return parts.last ?? URL(fileURLWithPath: path).lastPathComponent
    }

    private func isProjectRoot(_ path: String) -> Bool {
        let markers = [
            "package.json", "artisan", "manage.py", "Cargo.toml", "go.mod",
            "Gemfile", "composer.json", "pyproject.toml",
        ]
        return markers.contains {
            FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent($0))
        }
    }

    private func isMonorepoRoot(_ path: String) -> Bool {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        if fm.fileExists(atPath: url.appendingPathComponent("pnpm-workspace.yaml").path) { return true }
        if fm.fileExists(atPath: url.appendingPathComponent("lerna.json").path) { return true }
        if fm.fileExists(atPath: url.appendingPathComponent("nx.json").path) { return true }
        if fm.fileExists(atPath: url.appendingPathComponent("turbo.json").path) { return true }

        if let data = try? Data(contentsOf: url.appendingPathComponent("package.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["workspaces"] != nil {
            return true
        }

        // Heuristic: root package.json + multiple runnable children
        guard fm.fileExists(atPath: url.appendingPathComponent("package.json").path) else {
            return false
        }
        guard let kids = try? fm.contentsOfDirectory(atPath: path) else { return false }
        var childProjects = 0
        for name in kids {
            if skipNames.contains(name) || name.hasPrefix(".") { continue }
            let child = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: child, isDirectory: &isDir), isDir.boolValue else { continue }
            if isProjectRoot(child) {
                childProjects += 1
            } else if monorepoChildHints.contains(name.lowercased()),
                      let grand = try? fm.contentsOfDirectory(atPath: child) {
                // apps/web style
                for g in grand where isProjectRoot((child as NSString).appendingPathComponent(g)) {
                    childProjects += 1
                }
            }
            if childProjects >= 2 { return true }
        }
        return childProjects >= 2
    }

    private func shouldIncludeMonorepoRoot(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path).appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: Any] else {
            return false
        }
        let keys = Set(scripts.keys.map { $0.lowercased() })
        // Workspace-only roots often have only lint/test — skip those
        return keys.contains("dev") || keys.contains("start") || keys.contains("develop") || keys.contains("serve")
    }
}
