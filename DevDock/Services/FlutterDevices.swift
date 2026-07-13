import Foundation

/// Resolves `flutter devices --machine` targets for iOS / Android / web / desktop.
enum FlutterDevices {
    struct Device: Decodable, Identifiable, Hashable {
        let name: String
        let id: String
        let isSupported: Bool?
        let targetPlatform: String
        let emulator: Bool?
        let sdk: String?

        var isAvailable: Bool { isSupported != false }

        var kindLabel: String {
            if emulator == true { return "emulator" }
            if targetPlatform.contains("web") { return "browser" }
            if targetPlatform.hasPrefix("darwin")
                || targetPlatform.hasPrefix("windows")
                || targetPlatform.hasPrefix("linux") {
                return "desktop"
            }
            return "device"
        }

        var subtitle: String {
            var parts: [String] = [kindLabel]
            if let sdk, !sdk.isEmpty {
                parts.append(sdk)
            } else {
                parts.append(targetPlatform)
            }
            return parts.joined(separator: " · ")
        }

        var systemImage: String {
            if targetPlatform.hasPrefix("ios") { return "apple.logo" }
            if targetPlatform.hasPrefix("android") { return "smartphone" }
            if targetPlatform.contains("web") { return "globe" }
            if targetPlatform.hasPrefix("darwin") { return "desktopcomputer" }
            if targetPlatform.hasPrefix("windows") { return "pc" }
            if targetPlatform.hasPrefix("linux") { return "laptopcomputer" }
            return "cpu"
        }
    }

    struct Resolved {
        let id: String
        let label: String
    }

    static func flutterBaseCommand(at path: String) -> [String] {
        let fvmConfig = (path as NSString).appendingPathComponent(".fvm")
        let fvmrc = (path as NSString).appendingPathComponent(".fvmrc")
        if FileManager.default.fileExists(atPath: fvmConfig)
            || FileManager.default.fileExists(atPath: fvmrc),
           Toolchain.resolveExecutable("fvm", path: path) != nil {
            return ["fvm", "flutter"]
        }
        return ["flutter"]
    }

