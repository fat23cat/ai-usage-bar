# AI Usage Bar — Agent Instructions

macOS menu bar app showing Codex, Claude and Cursor subscription limits.
`README.md` describes features, providers, build and releases.

* Dependency direction: `AIUsageBar` (UI) → `UsageProviders` → `UsageCore`.
  Keep rules (formatting, tones, ordering, alerts, settings) in `UsageCore`,
  Foundation only, so `UsageCoreCheck` covers them without the UI.
* Providers only read credentials. Never write, refresh or log tokens; an
  expired Claude token is renewed only by running the `claude` CLI
  (`ProcessClaudeTokenRenewer`).
* The Claude usage endpoint rate-limits: keep the two-minute collector
  refresh, at most one Claude request per 110 seconds, and the 429 back-off
  in `ClaudeUsageProvider`.
* For behavior changes, add a failing check first, then the change. Run the
  narrowest check while working (`swift run UsageCoreCheck` or
  `swift run UsageProvidersCheck`) and `make check` once before finishing.
* Update `README.md` when features, settings, providers or the release flow
  change.
