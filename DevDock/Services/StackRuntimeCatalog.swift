import Foundation

/// Built-in one-shot helpers shown in project detail (not the long-running start process).
enum StackRuntimeCatalog {
    struct Helper: Identifiable, Hashable {
        var id: String { "\(key)|\(title)|\(argv.joined(separator: " "))" }
        let key: String
        let title: String
        let argv: [String]
        let systemImage: String
    }

    static func helpers(for framework: Framework, at path: String) -> [Helper] {
        switch framework {
        case .expo, .reactNative, .ionic:
            var list = nodeInstallBuild(at: path)
            let doctor = doctorCommand(for: framework, at: path)
            if !doctor.isEmpty {
                list.append(Helper(key: "doc", title: "Doctor", argv: doctor, systemImage: "stethoscope"))
            }
            return list

        case .flutter:
            let base = FlutterDevices.flutterBaseCommand(at: path)
            return [
                Helper(key: "get", title: "pub get", argv: base + ["pub", "get"], systemImage: "arrow.down.circle"),
                Helper(key: "out", title: "pub outdated", argv: base + ["pub", "outdated"], systemImage: "clock.arrow.circlepath"),
                Helper(key: "cln", title: "flutter clean", argv: base + ["clean"], systemImage: "trash"),
                Helper(key: "anl", title: "analyze", argv: base + ["analyze"], systemImage: "checkmark.seal"),
                Helper(key: "tst", title: "test", argv: base + ["test"], systemImage: "checkmark.diamond"),
            ]

        case .swift:
            var list = [
                Helper(key: "bld", title: "swift build", argv: ["swift", "build"], systemImage: "hammer"),
                Helper(key: "tst", title: "swift test", argv: ["swift", "test"], systemImage: "checkmark.diamond"),
            ]
            if FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("Package.swift")) {
                list.insert(
                    Helper(key: "res", title: "package resolve", argv: ["swift", "package", "resolve"], systemImage: "arrow.triangle.2.circlepath"),
                    at: 0
                )
            }
            return list

        case .kotlin:
            let gradle = FileManager.default.isExecutableFile(atPath: (path as NSString).appendingPathComponent("gradlew"))
                ? "./gradlew" : "gradle"
            return [
                Helper(key: "asm", title: "assembleDebug", argv: [gradle, "assembleDebug"], systemImage: "hammer"),
                Helper(key: "ins", title: "installDebug", argv: [gradle, "installDebug"], systemImage: "iphone.and.arrow.forward"),
                Helper(key: "cln", title: "clean", argv: [gradle, "clean"], systemImage: "trash"),
            ]

        case .nextjs, .nuxt, .remix, .astro, .gatsby, .angular, .sveltekit, .svelte,
             .solid, .ember, .vite, .vue, .react, .quasar:
            return nodeInstallBuild(at: path) + nodeLintTest(at: path)

        case .nestjs, .express, .fastify, .hono, .koa, .electron:
            return nodeInstallBuild(at: path) + nodeLintTest(at: path)

        case .tauri:
            return nodeInstallBuild(at: path) + [
                Helper(key: "chk", title: "cargo check", argv: ["cargo", "check"], systemImage: "checkmark.circle"),
            ]

        case .laravel:
            return [
                Helper(key: "mig", title: "migrate", argv: ["php", "artisan", "migrate"], systemImage: "cylinder.split.1x2"),
                Helper(key: "seed", title: "db:seed", argv: ["php", "artisan", "db:seed"], systemImage: "leaf"),
                Helper(key: "frsh", title: "migrate:fresh", argv: ["php", "artisan", "migrate:fresh", "--seed"], systemImage: "arrow.counterclockwise"),
                Helper(key: "rte", title: "route:list", argv: ["php", "artisan", "route:list"], systemImage: "point.3.connected.trianglepath.dotted"),
                Helper(key: "clr", title: "optimize:clear", argv: ["php", "artisan", "optimize:clear"], systemImage: "sparkles"),
                Helper(key: "tnk", title: "tinker", argv: ["php", "artisan", "tinker"], systemImage: "terminal"),
            ]

        case .symfony:
            return [
                Helper(key: "cch", title: "cache:clear", argv: ["php", "bin/console", "cache:clear"], systemImage: "sparkles"),
                Helper(key: "rte", title: "debug:router", argv: ["php", "bin/console", "debug:router"], systemImage: "point.3.connected.trianglepath.dotted"),
                Helper(key: "mig", title: "doctrine:migrate", argv: ["php", "bin/console", "doctrine:migrations:migrate", "--no-interaction"], systemImage: "cylinder.split.1x2"),
            ]

        case .django:
            return [
                Helper(key: "mig", title: "migrate", argv: ["python3", "manage.py", "migrate"], systemImage: "cylinder.split.1x2"),
                Helper(key: "mk", title: "makemigrations", argv: ["python3", "manage.py", "makemigrations"], systemImage: "plus.rectangle.on.folder"),
                Helper(key: "sh", title: "shell", argv: ["python3", "manage.py", "shell"], systemImage: "terminal"),
                Helper(key: "chk", title: "check", argv: ["python3", "manage.py", "check"], systemImage: "checkmark.seal"),
                Helper(key: "cst", title: "collectstatic", argv: ["python3", "manage.py", "collectstatic", "--noinput"], systemImage: "folder.badge.plus"),
            ]

        case .flask, .fastapi:
            return [
                Helper(key: "pip", title: "pip install", argv: ["pip3", "install", "-r", "requirements.txt"], systemImage: "arrow.down.circle"),
                Helper(key: "tst", title: "pytest", argv: ["pytest"], systemImage: "checkmark.diamond"),
            ]

        case .rails:
            return [
                Helper(key: "mig", title: "db:migrate", argv: ["bin/rails", "db:migrate"], systemImage: "cylinder.split.1x2"),
                Helper(key: "seed", title: "db:seed", argv: ["bin/rails", "db:seed"], systemImage: "leaf"),
                Helper(key: "con", title: "console", argv: ["bin/rails", "console"], systemImage: "terminal"),
                Helper(key: "rte", title: "routes", argv: ["bin/rails", "routes"], systemImage: "point.3.connected.trianglepath.dotted"),
                Helper(key: "tst", title: "test", argv: ["bin/rails", "test"], systemImage: "checkmark.diamond"),
            ]

        case .phoenix:
            return [
                Helper(key: "dep", title: "deps.get", argv: ["mix", "deps.get"], systemImage: "arrow.down.circle"),
                Helper(key: "mig", title: "ecto.migrate", argv: ["mix", "ecto.migrate"], systemImage: "cylinder.split.1x2"),
                Helper(key: "tst", title: "test", argv: ["mix", "test"], systemImage: "checkmark.diamond"),
                Helper(key: "fmt", title: "format", argv: ["mix", "format"], systemImage: "text.alignleft"),
            ]

        case .spring:
            if FileManager.default.isExecutableFile(atPath: (path as NSString).appendingPathComponent("mvnw")) {
                return [
                    Helper(key: "pkg", title: "mvn package", argv: ["./mvnw", "-q", "package", "-DskipTests"], systemImage: "shippingbox"),
                    Helper(key: "tst", title: "mvn test", argv: ["./mvnw", "test"], systemImage: "checkmark.diamond"),
                ]
            }
            if FileManager.default.isExecutableFile(atPath: (path as NSString).appendingPathComponent("gradlew")) {
                return [
                    Helper(key: "bld", title: "gradle build", argv: ["./gradlew", "build", "-x", "test"], systemImage: "hammer"),
                    Helper(key: "tst", title: "gradle test", argv: ["./gradlew", "test"], systemImage: "checkmark.diamond"),
                ]
            }
            return [
                Helper(key: "pkg", title: "mvn package", argv: ["mvn", "-q", "package", "-DskipTests"], systemImage: "shippingbox"),
                Helper(key: "tst", title: "mvn test", argv: ["mvn", "test"], systemImage: "checkmark.diamond"),
            ]

        case .dotnet:
            return [
                Helper(key: "rst", title: "restore", argv: ["dotnet", "restore"], systemImage: "arrow.down.circle"),
                Helper(key: "bld", title: "build", argv: ["dotnet", "build"], systemImage: "hammer"),
                Helper(key: "tst", title: "test", argv: ["dotnet", "test"], systemImage: "checkmark.diamond"),
            ]

        case .go:
            return [
                Helper(key: "tdy", title: "mod tidy", argv: ["go", "mod", "tidy"], systemImage: "wrench.and.screwdriver"),
                Helper(key: "bld", title: "build", argv: ["go", "build", "./..."], systemImage: "hammer"),
                Helper(key: "tst", title: "test", argv: ["go", "test", "./..."], systemImage: "checkmark.diamond"),
                Helper(key: "vet", title: "vet", argv: ["go", "vet", "./..."], systemImage: "checkmark.seal"),
            ]

        case .rust:
            return [
                Helper(key: "chk", title: "check", argv: ["cargo", "check"], systemImage: "checkmark.circle"),
                Helper(key: "bld", title: "build", argv: ["cargo", "build"], systemImage: "hammer"),
                Helper(key: "tst", title: "test", argv: ["cargo", "test"], systemImage: "checkmark.diamond"),
                Helper(key: "fmt", title: "fmt", argv: ["cargo", "fmt"], systemImage: "text.alignleft"),
                Helper(key: "clp", title: "clippy", argv: ["cargo", "clippy"], systemImage: "scissors"),
            ]

        case .unknown:
            if FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("package.json")) {
                return nodeInstallBuild(at: path)
            }
            return []
        }
    }

    static var sectionTitle: String { "Stack commands" }

    private static func nodeInstallBuild(at path: String) -> [Helper] {
        let pm = PackageManager.detect(at: path)
        switch pm {
        case .npm:
            return [
                Helper(key: "i", title: "npm install", argv: ["npm", "install"], systemImage: "arrow.down.circle"),
                Helper(key: "bld", title: "npm run build", argv: ["npm", "run", "build"], systemImage: "hammer"),
            ]
        case .pnpm:
            return [
                Helper(key: "i", title: "pnpm install", argv: ["pnpm", "install"], systemImage: "arrow.down.circle"),
                Helper(key: "bld", title: "pnpm build", argv: ["pnpm", "run", "build"], systemImage: "hammer"),
            ]
        case .yarn:
            return [
                Helper(key: "i", title: "yarn", argv: ["yarn", "install"], systemImage: "arrow.down.circle"),
                Helper(key: "bld", title: "yarn build", argv: ["yarn", "build"], systemImage: "hammer"),
            ]
        case .bun:
            return [
                Helper(key: "i", title: "bun install", argv: ["bun", "install"], systemImage: "arrow.down.circle"),
                Helper(key: "bld", title: "bun run build", argv: ["bun", "run", "build"], systemImage: "hammer"),
            ]
        }
    }

    private static func nodeLintTest(at path: String) -> [Helper] {
        let scripts = packageScripts(at: path)
        let pm = PackageManager.detect(at: path)
        var helpers: [Helper] = []
        if scripts.contains("lint") {
            helpers.append(Helper(key: "lint", title: "lint", argv: pm.runPrefix + ["lint"], systemImage: "paintbrush"))
        }
        if scripts.contains("test") {
            helpers.append(Helper(key: "tst", title: "test", argv: pm.runPrefix + ["test"], systemImage: "checkmark.diamond"))
        }
        if scripts.contains("typecheck") {
            helpers.append(Helper(key: "tsc", title: "typecheck", argv: pm.runPrefix + ["typecheck"], systemImage: "text.badge.checkmark"))
        }
        return helpers
    }

    private static func packageScripts(at path: String) -> Set<String> {
        let url = URL(fileURLWithPath: path).appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: Any] else {
            return []
        }
        return Set(scripts.keys)
    }

    private static func doctorCommand(for framework: Framework, at path: String) -> [String] {
        switch framework {
        case .expo:
            return ["npx", "expo-doctor"]
        case .reactNative:
            return ["npx", "react-native", "doctor"]
        default:
            return []
        }
    }
}
