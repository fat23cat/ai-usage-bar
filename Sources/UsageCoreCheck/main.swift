import Foundation
import UsageCore

var failures = 0
func expect(_ condition: Bool, _ name: String) {
    if !condition {
        fputs("FAIL \(name)\n", stderr)
        failures += 1
    }
}

private func percentMetric(_ kind: AiMetricKind, left: UInt8, resetIn: UInt32 = 7_800,
                           now: UInt32 = 10_000) -> AiUsageMetric {
    AiUsageMetric(kind: kind, unit: .percent, used: UInt32(100 - left), limit: 100,
                  remaining: UInt32(left), remainingPercent: left,
                  resetAt: resetIn == 0 ? 0 : now + resetIn, resetRemainingSeconds: resetIn)
}

private let now = Date(timeIntervalSince1970: 10_000)
private let codexPlus = AiUsageProviderSnapshot(
    provider: .codex, plan: .plus,
    metrics: [percentMetric(.fiveHour, left: 64), percentMetric(.week, left: 81, resetIn: 367_200)],
    resetCredits: AiResetCredits(availableCount: 2, credits: [
        AiResetCredit(title: "FULL RESET", expiresAt: 83_560, expiresRemainingSeconds: 73_560),
        AiResetCredit(title: "FULL RESET", expiresAt: 200_000, expiresRemainingSeconds: 190_000),
    ]),
    sampledAt: 9_988)
private let claudeMax = AiUsageProviderSnapshot(
    provider: .claude, plan: .max, freshness: .stale,
    metrics: [percentMetric(.fiveHour, left: 35, resetIn: 6_300),
              percentMetric(.week, left: 88, resetIn: 511_200)],
    sampledAt: 9_820)
private let cursorEnterprise = AiUsageProviderSnapshot(
    provider: .cursor, plan: .enterprise,
    metrics: [AiUsageMetric(kind: .money, unit: .cents, used: 245_542, limit: 255_000,
                            remaining: 9_458, remainingPercent: 4, resetAt: 298_000,
                            resetRemainingSeconds: 288_000)],
    sampledAt: 9_940)
private let codexBusiness = AiUsageProviderSnapshot(
    provider: .codex, plan: .business,
    metrics: [AiUsageMetric(kind: .credits, unit: .credits, used: 19_765, limit: 20_000,
                            remaining: 235, remainingPercent: 1, resetAt: 0,
                            resetRemainingSeconds: 0)])

func formatChecks() {
    expect(UsageFormat.duration(7_800) == "2h 10m", "hours and minutes")
    expect(UsageFormat.duration(367_200) == "4d 6h", "days and hours")
    expect(UsageFormat.duration(2_700) == "45m" && UsageFormat.duration(30) == "<1m",
           "short durations")
    expect(UsageFormat.duration(3_600) == "1h" && UsageFormat.duration(172_800) == "2d",
           "whole units drop the zero part")
    expect(UsageFormat.money(cents: 9_458) == "$94.58" &&
           UsageFormat.money(cents: 255_000) == "$2,550.00" &&
           UsageFormat.money(cents: 5) == "$0.05", "money in dollars with cents")
    expect(UsageFormat.credits(19_765) == "19,765" && UsageFormat.credits(235) == "235",
           "credits grouped")
    expect(UsageFormat.age(12) == "12s ago" && UsageFormat.age(180) == "3 min ago" &&
           UsageFormat.age(7_300) == "2h ago", "sample age")
}

func toneChecks() {
    expect(UsageTone(remainingPercent: 100) == .plenty && UsageTone(remainingPercent: 51) == .plenty,
           "51...100 plenty")
    expect(UsageTone(remainingPercent: 50) == .moderate && UsageTone(remainingPercent: 20) == .moderate,
           "20...50 moderate")
    expect(UsageTone(remainingPercent: 19) == .low && UsageTone(remainingPercent: 5) == .low,
           "5...19 low")
    expect(UsageTone(remainingPercent: 4) == .critical && UsageTone(remainingPercent: 0) == .critical,
           "0...4 critical")
}

