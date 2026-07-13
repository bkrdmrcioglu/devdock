import Foundation

/// Resolve a real Start command for Swift: SPM `swift run`, or Xcode build+launch
/// on iOS Simulator / macOS (never just `open` Xcode).
enum SwiftProjectStart {
    static func command(at path: String) -> [String] {
        if FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("Package.swift")) {
            return ["swift", "run"]
        }

        guard let project = xcodeProjectFlag(at: path) else {
            return ["swift", "run"]
        }

        let scheme = preferredScheme(at: path) ?? URL(fileURLWithPath: path).lastPathComponent

        // Pick a UDID only — do NOT boot / open Simulator here.
        // `StartCommandResolver` runs on launch + Rescan + metadata refresh;
        // side effects would reopen Simulator.app constantly. Boot happens in the run script.
        let simulatorUDID = MobileDevices.preferredIOSSimulator()?.id ?? ""

        let scriptPath = writeRunScript(
            flag: project.flag,
            projectPath: project.value,
            scheme: scheme,
            simulatorUDID: simulatorUDID
        )
        return ["/bin/bash", scriptPath]
    }

    private static func xcodeProjectFlag(at path: String) -> (flag: String, value: String)? {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: path) else { return nil }
        if let workspace = items.first(where: { $0.hasSuffix(".xcworkspace") }) {
            return ("-workspace", (path as NSString).appendingPathComponent(workspace))
        }
        if let project = items.first(where: { $0.hasSuffix(".xcodeproj") }) {
            return ("-project", (path as NSString).appendingPathComponent(project))
        }
        return nil
    }

    private static func preferredScheme(at path: String) -> String? {
        let schemes = sharedSchemeNames(at: path)
        if schemes.isEmpty { return nil }
        let folder = URL(fileURLWithPath: path).lastPathComponent
        if let exact = schemes.first(where: { $0.caseInsensitiveCompare(folder) == .orderedSame }) {
            return exact
        }
        let filtered = schemes.filter {
            let lower = $0.lowercased()
            return !lower.contains("test") && !lower.contains("pods")
        }
        return filtered.first ?? schemes.first
    }

    private static func sharedSchemeNames(at path: String) -> [String] {
        let fm = FileManager.default
        var names: [String] = []
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        for item in items where item.hasSuffix(".xcodeproj") || item.hasSuffix(".xcworkspace") {
            let schemeDir = ((path as NSString).appendingPathComponent(item) as NSString)
                .appendingPathComponent("xcshareddata/xcschemes")
            guard let schemes = try? fm.contentsOfDirectory(atPath: schemeDir) else { continue }
            for scheme in schemes where scheme.hasSuffix(".xcscheme") {
                names.append((scheme as NSString).deletingPathExtension)
            }
        }
        return names.sorted()
    }

    private static func writeRunScript(
        flag: String,
        projectPath: String,
        scheme: String,
        simulatorUDID: String
    ) -> String {
        let scriptPath = NSTemporaryDirectory() + "devdock-swift-\(UUID().uuidString).sh"
        let body = """
        #!/bin/bash
        # DevDock Swift/iOS runner — keep alive until Stop
        set +e
        FLAG=\(shellQuote(flag))
        PROJECT=\(shellQuote(projectPath))
        SCHEME=\(shellQuote(scheme))
        BOOTED=\(shellQuote(simulatorUDID))
        BUNDLE=""
        DD="$(mktemp -d /tmp/devdock-swift-dd.XXXXXX)"

        cleanup_dd() { rm -rf "$DD" 2>/dev/null; rm -f \(shellQuote(scriptPath)) 2>/dev/null; }
        on_stop() {
          echo "DevDock · Stopping…"
          if [ -n "${BOOTED}" ] && [ -n "${BUNDLE}" ]; then
            xcrun simctl terminate "$BOOTED" "$BUNDLE" >/dev/null 2>&1
          fi
          cleanup_dd
          exit 0
        }
        trap on_stop INT TERM
        # Do NOT trap EXIT for cleanup while waiting — Stop sends TERM.

        echo "DevDock · Swift scheme: $SCHEME"
        export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
        export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"

        if ! command -v xcrun >/dev/null 2>&1; then
          echo "DevDock · xcrun not found. Install Xcode + CLT."
          cleanup_dd
          exit 1
        fi

        if [ -n "$BOOTED" ]; then
          echo "DevDock · Using iOS Simulator: $BOOTED"
          xcrun simctl boot "$BOOTED" >/dev/null 2>&1
          open -a Simulator >/dev/null 2>&1
          sleep 2

          echo "DevDock · Building (this can take a minute)…"
          xcodebuild "$FLAG" "$PROJECT" -scheme "$SCHEME" \\
            -configuration Debug \\
            -destination "platform=iOS Simulator,id=$BOOTED" \\
            -derivedDataPath "$DD" \\
            build
          BUILD_STATUS=$?
          if [ $BUILD_STATUS -ne 0 ]; then
            echo "DevDock · xcodebuild failed ($BUILD_STATUS)"
            cleanup_dd
            exit $BUILD_STATUS
          fi

          APP="$(find "$DD/Build/Products" -type d -name '*.app' -print -quit 2>/dev/null)"
          if [ -z "$APP" ]; then
            echo "DevDock · No .app in build products — check scheme '$SCHEME' is shared."
            cleanup_dd
            exit 1
          fi
          echo "DevDock · App: $APP"

          BUNDLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null)"
          if [ -z "$BUNDLE" ]; then
            echo "DevDock · Missing CFBundleIdentifier"
            cleanup_dd
            exit 1
          fi

          echo "DevDock · Installing $BUNDLE…"
          xcrun simctl install "$BOOTED" "$APP"
          xcrun simctl terminate "$BOOTED" "$BUNDLE" >/dev/null 2>&1
          echo "DevDock · Launching…"
          xcrun simctl launch "$BOOTED" "$BUNDLE"
          LAUNCH_STATUS=$?
          if [ $LAUNCH_STATUS -ne 0 ]; then
            echo "DevDock · simctl launch failed ($LAUNCH_STATUS)"
            cleanup_dd
            exit $LAUNCH_STATUS
          fi

          echo "DevDock · Running on Simulator. Press Stop in DevDock to terminate."
          while true; do sleep 30; done
        fi

        echo "DevDock · No iOS Simulator available — trying macOS destination…"
        xcodebuild "$FLAG" "$PROJECT" -scheme "$SCHEME" \\
          -configuration Debug \\
          -destination 'platform=macOS' \\
          -derivedDataPath "$DD" \\
          build
        BUILD_STATUS=$?
        if [ $BUILD_STATUS -ne 0 ]; then
          echo "DevDock · macOS build failed ($BUILD_STATUS). Boot an iPhone Simulator and try again."
          cleanup_dd
          exit $BUILD_STATUS
        fi

        APP="$(find "$DD/Build/Products" -type d -name '*.app' -print -quit 2>/dev/null)"
        if [ -z "$APP" ]; then
          echo "DevDock · No .app produced for macOS."
          cleanup_dd
          exit 1
        fi
        BIN_NAME="$(basename "$APP" .app)"
        BIN="$APP/Contents/MacOS/$BIN_NAME"
        if [ ! -x "$BIN" ]; then
          BIN="$(find "$APP/Contents/MacOS" -type f -perm -111 -print -quit 2>/dev/null)"
        fi
        if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
          echo "DevDock · No macOS executable in $APP"
          cleanup_dd
          exit 1
        fi
        echo "DevDock · Running $BIN"
        trap cleanup_dd EXIT
        exec "$BIN"
        """

        do {
            try body.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptPath
            )
        } catch {
            // Fallback inline if write fails
            return "/bin/bash"
        }
        return scriptPath
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
