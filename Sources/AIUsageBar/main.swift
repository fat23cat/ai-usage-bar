import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let notifier = Notifier()
    private let loginItem = LoginItem()
    private var statusItem: StatusItemController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.start(requestingAuthorization: store.settings.notificationsEnabled)
        store.onAlerts = { [notifier] in notifier.post($0) }
        statusItem = StatusItemController(store: store) { [weak self] in self?.showSettings() }
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(store: store, loginItem: loginItem) { [notifier] enabled in
                if enabled { notifier.requestAuthorization() }
            }
            let controller = NSHostingController(rootView: view)
            controller.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: controller)
            window.title = "AI Usage Bar Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