func rowChecks() {
    let left = UsagePresentation.row(percentMetric(.fiveHour, left: 64), mode: .left)
    expect(left.label == "5-hour" && left.valueText == "64% left" && left.fraction == 0.64 &&
           left.tone == .plenty && left.resetText == "resets in 2h 10m", "remaining row")
    let used = UsagePresentation.row(percentMetric(.fiveHour, left: 64), mode: .used)
    expect(used.valueText == "36% used" && used.fraction == 0.36 && used.tone == .plenty,
           "used row keeps the remaining tone")
    let critical = UsagePresentation.row(percentMetric(.week, left: 3), mode: .used)
    expect(critical.valueText == "97% used !" && critical.tone == .critical,
           "critical rows are marked without color")
    let elapsed = UsagePresentation.row(
        AiUsageMetric(kind: .week, unit: .percent, used: 10, limit: 100, remaining: 90,
                      remainingPercent: 90, resetAt: 9_000, resetRemainingSeconds: 0), mode: .left)
    expect(elapsed.valueText == "90% left" && elapsed.resetText == "awaiting update",
           "a passed reset never claims replenished quota")
    expect(UsagePresentation.row(percentMetric(.week, left: 50, resetIn: 0), mode: .left)
        .resetText == nil, "no reset time, no reset line")
}

func cardChecks() {
    let codex = UsagePresentation.card(codexPlus, mode: .left, now: now)
    expect(codex.title == "Codex" && codex.plan == "ChatGPT Plus" && !codex.stale &&
           codex.updatedText == "12s ago", "Codex card header")
    expect(codex.rows.map(\.valueText) == ["64% left", "81% left"], "Codex rows")
    expect(codex.details == ["2 full resets · next expires in 20h 26m"], "Codex reset details")

    let claude = UsagePresentation.card(claudeMax, mode: .left, now: now)
    expect(claude.plan == "Max" && claude.stale && claude.updatedText == "stale · 3 min ago",
           "stale card says so")

    let cursorLeft = UsagePresentation.card(cursorEnterprise, mode: .left, now: now)
    expect(cursorLeft.rows.first?.label == "Budget" &&
           cursorLeft.rows.first?.valueText == "4% left !" &&
           cursorLeft.details == ["$94.58 of $2,550.00 left"], "Cursor budget left")
    let cursorUsed = UsagePresentation.card(cursorEnterprise, mode: .used, now: now)
    expect(cursorUsed.details == ["$2,455.42 of $2,550.00 used"], "Cursor budget used")

    let business = UsagePresentation.card(codexBusiness, mode: .used, now: now)
    expect(business.plan == "Business" && business.updatedText == "" &&
           business.details == ["19,765 of 20,000 credits used"], "Business credits")

    var mixed = codexPlus
    mixed.resetCredits = AiResetCredits(availableCount: 1, credits: [AiResetCredit(title: "BONUS")])
    expect(UsagePresentation.card(mixed, mode: .left, now: now).details == ["1 reset credit"],
           "other reset credits without expiry")
    mixed.resetCredits = AiResetCredits(availableCount: 0, credits: [])
    expect(UsagePresentation.card(mixed, mode: .left, now: now).details.isEmpty,
           "no reset credits, no line")
}

func popoverChecks() {
    let settings = UsageSettings()
    expect(UsagePresentation.popover(nil, settings: settings, now: now) == .checking,
           "no snapshot yet")
    expect(UsagePresentation.popover(AiUsageSnapshot(state: .discovering), settings: settings,
                                     now: now) == .checking, "first discovery")
    expect(UsagePresentation.popover(AiUsageSnapshot(state: .ready), settings: settings,
                                     now: now) == .empty, "nothing signed in")
    let snapshot = AiUsageSnapshot(state: .ready,
                                   providers: [codexPlus, cursorEnterprise, claudeMax])
    guard case .cards(let cards, let waiting) =
        UsagePresentation.popover(snapshot, settings: settings, now: now) else {
        return expect(false, "cards for signed-in providers")
    }
    expect(cards.map(\.provider) == [.codex, .claude, .cursor] && waiting.isEmpty,
           "cards follow the configured order")
    let prompt = AiUsageSnapshot(state: .discovering, providers: [], waiting: [.claude])
    expect(UsagePresentation.popover(prompt, settings: settings, now: now) ==
           .cards([], waiting: [.claude]), "a Keychain prompt is shown, not a spinner")
    let answered = AiUsageSnapshot(state: .ready, providers: [claudeMax], waiting: [.claude])
    guard case .cards(_, let none) =
        UsagePresentation.popover(answered, settings: settings, now: now) else {
        return expect(false, "cards while a recheck waits")
    }
    expect(none.isEmpty, "a provider with a sample is not listed as waiting")
}

