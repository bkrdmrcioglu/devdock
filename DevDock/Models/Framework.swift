import Foundation

enum Framework: String, Codable, CaseIterable, Identifiable {
    case nextjs = "Next.js"
    case react = "React"
    case vue = "Vue"
    case nestjs = "NestJS"
    case express = "Express"
    case laravel = "Laravel"
    case django = "Django"
    case flask = "Flask"
    case rails = "Rails"
    case go = "Go"
    case rust = "Rust"
    case unknown = "Unknown"

    var id: String { rawValue }

    var defaultPort: Int? {
        switch self {
        case .nextjs, .react, .vue: return 3000
        case .nestjs, .express: return 3000
        case .laravel: return 8000
        case .django, .flask: return 8000
        case .rails: return 3000
        case .go: return 8080
        case .rust: return 8080
        case .unknown: return nil
        }
    }

    var startCommand: [String] {
        switch self {
        case .nextjs, .react, .vue, .nestjs, .express:
            return ["npm", "run", "dev"]
        case .laravel:
            return ["php", "artisan", "serve"]
        case .django:
            return ["python3", "manage.py", "runserver"]
        case .flask:
            return ["python3", "app.py"]
        case .rails:
            return ["bin/rails", "server"]
        case .go:
            return ["go", "run", "."]
        case .rust:
            return ["cargo", "run"]
        case .unknown:
            return ["npm", "run", "dev"]
        }
    }

    var accentHex: String {
        switch self {
        case .nextjs: return "111111"
        case .react: return "61DAFB"
        case .vue: return "42B883"
        case .nestjs: return "E0234E"
        case .express: return "68A063"
        case .laravel: return "FF2D20"
        case .django: return "092E20"
        case .flask: return "000000"
        case .rails: return "CC0000"
        case .go: return "00ADD8"
        case .rust: return "DEA584"
        case .unknown: return "6B7280"
        }
    }
}
