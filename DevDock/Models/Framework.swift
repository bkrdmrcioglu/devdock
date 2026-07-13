import Foundation

enum Framework: String, Codable, CaseIterable, Identifiable {
    // Web
    case nextjs = "Next.js"
    case nuxt = "Nuxt"
    case remix = "Remix"
    case astro = "Astro"
    case gatsby = "Gatsby"
    case angular = "Angular"
    case sveltekit = "SvelteKit"
    case svelte = "Svelte"
    case solid = "Solid"
    case ember = "Ember"
    case vite = "Vite"
    case vue = "Vue"
    case react = "React"
    case quasar = "Quasar"

    // Mobile
    case expo = "Expo"
    case reactNative = "React Native"
    case flutter = "Flutter"
    case ionic = "Ionic"
    case swift = "Swift"
    case kotlin = "Kotlin"

    // Node API
    case nestjs = "NestJS"
    case express = "Express"
    case fastify = "Fastify"
    case hono = "Hono"
    case koa = "Koa"

    // Other backends
    case laravel = "Laravel"
    case symfony = "Symfony"
    case django = "Django"
    case flask = "Flask"
    case fastapi = "FastAPI"
    case rails = "Rails"
    case spring = "Spring Boot"
    case dotnet = ".NET"
    case phoenix = "Phoenix"
    case go = "Go"
    case rust = "Rust"

    // Desktop
    case electron = "Electron"
    case tauri = "Tauri"

    case unknown = "Unknown"

    var id: String { rawValue }