func menuBarChecks() {
    var settings = UsageSettings()
    let snapshot = AiUsageSnapshot(state: .ready,
                                   providers: [codexPlus, cursorEnterprise, claudeMax])
    let segments = UsagePresentation.menuBar(snapshot, settings: settings)
    expect(segments.map(\.text) == ["Cx 64·81", "Cl 35·88", "Cu 4"], "menu bar segments")
    expect(segments.map(\.tone) == [.plenty, .moderate, .critical] &&
           segments.map(\.stale) == [false, true, false], "segment tone and staleness")
    settings.displayMode = .used
    settings.hiddenInMenuBar = [.cursor]
    settings.providerOrder = [.claude, .cursor, .codex]
    expect(UsagePresentation.menuBar(snapshot, settings: settings).map(\.text) ==
           ["Cl 65·12", "Cx 36·19"], "used mode, hidden provider and order")
    expect(UsagePresentation.menuBar(nil, settings: settings).isEmpty, "nothing to show yet")
}

func settingsChecks() {
    let defaults = UsageSettings()
    expect(defaults.displayMode == .left && defaults.providerOrder == [.codex, .claude, .cursor] &&
           defaults.hiddenInMenuBar.isEmpty && defaults.notificationsEnabled, "defaults")
    var changed = defaults
    changed.displayMode = .used
    changed.hiddenInMenuBar = [.codex]
    changed.notificationsEnabled = false
    changed.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
    expect(changed.providerOrder == [.cursor, .codex, .claude], "move to the top")
    changed.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
    expect(changed.providerOrder == [.codex, .claude, .cursor], "move to the bottom")
    expect(UsageSettings.decoded(changed.encoded()) == changed, "settings round trip")
    expect(UsageSettings.decoded(nil) == defaults &&
           UsageSettings.decoded(Data("garbage".utf8)) == defaults, "unreadable settings reset")
    let partial = Data(#"{"displayMode":"used","providerOrder":[3,3]}"#.utf8)
    let decoded = UsageSettings.decoded(partial)
    expect(decoded.displayMode == .used && decoded.providerOrder == [.claude, .codex, .cursor] &&
           decoded.notificationsEnabled, "partial settings keep defaults and every provider")
}

func alertChecks() {
    func snapshot(left: UInt8, freshness: AiFreshness = .fresh) -> AiUsageSnapshot {
        AiUsageSnapshot(state: .ready, providers: [AiUsageProviderSnapshot(
            provider: .claude, plan: .max, freshness: freshness,
            metrics: [percentMetric(.fiveHour, left: left, resetIn: 2_280)])])
    }
    let tracker = UsageAlertTracker()
    expect(tracker.update(snapshot(left: 3)).isEmpty, "the first sample is a baseline")
    expect(tracker.update(snapshot(left: 2)).isEmpty, "no repeat inside a band")
    expect(tracker.update(snapshot(left: 90)).isEmpty, "a reset re-arms quietly")
    let low = tracker.update(snapshot(left: 19))
    expect(low.map(\.threshold) == [20] && low.first?.title == "Claude 5-hour: 19% left" &&
           low.first?.body == "Resets in 38m.", "below 20%")
    expect(tracker.update(snapshot(left: 4, freshness: .stale)).isEmpty, "stale samples ignored")
    let critical = tracker.update(snapshot(left: 4))
    expect(critical.map(\.threshold) == [5] && critical.first?.title == "Claude 5-hour: 4% left",
           "below 5% drops the ! mark from the title")
    expect(tracker.update(snapshot(left: 1)).isEmpty, "one alert per threshold")
    let jump = UsageAlertTracker()
    _ = jump.update(snapshot(left: 60))
    expect(jump.update(snapshot(left: 2), mode: .used).map(\.title) == ["Claude 5-hour: 98% used"],
           "a drop past both thresholds alerts once, in the chosen mode")
}

normalizationChecks()
formatChecks()
toneChecks()
rowChecks()
cardChecks()
popoverChecks()
menuBarChecks()
settingsChecks()
alertChecks()
if failures > 0 { exit(1) }
print("core checks passed")
