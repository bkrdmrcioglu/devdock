import Foundation

/// Versioned changelog. Newest release first — bump `contentID` when adding a release.
enum WhatsNew {
    /// Change when returning users should see the sheet again (usually = latest version).
    static let contentID = "0.2.4-versioned-changelog"

    private static let seenKey = "devdock.whatsNew.seenID"

    static var shouldPresent: Bool {
        UserDefaults.standard.string(forKey: seenKey) != contentID
    }

    static func markSeen() {
        UserDefaults.standard.set(contentID, forKey: seenKey)
    }

    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let systemImage: String
    }

    struct Release: Identifiable {
        var id: String { version }
        let version: String
        let items: [Item]
    }

    /// Full history, newest → oldest. Add a new `Release` block at the top each ship.
    static let releases: [Release] = [
        Release(version: "0.2.4", items: [
            Item(
                title: "Update check",
                detail: "Shows when a newer release is out. Tap Update → Homebrew upgrade → app relaunches.",
                systemImage: "arrow.down.circle"
            ),
            Item(
                title: "Expo vs Kotlin",
                detail: "Expo/React Native stay one project — nested android/ios shells are not separate apps.",
                systemImage: "shippingbox"
            ),
            Item(
                title: "Free plan",
                detail: "Debug builds no longer auto-unlock Pro. Activate a Lemon key for unlimited projects.",
                systemImage: "person.crop.circle"
            ),
        ]),
        Release(version: "0.2.3", items: [
            Item(
                title: "Port panel",
                detail: "See who holds localhost:port (name + pid + command) and Kill in one tap.",
                systemImage: "network"
            ),
            Item(
                title: "Missing dependencies",
                detail: "Warns for node_modules / flutter pub get / composer / bundle — with a Fix button.",
                systemImage: "shippingbox"
            ),
            Item(
                title: "Ready notifications",
                detail: "Optional macOS alert when your stack answers HTTP.",
                systemImage: "bell"
            ),
            Item(
                title: "Morning on launch + idle stop",
                detail: "Start your morning routine when DevDock opens, and auto-stop quiet stacks.",
                systemImage: "sun.max"
            ),
        ]),
        Release(version: "0.2.0", items: [
            Item(
                title: "First public build",
                detail: "Scan folders, start/stop stacks, workspaces, menu bar, and Homebrew cask.",
                systemImage: "shippingbox.and.arrow.backward"
            ),
        ]),
    ]
}
