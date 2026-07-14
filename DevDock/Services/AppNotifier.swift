import Foundation
import AppKit
import UserNotifications

enum AppNotifier {
    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func ready(projectName: String, port: Int) {
        post(title: "\(projectName) is ready", body: "http://localhost:\(port)", idPrefix: "ready-\(projectName)-\(port)")
    }

    static func idleStopped(projectName: String, minutes: Int) {
        post(title: "Stopped \(projectName)", body: "Idle for \(minutes) minutes", idPrefix: "idle-\(projectName)")
    }

    private static func post(title: String, body: String, idPrefix: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let attachment = iconAttachment() {
            content.attachments = [attachment]
        }
        let request = UNNotificationRequest(
            identifier: "\(idPrefix)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private static func iconAttachment() -> UNNotificationAttachment? {
        let image = BrandMark.resolvedImage
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("devdock-notify-\(UUID().uuidString).png")
        do {
            try png.write(to: url)
            return try UNNotificationAttachment(identifier: "logo", url: url, options: nil)
        } catch {
            return nil
        }
    }
}
