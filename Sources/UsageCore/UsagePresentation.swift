import Foundation

/// Remaining-capacity bands shared with the Cardputer AI USAGE app.
/// The tone always follows what is left, whichever display mode is chosen.
public enum UsageTone: Equatable {
    case plenty    // 51...100% left
    case moderate  // 20...50% left
    case low       // 5...19% left
    case critical  // 0...4% left, also marked with "!"

    public init(remainingPercent: UInt8) {
        switch remainingPercent {
        case 51...: self = .plenty
        case 20...: self = .moderate
        case 5...: self = .low
        default: self = .critical
        }
    }
}

public struct UsageMetricRow: Equatable {
    public var kind: AiMetricKind
    public var label: String
    /// Bar length in 0...1 for the current display mode.
    public var fraction: Double
    public var valueText: String
    public var tone: UsageTone
    public var resetText: String?
}

public struct UsageProviderCard: Equatable {
    public var provider: AiProviderId
    public var title: String
    public var plan: String?
    public var stale: Bool
    public var updatedText: String
    public var rows: [UsageMetricRow]
    public var details: [String]
}

public enum UsagePopoverContent: Equatable {
    /// The first discovery is still running and nothing can be shown yet.
    case checking
    /// Discovery finished without a signed-in provider.
    case empty
    case cards([UsageProviderCard], waiting: [AiProviderId])
}

public struct UsageMenuBarSegment: Equatable {
    public var provider: AiProviderId
    /// For example "Cx 64·81".
    public var text: String
    public var tone: UsageTone
    public var stale: Bool
}

public enum UsageFormat {
    public static func providerName(_ provider: AiProviderId) -> String {
        switch provider {
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .claude: return "Claude"
        }
    }

    public static func abbreviation(_ provider: AiProviderId) -> String {
        switch provider {
        case .codex: return "Cx"
        case .cursor: return "Cu"
        case .claude: return "Cl"
        }
    }

    public static func planName(_ provider: AiProviderId, _ plan: AiPlan) -> String? {
        switch plan {
        case .unknown: return nil
        case .plus: return provider == .codex ? "ChatGPT Plus" : "Plus"
        case .business: return "Business"
        case .enterprise: return "Enterprise"
        case .pro: return "Pro"
        case .max: return "Max"
        }
    }

    public static func metricLabel(_ kind: AiMetricKind) -> String {
        switch kind {
        case .fiveHour: return "5-hour"
        case .week: return "Week"
        case .credits: return "Credits"
        case .money: return "Budget"
        }
    }

    /// "2h 10m", "4d 6h", "45m", "<1m".
    public static func duration(_ seconds: UInt32) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 1 { return "<1m" }
        let days = minutes / 1440, hours = minutes / 60 % 24, rest = minutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if minutes >= 60 { return rest > 0 ? "\(minutes / 60)h \(rest)m" : "\(minutes / 60)h" }
        return "\(minutes)m"
    }

    /// "12s ago", "3 min ago", "2h ago".
    public static func age(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        if value < 60 { return "\(value)s ago" }
        if value < 3600 { return "\(value / 60) min ago" }
        return "\(value / 3600)h ago"
    }

    private static func grouped(_ value: UInt64) -> String {
        let digits = Array(String(value))
        var result = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result.append(",") }
            result.append(digit)
        }
        return result
    }

    /// "$94.58", "$2,550.00".
    public static func money(cents: UInt32) -> String {
        let value = UInt64(cents)
        let fraction = value % 100
        return "$\(grouped(value / 100)).\(fraction < 10 ? "0" : "")\(fraction)"
    }

    public static func credits(_ value: UInt32) -> String { grouped(UInt64(value)) }

    static func shownPercent(_ metric: AiUsageMetric, _ mode: UsageDisplayMode) -> UInt8 {
        mode == .left ? metric.remainingPercent : 100 - metric.remainingPercent
    }
}

public enum UsagePresentation {
    public static func row(_ metric: AiUsageMetric, mode: UsageDisplayMode) -> UsageMetricRow {
        let tone = UsageTone(remainingPercent: metric.remainingPercent)
        let percent = UsageFormat.shownPercent(metric, mode)
        var value = "\(percent)% \(mode == .left ? "left" : "used")"
        if tone == .critical { value += " !" }
        let reset: String?
        if metric.resetAt == 0 {
            reset = nil
        } else if metric.resetRemainingSeconds == 0 {
            // A passed deadline does not show that usage was replenished.
            reset = "awaiting update"
        } else {
            reset = "resets in \(UsageFormat.duration(metric.resetRemainingSeconds))"
        }
        return UsageMetricRow(kind: metric.kind, label: UsageFormat.metricLabel(metric.kind),
                              fraction: Double(percent) / 100, valueText: value, tone: tone,
                              resetText: reset)
    }

