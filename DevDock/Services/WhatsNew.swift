import Foundation

/// Simple post-0.2 “What’s new” sheet. Bump `contentID` when shipping a new notes batch.
enum WhatsNew {
    /// Change this when you want returning users to see the sheet again.
    static let contentID = "0.2.4-update-check"

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

    static let items: [Item] = [
        Item(
            title: "Update check",
            detail: "DevDock checks GitHub Releases on launch. Download or copy brew upgrade when a newer zip is out.",
            systemImage: "arrow.down.circle"
        ),
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
    ]
}