    enum StackRole: String, CaseIterable, Identifiable {
        case web
        case mobile
        case api
        case desktop
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .web: return "Web"
            case .mobile: return "Mobile"
            case .api: return "API"
            case .desktop: return "Desktop"
            case .other: return "Other"
            }
        }

        var systemImage: String {
            switch self {
            case .web: return "globe"
            case .mobile: return "iphone"
            case .api: return "server.rack"
            case .desktop: return "desktopcomputer"
            case .other: return "shippingbox"
            }
        }
    }

    var stackRole: StackRole {
        switch self {
        case .nextjs, .nuxt, .remix, .astro, .gatsby, .angular, .sveltekit, .svelte,
             .solid, .ember, .vite, .vue, .react, .quasar:
            return .web
        case .expo, .reactNative, .flutter, .ionic, .swift, .kotlin:
            return .mobile
        case .nestjs, .express, .fastify, .hono, .koa,
             .laravel, .symfony, .django, .flask, .fastapi, .rails,
             .spring, .dotnet, .phoenix, .go, .rust:
            return .api
        case .electron, .tauri:
            return .desktop
        case .unknown:
            return .other
        }
    }

    var defaultPort: Int? {
        switch self {
        case .nextjs, .nuxt, .remix, .gatsby, .react, .angular, .ember: return 3000
        case .astro: return 4321
        case .sveltekit, .svelte, .solid, .vite, .vue, .quasar: return 5173
        case .expo, .reactNative, .ionic: return 8081
        case .flutter: return 8080
        case .swift, .kotlin: return nil
        case .nestjs, .express, .fastify, .hono, .koa: return 3000
        case .laravel, .symfony: return 8000
        case .django, .flask, .fastapi: return 8000
        case .rails: return 3000
        case .spring: return 8080
        case .dotnet: return 5000
        case .phoenix: return 4000
        case .go, .rust: return 8080
        case .electron, .tauri, .unknown: return nil
        }
    }

    var startCommand: [String] {
        switch self {
        case .nextjs, .nuxt, .remix, .astro, .gatsby, .angular, .sveltekit, .svelte,
             .solid, .ember, .vite, .vue, .react, .quasar,
             .nestjs, .express, .fastify, .hono, .koa, .ionic, .electron:
            return ["npm", "run", "dev"]
        case .expo:
            return ["npx", "expo", "start", "--port", "8081"]
        case .reactNative:
            return ["npx", "react-native", "start", "--port", "8081"]
        case .flutter:
            return ["flutter", "run"] // resolved via StartCommandResolver (FVM-aware)
        case .swift:
            return ["swift", "run"] // Xcode apps resolved via SwiftProjectStart
        case .kotlin:
            return ["./gradlew", "installDebug"]
        case .laravel:
            return ["php", "artisan", "serve"]
        case .symfony:
            return ["symfony", "server:start", "--no-tls"]
        case .django:
            return ["python3", "manage.py", "runserver"]
        case .flask:
            return ["python3", "app.py"]
        case .fastapi:
            return ["uvicorn", "main:app", "--reload", "--port", "8000"]
        case .rails:
            return ["bin/rails", "server"]
        case .spring:
            return ["./mvnw", "spring-boot:run"]
        case .dotnet:
            return ["dotnet", "run"]
        case .phoenix:
            return ["mix", "phx.server"]
        case .go:
            return ["go", "run", "."]
        case .rust:
            return ["cargo", "run"]
        case .tauri:
            return ["npm", "run", "tauri", "dev"]
        case .unknown:
            return ["npm", "run", "dev"]
        }
    }

    /// Brand-ish accents tuned for dark UI (readable as label text on charcoal).
    var accentHex: String {
        switch self {
        case .nextjs: return "E5E7EB"
        case .nuxt: return "00DC82"
        case .remix: return "E8E8E8"
        case .astro: return "FF5D01"
        case .gatsby: return "B794F4"
        case .angular: return "DD0031"
        case .sveltekit, .svelte: return "FF3E00"
        case .solid: return "76B3F5"
        case .ember: return "E04E39"
        case .vite: return "A5B4FC"
        case .vue: return "42B883"
        case .quasar: return "00B4FF"
        case .react: return "61DAFB"
        case .expo: return "A3A1FF"
        case .reactNative: return "61DAFB"
        case .flutter: return "54C5F8"
        case .ionic: return "6EA8FE"
        case .swift: return "F05138"
        case .kotlin: return "A78BFA"
        case .nestjs: return "E0234E"
        case .express: return "68A063"
        case .fastify: return "C4C4C4"
        case .hono: return "E36002"
        case .koa: return "A8A8B3"
        case .laravel: return "FF2D20"
        case .symfony: return "C0C0C0"
        case .django: return "44B78B"
        case .flask: return "D1D5DB"
        case .fastapi: return "20C997"
        case .rails: return "FF4444"
        case .spring: return "6DB33F"
        case .dotnet: return "9B7AE8"
        case .phoenix: return "FD4F00"
        case .go: return "00ADD8"
        case .rust: return "DEA584"
        case .electron: return "6CB6C0"
        case .tauri: return "FFC131"
        case .unknown: return "9CA3AF"
        }
    }

    /// Relative luminance 0…1 — dark accents need chalk text on badges.
    var accentLuminance: Double {
        let hex = accentHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        guard hex.count == 6 else { return 0.5 }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    var accentNeedsLightLabel: Bool {
        accentLuminance < 0.45
    }

    var usesMetroBundler: Bool {
        self == .expo || self == .reactNative
    }

    var isNodeFamily: Bool {
        switch self {
        case .nextjs, .nuxt, .remix, .astro, .gatsby, .angular, .sveltekit, .svelte,
             .solid, .ember, .vite, .vue, .react, .quasar,
             .expo, .reactNative, .ionic,
             .nestjs, .express, .fastify, .hono, .koa,
             .electron, .tauri:
            return true
        default:
            return false
        }
    }

    /// Interactive stdin reload (`r`) — Expo / RN / Flutter.
    var supportsHotReload: Bool {
        usesMetroBundler || self == .flutter || self == .ionic
    }

    /// Flutter-style capital `R` hot restart.
    var supportsHotRestart: Bool {
        self == .flutter
    }

    var supportsClearCache: Bool {
        usesMetroBundler || self == .flutter
    }

    var supportsDeviceShortcuts: Bool {
        usesMetroBundler || self == .flutter || self == .ionic
    }
}
