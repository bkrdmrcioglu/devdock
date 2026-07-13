import Foundation

struct DependencyIssue: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let fixTitle: String
    let command: [String]

    static func detect(at path: String, framework: Framework) -> [DependencyIssue] {
        var issues: [DependencyIssue] = []
        let fm = FileManager.default

        if framework.isNodeFamily || framework == .electron {
            let pkg = (path as NSString).appendingPathComponent("package.json")
            let modules = (path as NSString).appendingPathComponent("node_modules")
            if fm.fileExists(atPath: pkg), !fm.fileExists(atPath: modules) {
                let pm = packageManager(at: path)
                issues.append(DependencyIssue(
                    id: "node_modules",
                    title: "Missing node_modules",
                    detail: "Run \(pm) install before Start.",
                    fixTitle: "\(pm) install",
                    command: [pm, "install"]
                ))
            }
        }

        if framework == .flutter {
            let pubspec = (path as NSString).appendingPathComponent("pubspec.yaml")
            let dartTool = (path as NSString).appendingPathComponent(".dart_tool")
            if fm.fileExists(atPath: pubspec), !fm.fileExists(atPath: dartTool) {
                issues.append(DependencyIssue(
                    id: "flutter_pub",
                    title: "Flutter packages not fetched",
                    detail: "Run flutter pub get before Start.",
                    fixTitle: "flutter pub get",
                    command: ["flutter", "pub", "get"]
                ))
            }
        }

        if framework == .django || framework == .flask || framework == .fastapi {
            let req = (path as NSString).appendingPathComponent("requirements.txt")
            let venvs = [
                (path as NSString).appendingPathComponent(".venv"),
                (path as NSString).appendingPathComponent("venv"),
            ]
            if fm.fileExists(atPath: req), !venvs.contains(where: { fm.fileExists(atPath: $0) }) {
                issues.append(DependencyIssue(
                    id: "python_venv",
                    title: "No Python venv",
                    detail: "Create .venv then pip install -r requirements.txt.",
                    fixTitle: "python3 -m venv .venv",
                    command: ["python3", "-m", "venv", ".venv"]
                ))
            }
        }

        if framework == .laravel || framework == .symfony {
            let composer = (path as NSString).appendingPathComponent("composer.json")
            let vendor = (path as NSString).appendingPathComponent("vendor")
            if fm.fileExists(atPath: composer), !fm.fileExists(atPath: vendor) {
                issues.append(DependencyIssue(
                    id: "composer_vendor",
                    title: "Missing vendor/",
                    detail: "Run composer install before Start.",
                    fixTitle: "composer install",
                    command: ["composer", "install"]
                ))
            }
        }

        if framework == .rails {
            let gemfile = (path as NSString).appendingPathComponent("Gemfile")
            let vendorBundle = (path as NSString).appendingPathComponent("vendor/bundle")
            let gems = (path as NSString).appendingPathComponent(".bundle")
            if fm.fileExists(atPath: gemfile),
               !fm.fileExists(atPath: vendorBundle),
               !fm.fileExists(atPath: gems) {
                issues.append(DependencyIssue(
                    id: "bundle",
                    title: "Gems not installed",
                    detail: "Run bundle install before Start.",
                    fixTitle: "bundle install",
                    command: ["bundle", "install"]
                ))
            }
        }

        return issues
    }

    private static func packageManager(at path: String) -> String {
        let fm = FileManager.default
        if fm.fileExists(atPath: (path as NSString).appendingPathComponent("pnpm-lock.yaml")) { return "pnpm" }
        if fm.fileExists(atPath: (path as NSString).appendingPathComponent("yarn.lock")) { return "yarn" }
        if fm.fileExists(atPath: (path as NSString).appendingPathComponent("bun.lockb")) { return "bun" }
        return "npm"
    }
}
