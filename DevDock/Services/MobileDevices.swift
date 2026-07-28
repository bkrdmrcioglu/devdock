import Foundation

/// Shared iOS Simulator / Android Emulator discovery for Expo, RN, Ionic, and Flutter shortcuts.
enum MobileDevices {
    enum Kind: String, Hashable {
        case iosSimulator
        case iosDevice
        case androidEmulator
        case androidDevice
    }

    struct Device: Identifiable, Hashable {
        let id: String
        let name: String
        let subtitle: String
        let kind: Kind

        var systemImage: String {
            switch kind {
            case .iosSimulator, .iosDevice: return "apple.logo"
            case .androidEmulator, .androidDevice: return "smartphone"
            }
        }

        var isVirtual: Bool {
            kind == .iosSimulator || kind == .androidEmulator
        }
    }

    // MARK: - Public API

    /// Booted simulators + attached adb devices (for the Connected list).
    static func connectedTargets() -> [Device] {
        var result: [Device] = []

        for sim in simctlDevices() where sim.state == "Booted" {
            result.append(
                Device(
                    id: sim.udid,
                    name: sim.name,
                    subtitle: "simulator · \(shortRuntime(sim.runtime)) · Booted",
                    kind: .iosSimulator
                )
            )
        }

        for phone in physicalIOSDevices() {
            result.append(phone)
        }

        for android in adbDevices() {
            result.append(android)
        }

        return result
    }

    static func preferredIOSSimulator() -> Device? {
        let sims = simctlDevices()
        guard !sims.isEmpty else { return nil }
        if let booted = sims.first(where: { $0.state == "Booted" }) {
            return Device(
                id: booted.udid,
                name: booted.name,
                subtitle: "simulator · \(shortRuntime(booted.runtime))",
                kind: .iosSimulator
            )
        }
        let iphones = sims.filter { $0.name.localizedCaseInsensitiveContains("iPhone") }
        let pool = iphones.isEmpty ? sims : iphones
        guard let best = pool.sorted(by: simSort).first else { return nil }
        return Device(
            id: best.udid,
            name: best.name,
            subtitle: "simulator · \(shortRuntime(best.runtime))",
            kind: .iosSimulator
        )
    }

    static func preferredAndroidEmulator() -> Device? {
        let androids = adbDevices()
        if let emu = androids.first(where: { $0.kind == .androidEmulator }) {
            return emu
        }
        return launchDefaultAndroidEmulator()
    }

    /// Boots simulator if needed and opens Simulator.app.
    /// Call only on explicit user action (iOS Quick target / Flutter ios resolve) — never from command resolve.
    @discardableResult
    static func prepareIOSSimulator(udid: String) -> Bool {
        guard bootSimctlDeviceIfNeeded(udid: udid) else { return false }
        // `simctl boot` returns as soon as the boot request is issued, not once springboard is
        // actually up — a cold boot can take well past that. Poll actual device state so callers
        // (e.g. `flutter run -d <udid>`) don't race a simulator that's still coming up.
        let booted = waitForSimulatorBooted(udid: udid)
        // Avoid focusing Simulator.app if the device is already Booted and app is running.
        if !booted || !isSimulatorAppRunning() {
            openSimulatorApp()
        }
        return booted
    }

    /// Poll `simctl list devices` until `udid` reports state "Booted", or `timeout` elapses.
    @discardableResult
    static func waitForSimulatorBooted(udid: String, timeout: TimeInterval = 60) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if simctlDeviceState(udid: udid) == "Booted" {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    private static func simctlDeviceState(udid: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "-j"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.environment = Toolchain.processEnvironment()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesByRuntime = json["devices"] as? [String: Any] else {
            return nil
        }
        for (_, value) in devicesByRuntime {
            guard let items = value as? [[String: Any]] else { continue }
            for item in items {
                if let itemUDID = item["udid"] as? String, itemUDID == udid {
                    return item["state"] as? String
                }
            }
        }
        return nil
    }

    private static func isSimulatorAppRunning() -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "Simulator"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - simctl

    private struct SimctlEntry {
        let udid: String
        let name: String
        let state: String
        let runtime: String
    }

    private static func simctlDevices() -> [SimctlEntry] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "available", "-j"]
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
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesByRuntime = json["devices"] as? [String: Any] else {
            return []
        }

