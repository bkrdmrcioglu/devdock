import Foundation
import UserNotifications

enum AppNotifier {
    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func ready(projectName: String, port: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(projectName) is ready"
        content.body = "http://localhost:\(port)"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "ready-\(projectName)-\(port)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func idleStopped(projectName: String, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Stopped \(projectName)"
        content.body = "Idle for \(minutes) minutes"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "idle-\(projectName)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
