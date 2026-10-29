import Foundation

public enum AiUsageState: UInt8 { case discovering = 1, ready = 2 }
public extension AiUsageState {
    static func forCache(pending: Int, hasUsableProvider: Bool) -> AiUsageState {
        pending == 0 || hasUsableProvider ? .ready : .discovering
    }
}
public enum AiProviderId: UInt8, CaseIterable, Codable { case codex = 1, cursor = 2, claude = 3 }
public enum AiPlan: UInt8 {
    case unknown = 0, plus = 1, business = 2, enterprise = 3, pro = 4, max = 5
}
public enum AiFreshness: UInt8 { case fresh = 1, stale = 2 }
public enum AiMetricKind: UInt8 { case fiveHour = 1, week = 2, credits = 3, money = 4 }
public enum AiMetricUnit: UInt8 { case percent = 1, credits = 2, cents = 3 }

public struct AiUsageMetric: Equatable {
    public var kind: AiMetricKind
    public var unit: AiMetricUnit
    public var used: UInt32
    public var limit: UInt32
    public var remaining: UInt32
    public var remainingPercent: UInt8
    public var resetAt: UInt32
    public var resetRemainingSeconds: UInt32

    public init(kind: AiMetricKind, unit: AiMetricUnit, used: UInt32, limit: UInt32,
                remaining: UInt32, remainingPercent: UInt8, resetAt: UInt32,
                resetRemainingSeconds: UInt32) {
        self.kind = kind; self.unit = unit; self.used = used; self.limit = limit
        self.remaining = remaining; self.remainingPercent = remainingPercent
        self.resetAt = resetAt; self.resetRemainingSeconds = resetRemainingSeconds
    }
}

public struct AiResetCredit: Equatable {
    public var title: String
    public var expiresAt: UInt32
    public var expiresRemainingSeconds: UInt32
    public init(title: String, expiresAt: UInt32 = 0, expiresRemainingSeconds: UInt32 = 0) {
        self.title = title; self.expiresAt = expiresAt
        self.expiresRemainingSeconds = expiresRemainingSeconds
    }
}

public struct AiResetCredits: Equatable {
    public var availableCount: UInt8
    public var credits: [AiResetCredit]
    public init(availableCount: UInt8, credits: [AiResetCredit]) {
        self.availableCount = availableCount; self.credits = credits
    }
}

public struct AiUsageProviderSnapshot: Equatable {
    public var provider: AiProviderId
    public var plan: AiPlan
    public var freshness: AiFreshness
    public var metrics: [AiUsageMetric]
    public var resetCredits: AiResetCredits?
    /// When the provider last returned this sample; zero when unknown.
    public var sampledAt: UInt32

    public init(provider: AiProviderId, plan: AiPlan, freshness: AiFreshness = .fresh,
                metrics: [AiUsageMetric], resetCredits: AiResetCredits? = nil,
                sampledAt: UInt32 = 0) {
        self.provider = provider; self.plan = plan; self.freshness = freshness
        self.metrics = metrics; self.resetCredits = resetCredits; self.sampledAt = sampledAt
    }

    /// Recompute countdowns without fabricating a quota recovery.
    /// A reset deadline passing does not establish that usage was replenished;
    /// retain the last observed percentage as historical until a new read.
    public func aged(now: Date) -> AiUsageProviderSnapshot {
        func remaining(until epoch: UInt32) -> UInt32 {
            UInt32(max(0, Double(epoch) - now.timeIntervalSince1970))
        }
        var result = self
        for index in result.metrics.indices {
            let metric = result.metrics[index]
            guard metric.resetAt != 0 else { continue }
            result.metrics[index].resetRemainingSeconds = remaining(until: metric.resetAt)
        }
        if var resets = result.resetCredits {
            for index in resets.credits.indices where resets.credits[index].expiresAt != 0 {
                resets.credits[index].expiresRemainingSeconds =
                    remaining(until: resets.credits[index].expiresAt)
            }
            result.resetCredits = resets
        }
        return result
    }
}

public struct AiUsageSnapshot: Equatable {
    public var generation: UInt32
    public var state: AiUsageState
    public var providers: [AiUsageProviderSnapshot]
    /// Providers whose credential read waits for a Keychain prompt.
    public var waiting: [AiProviderId]

    public init(generation: UInt32 = 0, state: AiUsageState = .discovering,
                providers: [AiUsageProviderSnapshot] = [], waiting: [AiProviderId] = []) {
        self.generation = generation; self.state = state; self.providers = providers
        self.waiting = waiting
    }
}

public protocol AiUsageCollecting: AnyObject {
    func snapshot() -> AiUsageSnapshot?
    /// Starts a provider refresh now, or once after a refresh already running.
    func refresh()
}