        var result: [SimctlEntry] = []
        for (runtime, value) in devicesByRuntime {
            guard runtime.contains("iOS"), let items = value as? [[String: Any]] else { continue }
            for item in items {
                guard let name = item["name"] as? String,
                      let udid = item["udid"] as? String,
                      let state = item["state"] as? String else { continue }
                if let available = item["isAvailable"] as? Bool, available == false { continue }
                result.append(SimctlEntry(udid: udid, name: name, state: state, runtime: runtime))
            }
        }
        return result
    }

    private static func simSort(_ lhs: SimctlEntry, _ rhs: SimctlEntry) -> Bool {
        if lhs.runtime != rhs.runtime { return lhs.runtime > rhs.runtime }
        return phonePreferenceScore(lhs.name) > phonePreferenceScore(rhs.name)
    }

    private static func phonePreferenceScore(_ name: String) -> Int {
        let n = name.lowercased()
        if n.contains("pro max") { return 40 }
        if n.contains("pro") { return 30 }
        if n.contains("plus") { return 20 }
        if n.contains("iphone") { return 10 }
        return 0
    }

    private static func shortRuntime(_ runtime: String) -> String {
        runtime.split(separator: ".").last.map(String.init) ?? runtime
    }

    @discardableResult
    static func bootSimctlDeviceIfNeeded(udid: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "boot", udid]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.environment = Toolchain.processEnvironment()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 || process.terminationStatus == 149
        } catch {
            return false
        }
    }

    static func openSimulatorApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Simulator"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Physical iOS (best-effort)

    private static func physicalIOSDevices() -> [Device] {
        // `xcrun xctrace list devices` includes sims + devices; filter non-simulator.
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xctrace", "list", "devices"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.environment = Toolchain.processEnvironment()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var result: [Device] = []
        var inDevices = false
        for raw in text.split(whereSeparator: \.isNewline).map(String.init) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.lowercased().contains("== devices ==") {
                inDevices = true
                continue
            }
            if line.lowercased().contains("== simulators ==") {
                inDevices = false
                continue
            }
            guard inDevices, !line.isEmpty else { continue }
            // "Bekir’s iPhone (26.5) (00008140-...)"
            guard let open = line.lastIndex(of: "("),
                  let close = line.lastIndex(of: ")"),
                  open < close else { continue }
            let udid = String(line[line.index(after: open)..<close])
            guard udid.count >= 20, !udid.contains(".") else { continue }
            let name = String(line[..<open]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            result.append(
                Device(id: udid, name: name, subtitle: "device · physical", kind: .iosDevice)
            )
        }
        return result
    }

    // MARK: - Android / adb

    private static func adbPath() -> String? {
        if let resolved = Toolchain.resolveExecutable("adb") {
            return resolved
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/Library/Android/sdk/platform-tools/adb",
            "/opt/homebrew/bin/adb",
            "/usr/local/bin/adb",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func emulatorPath() -> String? {
        if let resolved = Toolchain.resolveExecutable("emulator") {
            return resolved
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/Library/Android/sdk/emulator/emulator",
            "/opt/homebrew/bin/emulator",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func adbDevices() -> [Device] {
        guard let adb = adbPath() else { return [] }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: adb)
        process.arguments = ["devices", "-l"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.environment = Toolchain.processEnvironment()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var result: [Device] = []
        for raw in text.split(whereSeparator: \.isNewline).map(String.init) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.lowercased().hasPrefix("list of devices") else { continue }
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2, parts[1] == "device" else { continue }
            let serial = parts[0]
            let isEmu = serial.hasPrefix("emulator-")
            let model = parts.first(where: { $0.hasPrefix("model:") })?
                .replacingOccurrences(of: "model:", with: "")
                .replacingOccurrences(of: "_", with: " ")
            let name = model?.isEmpty == false ? model! : serial
            result.append(
                Device(
                    id: serial,
                    name: name,
                    subtitle: isEmu ? "emulator · \(serial)" : "device · \(serial)",
                    kind: isEmu ? .androidEmulator : .androidDevice
                )
            )
        }
        return result
    }

    /// Launch first AVD if no emulator is running.
    private static func launchDefaultAndroidEmulator() -> Device? {
        guard let emulator = emulatorPath() else { return nil }
        let list = Process()
        let pipe = Pipe()
        list.executableURL = URL(fileURLWithPath: emulator)
        list.arguments = ["-list-avds"]
        list.standardOutput = pipe
        list.standardError = Pipe()
        list.environment = Toolchain.processEnvironment()
        do {
            try list.run()
            list.waitUntilExit()
        } catch {
            return nil
        }
        let avds = (String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let avd = avds.first else { return nil }

        let launch = Process()
        launch.executableURL = URL(fileURLWithPath: emulator)
        launch.arguments = ["-avd", avd]
        launch.standardOutput = Pipe()
        launch.standardError = Pipe()
        launch.environment = Toolchain.processEnvironment()
        do {
            try launch.run()
        } catch {
            return nil
        }

        // Wait briefly for adb to see it
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.5)
            if let emu = adbDevices().first(where: { $0.kind == .androidEmulator }) {
                return emu
            }
        }
        return Device(
            id: "emulator",
            name: avd,
            subtitle: "emulator · launching",
            kind: .androidEmulator
        )
    }
}