    static func details(_ provider: AiUsageProviderSnapshot, mode: UsageDisplayMode) -> [String] {
        var lines: [String] = []
        for metric in provider.metrics where metric.limit > 0 {
            let used = min(metric.used, metric.limit)
            switch metric.unit {
            case .cents:
                lines.append(mode == .left
                    ? "\(UsageFormat.money(cents: metric.remaining)) of \(UsageFormat.money(cents: metric.limit)) left"
                    : "\(UsageFormat.money(cents: used)) of \(UsageFormat.money(cents: metric.limit)) used")
            case .credits:
                lines.append(mode == .left
                    ? "\(UsageFormat.credits(metric.remaining)) of \(UsageFormat.credits(metric.limit)) credits left"
                    : "\(UsageFormat.credits(used)) of \(UsageFormat.credits(metric.limit)) credits used")
            case .percent:
                break
            }
        }
        if let resets = provider.resetCredits, resets.availableCount > 0 {
            let count = Int(resets.availableCount)
            let allFull = !resets.credits.isEmpty &&
                resets.credits.allSatisfy { $0.title == "FULL RESET" }
            var line = allFull
                ? "\(count) full reset\(count == 1 ? "" : "s")"
                : "\(count) reset credit\(count == 1 ? "" : "s")"
            if let next = resets.credits.first(where: { $0.expiresAt != 0 }) {
                line += next.expiresRemainingSeconds == 0
                    ? " · next has expired"
                    : " · next expires in \(UsageFormat.duration(next.expiresRemainingSeconds))"
            }
            lines.append(line)
        }
        return lines
    }

    public static func card(_ provider: AiUsageProviderSnapshot, mode: UsageDisplayMode,
                            now: Date) -> UsageProviderCard {
        let stale = provider.freshness == .stale
        let updated: String
        if provider.sampledAt == 0 {
            updated = stale ? "stale" : ""
        } else {
            let age = UsageFormat.age(now.timeIntervalSince1970 - Double(provider.sampledAt))
            updated = stale ? "stale · \(age)" : age
        }
        return UsageProviderCard(provider: provider.provider,
                                 title: UsageFormat.providerName(provider.provider),
                                 plan: UsageFormat.planName(provider.provider, provider.plan),
                                 stale: stale, updatedText: updated,
                                 rows: provider.metrics.map { row($0, mode: mode) },
                                 details: details(provider, mode: mode))
    }

    public static func popover(_ snapshot: AiUsageSnapshot?, settings: UsageSettings,
                               now: Date) -> UsagePopoverContent {
        guard let snapshot else { return .checking }
        let waiting = settings.ordered(
            snapshot.waiting.filter { id in !snapshot.providers.contains { $0.provider == id } },
            by: { $0 })
        if snapshot.providers.isEmpty && waiting.isEmpty {
            return snapshot.state == .discovering ? .checking : .empty
        }
        let cards = settings.ordered(snapshot.providers, by: \.provider)
            .map { card($0, mode: settings.displayMode, now: now) }
        return .cards(cards, waiting: waiting)
    }

    /// One segment per visible provider; empty when nothing can be shown.
    public static func menuBar(_ snapshot: AiUsageSnapshot?,
                               settings: UsageSettings) -> [UsageMenuBarSegment] {
        guard let snapshot else { return [] }
        return settings.ordered(snapshot.providers, by: \.provider)
            .filter { !settings.hiddenInMenuBar.contains($0.provider) && !$0.metrics.isEmpty }
            .map { provider in
                let values = provider.metrics
                    .map { String(UsageFormat.shownPercent($0, settings.displayMode)) }
                let worst = provider.metrics.map(\.remainingPercent).min() ?? 100
                return UsageMenuBarSegment(
                    provider: provider.provider,
                    text: "\(UsageFormat.abbreviation(provider.provider)) " +
                        values.joined(separator: "·"),
                    tone: UsageTone(remainingPercent: worst),
                    stale: provider.freshness == .stale)
            }
    }
}
