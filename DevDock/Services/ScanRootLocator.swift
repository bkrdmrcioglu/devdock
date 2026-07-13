import Foundation
import AppKit

enum ScanRootLocator {
    /// Candidate folders shown during onboarding / settings.
    static func suggestedRoots() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var candidates = [
            "\(home)/Projects",
            "\(home)/Developer",
            "\(home)/Development",
            "\(home)/Code",
            "\(home)/Sites",
            "\(home)/Desktop",
            "\(home)/Documents",
            "\(home)/src",
            "\(home)/work",
            "\(home)/repos",
        ]
        candidates.append(contentsOf: volumeProjectFolders())
        return uniqueExistingPreferring(candidates)
    }

    /// Roots that actually exist on disk.
    static func existingSuggestions() -> [String] {
        suggestedRoots().filter { isDirectory($0) }
    }

    /// Best default selection: prefer external Projeler/Projects folders, else existing suggestions.
    static func defaultSelection() -> [String] {
        let volumes = volumeProjectFolders()
        if !volumes.isEmpty { return volumes }
        let existing = existingSuggestions()
        let withMarkers = existing.filter { hasProjectMarkers(under: $0) }
        if !withMarkers.isEmpty { return withMarkers }
        return existing
    }

    static func expandPath(_ raw: String) -> String {
        var path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("~") {
            path = NSString(string: path).expandingTildeInPath
        }
        return (path as NSString).standardizingPath
    }

    @MainActor
    static func pickFolders(existing: [String] = []) -> [String] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Add Folder"
        panel.message = "Select folders that contain your local projects"
        if let first = existing.first {
            panel.directoryURL = URL(fileURLWithPath: first)
        } else if let kingston = volumeProjectFolders().first {
            panel.directoryURL = URL(fileURLWithPath: kingston)
        }
        guard panel.runModal() == .OK else { return [] }
        return panel.urls.map(\.path).map(expandPath)
    }

    private static func volumeProjectFolders() -> [String] {
        let fm = FileManager.default
        let volumes = "/Volumes"
        guard let names = try? fm.contentsOfDirectory(atPath: volumes) else { return [] }
        var found: [String] = []
        let folderNames = ["Projeler", "Projects", "Developer", "Code", "Development", "Sites", "work"]
        for volume in names {
            if volume.hasPrefix(".") { continue }
            let volumePath = (volumes as NSString).appendingPathComponent(volume)
            for name in folderNames {
                let path = (volumePath as NSString).appendingPathComponent(name)
                if isDirectory(path) {
                    found.append(path)
                }
            }
        }
        return found
    }

    /// Cheap check: look only at immediate children for project markers.
    private static func hasProjectMarkers(under root: String, maxDepth: Int = 2) -> Bool {
        let markers: Set<String> = [
            "package.json", "artisan", "manage.py", "Cargo.toml",
            "go.mod", "Gemfile", "composer.json", "pyproject.toml",
            "pubspec.yaml", "pom.xml", "build.gradle", "build.gradle.kts",
            "settings.gradle", "settings.gradle.kts", "Package.swift",
            "app.py", "requirements.txt", "mix.exs",
        ]
        let skip: Set<String> = [
            "node_modules", ".git", "vendor", ".next", "dist", "build",
            "DerivedData", "Pods", "target", ".build",
        ]

        func hasMarker(at path: String) -> Bool {
            markers.contains {
                FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent($0))
            }
        }

        if hasMarker(at: root) { return true }
        guard maxDepth >= 1,
              let kids = try? FileManager.default.contentsOfDirectory(atPath: root) else { return false }
        for name in kids {
            if name.hasPrefix(".") || skip.contains(name) { continue }
            let child = (root as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: child, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            if hasMarker(at: child) { return true }
            if maxDepth >= 2,
               let grandkids = try? FileManager.default.contentsOfDirectory(atPath: child) {
                for g in grandkids {
                    if g.hasPrefix(".") || skip.contains(g) { continue }
                    let gp = (child as NSString).appendingPathComponent(g)
                    var isDir2: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: gp, isDirectory: &isDir2), isDir2.boolValue else {
                        continue
                    }
                    if hasMarker(at: gp) { return true }
                }
            }
        }
        return false
    }

    private static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func uniqueExistingPreferring(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for path in paths {
            let standardized = expandPath(path)
            guard !seen.contains(standardized) else { continue }
            seen.insert(standardized)
            out.append(standardized)
        }
        return out
    }
}
