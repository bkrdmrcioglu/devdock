import Foundation

/// Kotlin/Android Start: ensure an emulator/device exists, then `installDebug`, keep alive.
enum AndroidKotlinStart {
    static func command(at path: String) -> [String] {
        let gradle: String
        if FileManager.default.isExecutableFile(atPath: (path as NSString).appendingPathComponent("gradlew")) {
            gradle = "./gradlew"
        } else {
            gradle = "gradle"
        }

        // Do NOT launch an AVD here — resolve runs on launch/Rescan/metadata refresh.
        // The run script starts an emulator only when the user actually presses Start.

        let scriptPath = NSTemporaryDirectory() + "devdock-android-\(UUID().uuidString).sh"
        let body = """
        #!/bin/bash
        set +e
        GRADLE=\(shellQuote(gradle))
        export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:$PATH"
        if [ -d "$HOME/Library/Android/sdk" ]; then
          export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
          export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
        fi

        echo "DevDock · Android / Kotlin"

        wait_for_device() {
          for _ in $(seq 1 90); do
            DEV="$(adb devices 2>/dev/null | awk 'NR>1 && $2==\"device\" {print $1; exit}')"
            if [ -n "$DEV" ]; then
              echo "$DEV"
              return 0
            fi
            sleep 2
          done
          return 1
        }

        DEVICE="$(adb devices 2>/dev/null | awk 'NR>1 && $2==\"device\" {print $1; exit}')"
        if [ -z "$DEVICE" ]; then
          AVD="$(emulator -list-avds 2>/dev/null | head -1)"
          if [ -n "$AVD" ] && command -v emulator >/dev/null 2>&1; then
            echo "DevDock · Starting AVD $AVD…"
            emulator -avd "$AVD" -netdelay none -netspeed full >/tmp/devdock-emulator.log 2>&1 &
          else
            echo "DevDock · No Android device/emulator connected."
            echo "DevDock · Create/start one in Android Studio → Device Manager, then Start again."
            exit 1
          fi
          echo "DevDock · Waiting for adb device…"
          DEVICE="$(wait_for_device)"
          if [ -z "$DEVICE" ]; then
            echo "DevDock · Timed out — No connected devices."
            exit 1
          fi
        fi

        echo "DevDock · Installing on $DEVICE…"
        export ANDROID_SERIAL="$DEVICE"
        "$GRADLE" installDebug
        STATUS=$?
        if [ $STATUS -ne 0 ]; then
          echo "DevDock · installDebug failed ($STATUS)"
          exit $STATUS
        fi

        echo "DevDock · Installed on $DEVICE. Press Stop in DevDock when done."
        while true; do sleep 30; done
        """

        do {
            try body.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            return ["/bin/bash", scriptPath]
        } catch {
            return [gradle, "installDebug"]
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
