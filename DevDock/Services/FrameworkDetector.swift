import Foundation

enum FrameworkDetector {
    static func detect(at path: String) -> Framework {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)

        func exists(_ name: String) -> Bool {
            fm.fileExists(atPath: url.appendingPathComponent(name).path)
        }

        // —— Non-JS backends / mobile first (clear markers) ——
        if exists("artisan") { return .laravel }
        if exists("symfony.lock") {
            return .symfony
        }
        if exists("bin/console"), exists("composer.json") {
            let composer = readText(url.appendingPathComponent("composer.json")).lowercased()
            if composer.contains("symfony/") { return .symfony }
        }
        if exists("manage.py") { return .django }
        if pythonDepends(on: "fastapi", at: url) { return .fastapi }
        if exists("app.py") || exists("wsgi.py") || pythonDepends(on: "flask", at: url) { return .flask }
        if exists("Gemfile"), readText(url.appendingPathComponent("Gemfile")).contains("rails") {
            return .rails
        }
        if exists("mix.exs"), readText(url.appendingPathComponent("mix.exs")).lowercased().contains("phoenix") {
            return .phoenix
        }
        if exists("pubspec.yaml") {
            let pub = readText(url.appendingPathComponent("pubspec.yaml")).lowercased()
            if pub.contains("flutter:") || pub.contains("sdk: flutter") { return .flutter }
        }
        // Android / Kotlin before Spring (both use Gradle).
        if hasAndroidKotlinProject(at: url) { return .kotlin }
        if hasSwiftProject(at: url) { return .swift }
        if hasDotnetProject(at: url) { return .dotnet }
        if hasSpringProject(at: url) { return .spring }
        if exists("Cargo.toml") {
            if exists("src-tauri") { return .tauri }
            return .rust
        }
        if exists("go.mod") { return .go }
        if exists("src-tauri") { return .tauri }

        // —— Mobile JS before web frameworks (Expo apps also depend on react) ——
        if isExpoProject(at: url, exists: exists) { return .expo }
        if packageDepends(on: "react-native", at: url)
            || exists("metro.config.js")
            || exists("metro.config.ts")
            || exists("react-native.config.js") {
            return .reactNative
        }
        if exists("ionic.config.json") || packageDepends(on: "@ionic/angular", at: url)
            || packageDepends(on: "@ionic/react", at: url)
            || packageDepends(on: "@ionic/vue", at: url) {
            return .ionic
        }

        // —— JS / TS meta-frameworks (most specific first) ——
        if exists("next.config.js") || exists("next.config.mjs") || exists("next.config.ts")
            || packageDepends(on: "next", at: url) {
            return .nextjs
        }
        if exists("nuxt.config.js") || exists("nuxt.config.ts") || exists("nuxt.config.mjs")
            || packageDepends(on: "nuxt", at: url) {
            return .nuxt
        }
        if exists("remix.config.js") || exists("remix.config.ts")
            || packageDepends(on: "@remix-run/react", at: url)
            || packageDepends(on: "@remix-run/node", at: url) {
            return .remix
        }
        if exists("astro.config.mjs") || exists("astro.config.js") || exists("astro.config.ts")
            || packageDepends(on: "astro", at: url) {
            return .astro
        }
        if exists("gatsby-config.js") || exists("gatsby-config.ts")
            || packageDepends(on: "gatsby", at: url) {
            return .gatsby
        }
        if exists("angular.json") || packageDepends(on: "@angular/core", at: url) {
            return .angular
        }
        if packageDepends(on: "@sveltejs/kit", at: url)
            || (exists("svelte.config.js") && packageDepends(on: "@sveltejs/kit", at: url)) {
            return .sveltekit
        }
        if exists("svelte.config.js") || packageDepends(on: "svelte", at: url) {
            return .svelte
        }
        if packageDepends(on: "solid-js", at: url) { return .solid }
        if exists("ember-cli-build.js") || packageDepends(on: "ember-source", at: url) {
            return .ember
        }
        if packageDepends(on: "quasar", at: url) || exists("quasar.config.js") || exists("quasar.config.ts") {
            return .quasar
        }

        // Node API
        if exists("nest-cli.json")
            || packageDepends(on: "@nestjs/core", at: url) {
            return .nestjs
        }
        if packageDepends(on: "fastify", at: url) { return .fastify }
        if packageDepends(on: "hono", at: url) { return .hono }
        if packageDepends(on: "koa", at: url) { return .koa }
        if packageDepends(on: "express", at: url) { return .express }

        // Desktop
        if packageDepends(on: "electron", at: url) { return .electron }
        if packageDepends(on: "@tauri-apps/cli", at: url) || packageDepends(on: "@tauri-apps/api", at: url) {
            return .tauri
        }

        // Vite / Vue / React (generic)
        let hasViteConfig = exists("vite.config.js")
            || exists("vite.config.ts")
            || exists("vite.config.mjs")
            || exists("vite.config.mts")
        if hasViteConfig || packageDepends(on: "vite", at: url) {
            return .vite
        }
        if exists("vue.config.js") || packageDepends(on: "vue", at: url) {
            return .vue
        }
        if packageDepends(on: "react", at: url) { return .react }

