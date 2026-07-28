import Foundation

/// Versioned changelog. Newest release first — bump `contentID` when adding a release.
enum WhatsNew {
    /// Change when returning users should see the sheet again (usually = latest version).
    static let contentID = "1.0.0-launch"

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
        Release(version: "1.0.0", items: [
            Item(
                title: "DevDock is free & open source",
                detail: "Every project and workspace is unlocked for everyone — no Pro plan, no license key. Enjoying DevDock? Buy Me a Coffee in Settings.",
                systemImage: "heart.fill"
            ),
            Item(
                title: "Scan & detect",
                detail: "Find local projects automatically across 36 frameworks — web, mobile, API, and desktop stacks.",
                systemImage: "shippingbox"
            ),
            Item(
                title: "Start / stop, reliably",
                detail: "Run stacks without opening Terminal. Stop kills the full process tree and verifies it actually exited.",
                systemImage: "checkmark.seal"
            ),
            Item(
                title: "Workspaces & menu bar",
                detail: "Launch grouped stacks together, control everything from the menu bar, morning routine on launch.",
                systemImage: "square.stack.3d.up"
            ),
        ]),
    ]
}
