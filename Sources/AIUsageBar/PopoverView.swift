import SwiftUI
import UsageCore

extension UsageTone {
    /// The Cardputer palette: Leaf, Blue, Vermilion.
    var color: Color {
        switch self {
        case .plenty: return Color(nsColor: .systemGreen)
        case .moderate: return Color(nsColor: .systemBlue)
        case .low, .critical: return Color(nsColor: .systemRed)
        }
    }
}

struct PopoverView: View {
    @ObservedObject var store: UsageStore
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
            HStack {
                Button { store.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .keyboardShortcut("r")
                Spacer()
                Button { openSettings() } label: { Label("Settings…", systemImage: "gearshape") }
                    .keyboardShortcut(",")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.system(size: 12))
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(10)
        .frame(width: 320)
    }

    @ViewBuilder private var content: some View {
        switch UsagePresentation.popover(store.snapshot, settings: store.settings, now: store.now) {
        case .checking:
            Notice {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Checking AI providers…")
                }
            }
        case .empty:
            Notice {
                Text("No AI providers found").font(.system(size: 13, weight: .medium))
                Text("Sign in to Codex, Cursor, or Claude Code on this Mac.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .cards(let cards, let waiting):
            ForEach(cards, id: \.provider) { ProviderCardView(card: $0) }
            ForEach(waiting, id: \.self) { provider in
                Notice {
                    Text(UsageFormat.providerName(provider)).font(.system(size: 13, weight: .medium))
                    Text("Waiting for Keychain access. Choose Always Allow in the macOS prompt.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct Notice<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 3) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(CardBackground())
    }
}

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75)))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

struct ProviderCardView: View {
    let card: UsageProviderCard

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.title).font(.system(size: 13, weight: .semibold))
                if let plan = card.plan {
                    Text("· \(plan)").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(card.updatedText)
                    .font(.system(size: 11))
                    .foregroundStyle(card.stale ? Color(nsColor: .systemOrange) : .secondary)
            }
            ForEach(card.rows, id: \.kind.rawValue) { MetricRowView(row: $0) }
            ForEach(card.details, id: \.self) { detail in
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35)))
                    .padding(.top, 2)
            }
        }
        .modifier(CardBackground())
        .opacity(card.stale ? 0.85 : 1)
    }
}

struct MetricRowView: View {
    let row: UsageMetricRow

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 8) {
                Text(row.label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                UsageBar(fraction: row.fraction, color: row.tone.color)
                Text(row.valueText)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(row.tone == .critical ? row.tone.color : .primary)
                    .frame(width: 78, alignment: .trailing)
            }
            if let reset = row.resetText {
                Text(reset)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 58)
            }
        }
        .padding(.vertical, 1)
    }
}

struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(nsColor: .quaternaryLabelColor))
                Capsule().fill(color)
                    .frame(width: max(fraction > 0 ? 3 : 0,
                                      geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 5)
    }
}