        if exists("package.json") { return .unknown }
        return .unknown
    }

    private static func isExpoProject(at url: URL, exists: (String) -> Bool) -> Bool {
        if exists("eas.json") { return true }
        if packageDepends(on: "expo", at: url) { return true }
        if packageDepends(on: "expo-router", at: url) { return true }
        if packageDepends(on: "babel-preset-expo", at: url) { return true }
        let pkg = readText(url.appendingPathComponent("package.json")).lowercased()
        if pkg.contains("expo-router/entry") || pkg.contains("\"main\": \"expo") {
            return true
        }
        for name in ["app.json", "app.config.js", "app.config.ts"] where exists(name) {
            let text = readText(url.appendingPathComponent(name)).lowercased()
            // Require expo config object, not a random "expo" substring elsewhere
            if text.contains("\"expo\"") { return true }
        }
        return false
    }

    static func detectPort(at path: String, framework: Framework) -> Int? {
        let url = URL(fileURLWithPath: path)
        let envCandidates = [".env", ".env.local", ".env.development", ".env.development.local"]
        for name in envCandidates {
            let text = readText(url.appendingPathComponent(name))
            if let port = parsePort(fromEnv: text) { return port }
        }

        let pkg = readText(url.appendingPathComponent("package.json"))
        if let port = parsePort(fromPackageScripts: pkg) { return port }

        if framework == .vite || framework == .vue || framework == .svelte || framework == .sveltekit
            || framework == .solid || framework == .quasar {
            for name in ["vite.config.ts", "vite.config.js", "vite.config.mjs", "vite.config.mts"] {
                let text = readText(url.appendingPathComponent(name))
                if let port = parseNamedPort(text) { return port }
            }
        }

        return framework.defaultPort
    }

    // MARK: - Helpers

    private static func packageDepends(on name: String, at url: URL) -> Bool {
        let text = readText(url.appendingPathComponent("package.json"))
        // Match dependency keys precisely: "expo": not "@expo-google-fonts"
        let pattern = "\"\(NSRegularExpression.escapedPattern(for: name))\"\\s*:"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.lowercased().contains("\"\(name.lowercased())\":")
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    private static func pythonDepends(on name: String, at url: URL) -> Bool {
        let files = ["requirements.txt", "pyproject.toml", "Pipfile"]
        let needle = name.lowercased()
        for file in files {
            if readText(url.appendingPathComponent(file)).lowercased().contains(needle) {
                return true
            }
        }
        return false
    }

    private static func hasSpringProject(at url: URL) -> Bool {
        let pom = readText(url.appendingPathComponent("pom.xml")).lowercased()
        if pom.contains("spring-boot") { return true }
        for name in ["build.gradle", "build.gradle.kts"] {
            let text = readText(url.appendingPathComponent(name)).lowercased()
            if text.contains("spring-boot") || text.contains("org.springframework.boot") {
                return true
            }
        }
        return false
    }

    /// Android app / Kotlin Multiplatform (Gradle), not Spring Boot.
    /// Skip Expo/RN `android/` shells — those belong to the JS app root.
    private static func hasAndroidKotlinProject(at url: URL) -> Bool {
        let leaf = url.lastPathComponent.lowercased()
        if leaf == "android" {
            let parentPkg = url.deletingLastPathComponent().appendingPathComponent("package.json")
            if let text = (try? String(contentsOf: parentPkg, encoding: .utf8))?.lowercased(),
               text.contains("\"expo\"")
                || text.contains("\"react-native\"")
                || text.contains("expo-router") {
                return false
            }
        }

        let fm = FileManager.default
        let manifest = url.appendingPathComponent("app/src/main/AndroidManifest.xml")
        if fm.fileExists(atPath: manifest.path) { return true }

        let gradleFiles = [
            "settings.gradle", "settings.gradle.kts",
            "build.gradle", "build.gradle.kts",
            "app/build.gradle", "app/build.gradle.kts",
        ]
        for name in gradleFiles {
            let text = readText(url.appendingPathComponent(name)).lowercased()
            if text.contains("com.android.application")
                || text.contains("com.android.library")
                || text.contains("com.android.kotlin.multiplatform")
                || text.contains("org.jetbrains.kotlin.android")
                || text.contains("org.jetbrains.kotlin.multiplatform") {
                return true
            }
        }
        return false
    }

    private static func hasSwiftProject(at url: URL) -> Bool {
        // Skip Expo/RN `ios/` shells
        if url.lastPathComponent.lowercased() == "ios" {
            let parentPkg = url.deletingLastPathComponent().appendingPathComponent("package.json")
            if let text = (try? String(contentsOf: parentPkg, encoding: .utf8))?.lowercased(),
               text.contains("\"expo\"")
                || text.contains("\"react-native\"")
                || text.contains("expo-router") {
                return false
            }
        }

        let fm = FileManager.default
        if fm.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            return true
        }
        guard let items = try? fm.contentsOfDirectory(atPath: url.path) else { return false }
        return items.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
    }

    private static func hasDotnetProject(at url: URL) -> Bool {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: url.path) else { return false }
        return items.contains { $0.hasSuffix(".csproj") || $0.hasSuffix(".fsproj") || $0.hasSuffix(".sln") }
    }

    private static func readText(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private static func parsePort(fromEnv text: String) -> Int? {
        let patterns = [
            "PORT=", "APP_PORT=", "VITE_PORT=", "RCT_METRO_PORT=", "EXPO_PORT=",
            "ASPNETCORE_URLS=http://localhost:", "SERVER_PORT=",
        ]
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for prefix in patterns where trimmed.uppercased().hasPrefix(prefix.uppercased())
                || trimmed.hasPrefix(prefix) {
                var value = trimmed
                if let range = trimmed.range(of: prefix, options: [.caseInsensitive]) {
                    value = String(trimmed[range.upperBound...])
                } else if let idx = trimmed.firstIndex(of: "=") {
                    value = String(trimmed[trimmed.index(after: idx)...])
                }
                value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                // ASP.NET style http://localhost:5000
                if let regex = try? NSRegularExpression(pattern: #"(\d{2,5})"#),
                   let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                   let range = Range(match.range(at: 1), in: value),
                   let port = Int(value[range]) {
                    return port
                }
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

    private static func parseNamedPort(_ text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"port\s*:\s*(\d{2,5})"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[range])
    }
}
