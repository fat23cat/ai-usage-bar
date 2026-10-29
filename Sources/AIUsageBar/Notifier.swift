import Foundation
import UsageCore
import UserNotifications

/// Posts low-capacity alerts. User notifications need a bundled app, so a
/// bare `swift run` build skips them.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func start(requestingAuthorization: Bool) {
        center?.delegate = self
        if requestingAuthorization { requestAuthorization() }
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(_ alerts: [UsageAlert]) {
        guard let center else { return }
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            // One notification per window: a deeper threshold replaces the earlier one.
            let id = "usage.\(alert.provider.rawValue).\(alert.kind.rawValue)"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
        }
    }

    // The app is always "in the foreground" as a menu bar agent; show banners anyway.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
