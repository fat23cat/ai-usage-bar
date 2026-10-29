import Combine
import Foundation
import UsageCore
import UsageProviders

/// Main-thread state for the menu bar title, the menu and Settings.
final class UsageStore: ObservableObject {
    private static let settingsKey = "settings"
    /// Countdowns and sample ages are shown in minutes, and the collector marks
    /// samples stale after three and a half minutes; this keeps both current
    /// between changes.
    private static let tickInterval: TimeInterval = 15

    @Published private(set) var snapshot: AiUsageSnapshot?
    @Published private(set) var now = Date()
    @Published var settings: UsageSettings {
        didSet {
            guard settings != oldValue else { return }
            defaults.set(settings.encoded(), forKey: Self.settingsKey)
        }
    }
    /// Receives low-capacity alerts while notifications are enabled.
    var onAlerts: (([UsageAlert]) -> Void)?

    private let collector: AiUsageCollector
    private let defaults: UserDefaults
    private let alerts = UsageAlertTracker()
    private var timer: Timer?

    init(collector: AiUsageCollector = AiUsageCollector(), defaults: UserDefaults = .standard) {
        self.collector = collector
        self.defaults = defaults
        settings = UsageSettings.decoded(defaults.data(forKey: Self.settingsKey))
    }

    func start() {
        collector.onChange = { [weak self] in
            DispatchQueue.main.async { self?.pull() }
        }
        collector.start()
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.pull()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        pull()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        collector.onChange = nil
        collector.stop()
    }

    func refresh() {
        collector.refresh()
        pull()
    }

    /// Shows the provider's Keychain prompt again.
    func requestAccess(_ provider: AiProviderId) {
        collector.requestAccess(provider)
    }

    private func pull() {
        now = Date()
        let next = collector.snapshot()
        guard next != snapshot else { return }
        snapshot = next
        guard let next else { return }
        // The tracker always sees fresh samples, so enabling notifications
        // later never reports a drop that happened while they were off.
        let fired = alerts.update(next, mode: settings.displayMode)
        if settings.notificationsEnabled && !fired.isEmpty { onAlerts?(fired) }
    }
}
