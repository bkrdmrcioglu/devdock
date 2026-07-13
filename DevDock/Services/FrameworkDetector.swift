import Foundation

enum FrameworkDetector {
    static func detect(at path: String) -> Framework {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)

        func exists(_ name: String) -> Bool {
            fm.fileExists(atPath: url.appendingPathComponent(name).path)
        }

        if exists("artisan") { return .laravel }
        if exists("manage.py") { return .django }
        if exists("Gemfile"), readText(url.appendingPathComponent("Gemfile")).contains("rails") {
            return .rails
        }
        if exists("Cargo.toml") { return .rust }
        if exists("go.mod") { return .go }
        if exists("next.config.js") || exists("next.config.mjs") || exists("next.config.ts") {
            return .nextjs
        }
        if exists("nest-cli.json")
            || packageDepends(on: "@nestjs/core", at: url)
            || packageDepends(on: "nestjs", at: url) {
            return .nestjs
        }
        if exists("vite.config.js") || exists("vite.config.ts") || exists("vue.config.js") {
            if packageDepends(on: "vue", at: url) { return .vue }
        }
        if packageDepends(on: "express", at: url) { return .express }
        if packageDepends(on: "react", at: url) { return .react }
        if packageDepends(on: "vue", at: url) { return .vue }
        if exists("app.py") || exists("wsgi.py") { return .flask }
        if exists("package.json") { return .react }
        return .unknown
    }

    static func detectPort(at path: String, framework: Framework) -> Int? {
        let url = URL(fileURLWithPath: path)
        let envCandidates = [".env", ".env.local", ".env.development"]
        for name in envCandidates {
            let text = readText(url.appendingPathComponent(name))
            if let port = parsePort(fromEnv: text) { return port }
        }

        let pkg = readText(url.appendingPathComponent("package.json"))
        if let port = parsePort(fromPackageScripts: pkg) { return port }

        return framework.defaultPort
    }

    private static func packageDepends(on name: String, at url: URL) -> Bool {
        let text = readText(url.appendingPathComponent("package.json")).lowercased()
        return text.contains("\"\(name)\"") || text.contains("\"@\(name)/")
    }

    private static func readText(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private static func parsePort(fromEnv text: String) -> Int? {
        let patterns = ["PORT=", "APP_PORT=", "VITE_PORT="]
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for prefix in patterns where trimmed.hasPrefix(prefix) {
                let value = trimmed.dropFirst(prefix.count)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if let port = Int(value) { return port }
            }
        }
        return nil
    }

    private static func parsePort(fromPackageScripts text: String) -> Int? {
        let patterns = [
            #"--port[= ](\d{2,5})"#,
            #"-p[= ](\d{2,5})"#,
            #":(\d{4,5})"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text),
               let port = Int(text[range]) {
                return port
            }
        }
        return nil
    }
}
