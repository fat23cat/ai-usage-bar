import Foundation

public struct UsageAlert: Equatable {
    public var provider: AiProviderId
    public var kind: AiMetricKind
    /// The remaining-capacity threshold crossed: 20 or 5.
    public var threshold: UInt8
    public var title: String
    public var body: String
}

/// Turns fresh samples into low-capacity alerts.
///
/// An alert fires once when remaining capacity first falls below 20% and again
/// below 5%. Rising back above a threshold (a reset) re-arms it. The first
/// sample of a metric only sets the baseline, so a launch never repeats alerts
/// for a window that was already low. Stale samples are ignored: they do not
/// describe current usage.
public final class UsageAlertTracker {
    public static let thresholds: [UInt8] = [20, 5]
    private struct Key: Hashable { var provider: AiProviderId; var kind: AiMetricKind }
    private var levels: [Key: Int] = [:]

    public init() {}

    static func level(_ remainingPercent: UInt8) -> Int {
        thresholds.filter { remainingPercent < $0 }.count
    }

    public func update(_ snapshot: AiUsageSnapshot,
                       mode: UsageDisplayMode = .left) -> [UsageAlert] {
        var alerts: [UsageAlert] = []
        for provider in snapshot.providers where provider.freshness == .fresh {
            for metric in provider.metrics {
                let key = Key(provider: provider.provider, kind: metric.kind)
                let level = Self.level(metric.remainingPercent)
                defer { levels[key] = level }
                guard let previous = levels[key], level > previous else { continue }
                let row = UsagePresentation.row(metric, mode: mode)
                let title = "\(UsageFormat.providerName(provider.provider)) " +
                    "\(row.label): \(row.valueText.replacingOccurrences(of: " !", with: ""))"
                let body = row.resetText.map { $0.prefix(1).uppercased() + $0.dropFirst() + "." }
                    ?? "No reset time reported."
                alerts.append(UsageAlert(provider: provider.provider, kind: metric.kind,
                                         threshold: Self.thresholds[level - 1],
                                         title: title, body: body))
            }
        }
        return alerts
    }
}
