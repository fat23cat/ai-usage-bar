import UsageCore

enum AiUsageRefreshOutcome: Equatable {
    case sample(AiUsageProviderSnapshot)
    /// The provider is not installed or signed in; omit it.
    case absent
    /// The refresh failed; retry with backoff.
    case failed
    /// The source cannot be read now without anything failing (for example, its
    /// credential owner is not running). Keep any prior sample, marked stale.
    case unavailable
    /// The source waits for the user (a Keychain prompt). Like `unavailable`,
    /// but discovery stays open while nothing else can be shown.
    case waiting
    /// The source is installed but this app may not read its credential: the
    /// user declined the Keychain prompt, or the item was rewritten without
    /// this app's access. Like `unavailable`; `requestAccess()` asks again.
    case accessNeeded

    var sample: AiUsageProviderSnapshot? {
        if case .sample(let value) = self { return value }
        return nil
    }
}

protocol AiUsageProviderRefreshing: AnyObject {
    func refresh(_ done: @escaping (AiUsageRefreshOutcome) -> Void)
    func setRecoveryHandler(_ handler: @escaping () -> Void)
    /// Lets the next refresh show the Keychain prompt again.
    func requestAccess()
    func stop()
}

extension AiUsageProviderRefreshing {
    func setRecoveryHandler(_ handler: @escaping () -> Void) {}
    func requestAccess() {}
}