    static func list(at path: String) -> [Device] {
        let base = flutterBaseCommand(at: path)
        guard let executable = Toolchain.resolveExecutable(base[0], path: path) else {
            return []
        }

        let process = Process()
        let pipe = Pipe()
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(base.dropFirst()) + ["devices", "--machine"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.environment = Toolchain.processEnvironment()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = extractJSONArray(from: data) else { return [] }
        return (try? JSONDecoder().decode([Device].self, from: json)) ?? []
    }

    /// Available devices only — physical / sim first, then desktop, then web.
    static func available(at path: String) -> [Device] {
        list(at: path)
            .filter(\.isAvailable)
            .sorted { lhs, rhs in
                rank(lhs) < rank(rhs)
            }
    }

    private static func rank(_ device: Device) -> Int {
        if device.targetPlatform.hasPrefix("ios") { return device.emulator == true ? 1 : 0 }
        if device.targetPlatform.hasPrefix("android") { return device.emulator == true ? 3 : 2 }
        if device.targetPlatform.hasPrefix("darwin") { return 4 }
        if device.targetPlatform.hasPrefix("windows") || device.targetPlatform.hasPrefix("linux") { return 5 }
        if device.targetPlatform.contains("web") { return 6 }
        return 7
    }

    /// Map UI platform keys to a concrete `-d` id.
    /// iOS / Android shortcuts always target simulator/emulator — never a physical phone.
    static func resolve(platform: String, at path: String) -> Resolved? {
        let key = platform.lowercased()
        let devices = available(at: path)

        switch key {
        case "ios", "i", "ios-simulator", "simulator":
            return resolveIOSSimulator(from: devices)

        case "android", "a", "android-emulator", "emulator":
            return resolveAndroidEmulator(from: devices, projectPath: path)

        case "web", "w", "chrome":
            if let chrome = devices.first(where: { $0.id == "chrome" || isWeb($0) }) {
                return Resolved(id: chrome.id, label: chrome.name)
            }
            return Resolved(id: "chrome", label: "Chrome")

        case "macos", "mac", "darwin":
            if let mac = devices.first(where: { $0.id == "macos" || $0.targetPlatform.hasPrefix("darwin") }) {
                return Resolved(id: mac.id, label: mac.name)
            }
            return Resolved(id: "macos", label: "macOS")

        case "windows", "win":
            if let win = devices.first(where: { $0.id == "windows" || $0.targetPlatform.hasPrefix("windows") }) {
                return Resolved(id: win.id, label: win.name)
            }
            return Resolved(id: "windows", label: "Windows")

        case "linux":
            if let linux = devices.first(where: { $0.id == "linux" || $0.targetPlatform.hasPrefix("linux") }) {
                return Resolved(id: linux.id, label: linux.name)
            }
            return Resolved(id: "linux", label: "Linux")

        default:
            if let match = devices.first(where: {
                $0.id.localizedCaseInsensitiveContains(key) || $0.name.localizedCaseInsensitiveContains(key)
            }) {
                return Resolved(id: match.id, label: match.name)
            }
            return Resolved(id: platform, label: platform)
        }
    }

    /// Booted Flutter iOS simulator, else a shutdown Simulator from simctl (never physical).
    private static func resolveIOSSimulator(from devices: [Device]) -> Resolved? {
        if let sim = devices.first(where: { isIOS($0) && $0.emulator == true }) {
            return Resolved(id: sim.id, label: "\(sim.name) (simulator)")
        }
        if let preferred = MobileDevices.preferredIOSSimulator() {
            _ = MobileDevices.prepareIOSSimulator(udid: preferred.id)
            return Resolved(id: preferred.id, label: "\(preferred.name) (simulator)")
        }
        return nil
    }

    /// Running Android emulator only — never a plugged-in phone.
    private static func resolveAndroidEmulator(from devices: [Device], projectPath: String) -> Resolved? {
        if let emu = devices.first(where: { isAndroid($0) && $0.emulator == true }) {
            return Resolved(id: emu.id, label: "\(emu.name) (emulator)")
        }
        if let preferred = MobileDevices.preferredAndroidEmulator() {
            return Resolved(id: preferred.id, label: "\(preferred.name) (emulator)")
        }
        if let launched = launchFlutterAndroidEmulator(projectPath: projectPath) {
            return launched
        }
        return nil
    }

    private static func launchFlutterAndroidEmulator(projectPath: String) -> Resolved? {
        let base = flutterBaseCommand(at: projectPath)
        guard let executable = Toolchain.resolveExecutable(base[0], path: projectPath) else {
            return nil
        }

        // List flutter emulators; pick first android*
        let list = Process()
        let out = Pipe()
        list.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        list.executableURL = URL(fileURLWithPath: executable)
        list.arguments = Array(base.dropFirst()) + ["emulators"]
        list.standardOutput = out
        list.standardError = Pipe()
        list.environment = Toolchain.processEnvironment()
        do {
            try list.run()
            list.waitUntilExit()
        } catch {
            return nil
        }
        let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // Typical line: "apple_ios_simulator • iOS Simulator  • Apple"
        // or "Pixel_6 • Pixel 6 • Google"
        let androidID = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { line -> String? in
                guard !line.isEmpty, !line.lowercased().hasPrefix("id"), !line.contains("No emulators") else {
                    return nil
                }
                let id = line.split(separator: "•").first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !id.isEmpty else { return nil }
                let lower = line.lowercased()
                if lower.contains("ios") || lower.contains("apple") { return nil }
                return id
            }
            .first

        guard let androidID else { return nil }

        let launch = Process()
        launch.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        launch.executableURL = URL(fileURLWithPath: executable)
        launch.arguments = Array(base.dropFirst()) + ["emulators", "--launch", androidID]
        launch.standardOutput = Pipe()
        launch.standardError = Pipe()
        launch.environment = Toolchain.processEnvironment()
        do {
            try launch.run()
            launch.waitUntilExit()
        } catch {
            return nil
        }

        // Prefer concrete emulator id once it shows up; fall back to -d emulator
        Thread.sleep(forTimeInterval: 1.5)
        if let emu = available(at: projectPath).first(where: { isAndroid($0) && $0.emulator == true }) {
            return Resolved(id: emu.id, label: "\(emu.name) (emulator)")
        }
        return Resolved(id: "emulator", label: "Android Emulator")
    }

    static func summaryLines(at path: String) -> [String] {
        let devices = list(at: path)
        if devices.isEmpty {
            return ["No Flutter devices found. Open Simulator / start an emulator, or enable web."]
        }
        return devices.map { device in
            let support = device.isSupported == false ? " · unsupported" : ""
            return "• \(device.name) [\(device.id)] · \(device.subtitle)\(support)"
        }
    }

    private static func isIOS(_ device: Device) -> Bool {
        device.targetPlatform.hasPrefix("ios")
    }

    private static func isAndroid(_ device: Device) -> Bool {
        device.targetPlatform.hasPrefix("android")
    }

    private static func isWeb(_ device: Device) -> Bool {
        device.targetPlatform.contains("web")
    }

    /// Flutter sometimes prints banners before the JSON array.
    private static func extractJSONArray(from data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]") else {
            return nil
        }
        return String(text[start...end]).data(using: .utf8)
    }
}
