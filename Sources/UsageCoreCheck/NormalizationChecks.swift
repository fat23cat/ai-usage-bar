import Foundation
import UsageCore

/// Normalization checks carried over from Cardputer Companion; the provider
/// payloads are the same.
func normalizationChecks() {
    let displayNow = Date(timeIntervalSince1970: 10_000)
    let plus: [String: Any] = ["rateLimits": ["planType": "plus",
        "primary": ["usedPercent": 80, "windowDurationMins": 10080, "resetsAt": 20000],
        "secondary": ["usedPercent": 37, "windowDurationMins": 300, "resetsAt": 12000]]]
    let plusSample = AiUsageNormalization.codex(plus, now: displayNow)
    expect(plusSample?.metrics.map(\.kind) == [.fiveHour, .week],
           "Codex windows identified by duration")
    expect(plusSample?.metrics.first?.remainingPercent == 63, "Codex shows remaining quota")
    let noCodexBucket: [String: Any] = [
        "rateLimitsByLimitId": ["different": ["limitId": "different"]],
        "rateLimits": plus["rateLimits"]!,
    ]
    expect(AiUsageNormalization.codex(noCodexBucket) == nil,
           "present bucket map never falls back to another product")
    let selectedCodex: [String: Any] = [
        "rateLimitsByLimitId": ["codex": plus["rateLimits"]!],
        "rateLimits": ["limitId": "different"],
    ]
    expect(AiUsageNormalization.codex(selectedCodex)?.metrics.first?.remainingPercent == 63,
           "canonical Codex bucket wins over legacy data")
    let invalidBuckets: [Any] = [[String: Any](), "invalid", ["codex": NSNull()],
                                 ["codex": [Any]()]]
    for buckets in invalidBuckets {
        expect(AiUsageNormalization.codex(["rateLimitsByLimitId": buckets,
                                           "rateLimits": plus["rateLimits"]!]) == nil,
               "malformed authoritative buckets cannot fall back to legacy limits")
    }
    let invalidIds: [Any] = ["different", 42]
    for invalidId in invalidIds {
        var foreign = plus["rateLimits"] as! [String: Any]
        foreign["limitId"] = invalidId
        expect(AiUsageNormalization.codex(["rateLimits": foreign]) == nil &&
               AiUsageNormalization.codex(["rateLimitsByLimitId": ["codex": foreign]]) == nil,
               "foreign or malformed bucket identity is never reported as Codex")
    }
    expect(AiUsageNormalization.codex(["rateLimits": "invalid"]) == nil,
           "malformed legacy limits are rejected")
    expect(AiUsageNormalization.codex(["ordinaryUsageAllowed": false,
                                       "rateLimits": plus["rateLimits"]!]) == nil,
           "backend permission false blocks apparently available quota")
    let permissions: [Any] = [true, NSNull()]
    for permission in permissions {
        expect(AiUsageNormalization.codex(["ordinaryUsageAllowed": permission,
                                           "rateLimits": plus["rateLimits"]!])?.metrics.count == 2,
               "allowed or unknown permission preserves legacy support")
    }
    expect(AiUsageNormalization.codex(["rateLimitsByLimitId": NSNull(),
                                       "rateLimits": plus["rateLimits"]!])?.metrics.count == 2,
           "null bucket map preserves legacy support")
    var foreignLegacy = plus["rateLimits"] as! [String: Any]
    foreignLegacy["limitId"] = "different"
    let unavailableReadings: [[String: Any]] = [
        ["ordinaryUsageAllowed": false, "rateLimits": plus["rateLimits"]!],
        noCodexBucket, ["rateLimitsByLimitId": [String: Any]()],
        ["rateLimitsByLimitId": ["codex": NSNull()]], ["rateLimits": foreignLegacy],
    ]
    for result in unavailableReadings {
        expect(AiUsageNormalization.codexReading(result) == .unavailable,
               "restricted or absent Codex quota is unavailable, not a failure")
    }
    var numericId = plus["rateLimits"] as! [String: Any]
    numericId["limitId"] = 42
    let invalidReadings: [[String: Any]] = [
        ["rateLimitsByLimitId": "invalid"], ["rateLimitsByLimitId": ["codex": [Any]()]],
        ["rateLimits": "invalid"], ["rateLimits": numericId], [:],
    ]
    for result in invalidReadings {
        expect(AiUsageNormalization.codexReading(result) == .invalid,
               "malformed Codex quota stays a retryable failure")
    }
    expect(AiUsageNormalization.codexReading(selectedCodex) ==
           AiUsageNormalization.codex(selectedCodex).map { .sample($0) },
           "readable Codex quota is a sample")
    var plusWithSpend = plus
    var plusLimits = plusWithSpend["rateLimits"] as! [String: Any]
    plusLimits["individualLimit"] = ["limit": 100, "used": 1,
                                     "remainingPercent": 99]
    plusWithSpend["rateLimits"] = plusLimits
    expect(AiUsageNormalization.codex(plusWithSpend)?.metrics.map(\.kind) ==
           [.fiveHour, .week], "Plus rolling limits win over optional spend limit")
    var plusWithResets = plus
    plusWithResets["rateLimitResetCredits"] = ["availableCount": 2, "credits": [
        ["status": "available", "title": "Full reset", "expiresAt": 90000],
        ["status": "used", "title": "Old reset", "expiresAt": 80000],
        ["status": "available", "title": "Later reset", "expiresAt": 120000]]]
    let resetSample = AiUsageNormalization.codex(plusWithResets, now: displayNow)
    expect(resetSample?.resetCredits?.availableCount == 2, "Plus reset count")
    expect(resetSample?.resetCredits?.credits.map(\.title) == ["FULL RESET", "LATER RESET"],
           "Only usable credits, sorted by expiry")
    plusWithResets["rateLimitResetCredits"] = ["availableCount": 0,
                                                 "credits": []]
    expect(AiUsageNormalization.codex(plusWithResets)?.resetCredits?.availableCount == 0,
           "known zero remains known")
    plusWithResets["rateLimitResetCredits"] = ["availableCount": 1, "credits": [
        ["status": "available", "title": "First reset", "expiresAt": 100],
        ["status": "available", "title": "Second reset", "expiresAt": 200]]]
    expect(AiUsageNormalization.codex(plusWithResets)?.resetCredits?.credits.count == 1,
           "details never exceed available count")
    plusWithResets["rateLimitResetCredits"] = ["availableCount": 1, "credits": [
        ["status": "available", "title": "Full reset", "expiresAt": 100]]]
    expect(AiUsageNormalization.codex(plusWithResets)?.resetCredits?.credits.first?.title ==
           "FULL RESET", "short title normalized on Mac")
    plusWithResets["rateLimitResetCredits"] = ["availableCount": 1, "credits": [
        ["status": "available", "title": "Full reset (Weekly + 5 hr)",
         "expiresAt": 100]]]
    expect(AiUsageNormalization.codex(plusWithResets)?.resetCredits?.credits.first?.title ==
           "FULL RESET", "reset detail uses a concise title")
    plusWithResets["rateLimitResetCredits"] = ["availableCount": 1, "credits": [
        ["status": "available", "title": "Additional Codex Rate Limit Reset",
         "expiresAt": 100]]]
    let longTitle = AiUsageNormalization.codex(plusWithResets)?
        .resetCredits?.credits.first?.title
    expect(longTitle?.hasPrefix("ADDITIONAL") == true &&
           longTitle?.hasSuffix("...") == true && (longTitle?.utf8.count ?? 25) <= 24,
           "long ASCII title keeps a bounded prefix")
    plusWithResets["rateLimitResetCredits"] = ["availableCount": 1, "credits": [
        ["status": "available", "title": String(repeating: "é", count: 20),
         "expiresAt": 100]]]
    let unicodeTitle = AiUsageNormalization.codex(plusWithResets)?
        .resetCredits?.credits.first?.title
    expect(unicodeTitle == "RESET CREDIT",
           "title outside the Cardputer font falls back")
    plusWithResets["rateLimitResetCredits"] = ["availableCount": 1, "credits": [
        ["status": "available", "title": "Reset\ncredit", "expiresAt": 100]]]
    expect(AiUsageNormalization.codex(plusWithResets)?.resetCredits?.credits.first?.title ==
           "RESET CREDIT", "control characters in title fall back")
    plusWithResets["rateLimitResetCredits"] = ["availableCount": "bad"]
    let malformedResets = AiUsageNormalization.codex(plusWithResets)
    expect(malformedResets?.metrics.count == 2 && malformedResets?.resetCredits == nil,
           "bad optional reset data keeps Plus limits")
    let business: [String: Any] = ["planType": "business",
        "individualLimit": ["limit": "20000", "used": "19765.35930800438",
                            "remainingPercent": 1, "resetsAt": 1790812800]]
    let businessSample = AiUsageNormalization.codex(business, now: displayNow)
    expect(businessSample?.provider == .codex && businessSample?.plan == .business &&
           businessSample?.metrics.first?.kind == .credits &&
           businessSample?.metrics.first?.limit == 20000 &&
           businessSample?.metrics.first?.used == 19765 &&
           businessSample?.metrics.first?.remaining == 235 &&
           businessSample?.metrics.first?.remainingPercent == 1,
           "real Business numeric strings and fractional credits normalized")
    expect(AiUsageNormalization.codex(["rateLimitsByLimitId": ["codex": business]],
                                      now: displayNow)?
        .metrics == businessSample?.metrics, "canonical Business credits remain supported")
    expect(AiUsageNormalization.codex(["ordinaryUsageAllowed": false,
                                       "rateLimitsByLimitId": ["codex": business]]) == nil,
           "backend permission also blocks Business credits")
    expect(AiUsageNormalization.codex([
        "rateLimitsByLimitId": ["codex": ["planType": "business"]],
        "rateLimits": business, "individualLimit": business["individualLimit"]!,
    ]) == nil, "canonical bucket never borrows legacy or top-level Business credits")
    let overflowingBusiness: [String: Any] = ["planType": "business",
        "individualLimit": ["limit": "4294967295.9", "used": "1",
                            "remainingPercent": 1]]
    expect(AiUsageNormalization.codex(overflowingBusiness) == nil,
           "rounded Business credits cannot overflow UInt32")
    let cursor: [String: Any] = ["membershipType": "enterprise",
        "billingCycleEnd": "2026-10-01T00:00:00Z",
        "individualUsage": ["overall": ["enabled": true, "used": 9458,
                                          "limit": 255000, "remaining": 245542]]]
    let cursorSample = AiUsageNormalization.cursor(cursor, now: displayNow)
    expect(cursorSample?.metrics.first?.unit == .cents &&
           cursorSample?.metrics.first?.remainingPercent == 96,
           "Cursor individual cents normalized")
    var fractionalCursor = cursor
    fractionalCursor["billingCycleEnd"] = "2026-10-01T00:00:00.000Z"
    expect(AiUsageNormalization.cursor(fractionalCursor, now: displayNow)?
        .metrics.first?.resetAt != 0, "Cursor fractional reset timestamp")

    let claude: [String: Any] = [
        "five_hour": ["utilization": 99.0, "resets_at": "1970-01-01T03:00:00.284624+00:00"],
        "seven_day": ["utilization": 99.0, "resets_at": "1970-01-02T00:00:00+00:00"],
        "seven_day_opus": NSNull(),
        "iguana_necktie": ["utilization": 0.0, "limit_dollars": 100],
        "limits": [
            ["kind": "session", "percent": 8, "resets_at": "1970-01-01T03:00:00.284624+00:00",
             "scope": NSNull()],
            ["kind": "weekly_opus", "percent": 50, "resets_at": "1970-01-03T00:00:00Z",
             "scope": "opus"],
            ["kind": "weekly_all", "percent": 1, "resets_at": "1970-01-02T00:00:00+00:00",
             "scope": NSNull()],
        ]]
    let claudeSample = AiUsageNormalization.claude(claude, subscriptionType: "pro",
                                                   now: displayNow)
    expect(claudeSample?.provider == .claude && claudeSample?.plan == .pro,
           "Claude provider and plan")
    expect(claudeSample?.metrics.map(\.kind) == [.fiveHour, .week] &&
           claudeSample?.metrics.map(\.remainingPercent) == [92, 99],
           "Claude limits list wins over legacy windows")
    expect(claudeSample?.metrics.first?.resetAt == 10_800 &&
           claudeSample?.metrics.first?.resetRemainingSeconds == 800,
           "Claude fractional reset timestamp")
    var legacyClaude = claude
    legacyClaude["limits"] = nil
    legacyClaude["five_hour"] = ["utilization": 37.4, "resets_at": "1970-01-01T03:00:00Z"]
    legacyClaude["seven_day"] = NSNull()
    let legacySample = AiUsageNormalization.claude(legacyClaude, subscriptionType: "max",
                                                   now: displayNow)
    expect(legacySample?.plan == .max && legacySample?.metrics.map(\.kind) == [.fiveHour] &&
           legacySample?.metrics.first?.remainingPercent == 63,
           "Claude legacy five-hour fallback")
    expect(AiUsageNormalization.claude(["limits": []], subscriptionType: "pro") == nil,
           "Claude without rolling windows is not a sample")
    expect(AiUsageNormalization.claude(claude, subscriptionType: "team")?.plan == .unknown,
           "Claude unknown subscription keeps the account")
    var elapsed = claudeSample!
    elapsed.freshness = .stale
    let reset = elapsed.aged(now: Date(timeIntervalSince1970: 20_000))
    expect(reset.metrics.first?.remainingPercent == elapsed.metrics.first?.remainingPercent &&
           reset.metrics.first?.used == elapsed.metrics.first?.used &&
           reset.metrics.first?.resetAt == elapsed.metrics.first?.resetAt &&
           reset.metrics.first?.resetRemainingSeconds == 0,
           "elapsed stale window keeps its last observation until a new read")
    let expiredWeek = elapsed.aged(now: Date(timeIntervalSince1970: 100_000))
    expect(expiredWeek.metrics.map(\.remainingPercent) == elapsed.metrics.map(\.remainingPercent) &&
           expiredWeek.metrics.allSatisfy { $0.resetRemainingSeconds == 0 },
           "both expired Claude windows retain historical quota")
    expect(reset.metrics.last?.remainingPercent == elapsed.metrics.last?.remainingPercent &&
           reset.metrics.last?.resetRemainingSeconds == 86_400 - 20_000,
           "pending window keeps usage and recounts its reset")
    let agedCursor = cursorSample!.aged(now: Date(timeIntervalSince1970: 4_000_000_000))
    expect(agedCursor.metrics.first?.remainingPercent == 96 &&
           agedCursor.metrics.first?.resetRemainingSeconds == 0,
           "spend metrics are not rolling windows")
    let agedResets = resetSample!.aged(now: Date(timeIntervalSince1970: 30_000))
    expect(agedResets.resetCredits?.credits.first?.expiresRemainingSeconds == 60_000,
           "reset-credit expiry recounts")
}
