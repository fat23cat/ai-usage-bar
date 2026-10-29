import SwiftUI
import UsageCore

/// Width of the custom menu rows; standard items size the menu to match.
let menuRowWidth: CGFloat = 300
/// Leading and trailing inset of custom rows, aligned with standard item titles.
let menuContentInset: CGFloat = 16

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

/// Mark, provider name and plan; the trailing text is the sample age or state.
private struct ProviderHeader: View {
    let provider: AiProviderId
    let title: String
    var plan: String?
    var trailing: String = ""
    var trailingColor: Color = Color(nsColor: .tertiaryLabelColor)

    private static let titleCapHeight = NSFont.systemFont(ofSize: 13, weight: .semibold).capHeight

    var body: some View {
        // Texts share one baseline; the mark is centered on the title's capitals.
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            ProviderMarkView(provider: provider)
                .frame(width: 15, height: 15)
                .alignmentGuide(.firstTextBaseline) { $0.height / 2 + Self.titleCapHeight / 2 }
            Text(title).font(.system(size: 13, weight: .semibold))
            if let plan {
                Text(plan).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(trailing)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(trailingColor)
        }
    }
}

/// A provider block inside the menu.
struct ProviderCardView: View {
    let card: UsageProviderCard

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ProviderHeader(provider: card.provider, title: card.title, plan: card.plan,
                           trailing: card.updatedText,
                           trailingColor: card.stale ? Color(nsColor: .systemOrange)
                                                     : Color(nsColor: .tertiaryLabelColor))
            ForEach(card.rows, id: \.kind.rawValue) { MetricRowView(row: $0, stale: card.stale) }
            ForEach(card.details, id: \.self) { detail in
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, menuContentInset)
        .padding(.top, 7)
        .padding(.bottom, 9)
        .frame(width: menuRowWidth, alignment: .leading)
    }
}

/// Checking, empty, Keychain and no-reading states in the same layout.
struct MenuNoticeView: View {
    var provider: AiProviderId?
    let title: String
    let detail: String?
    var showsProgress = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let provider {
                ProviderHeader(provider: provider, title: title)
            } else {
                HStack(spacing: 6) {
                    if showsProgress { ProgressView().controlSize(.small) }
                    Text(title).font(.system(size: 13, weight: .semibold))
                }
            }
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, menuContentInset)
        .padding(.vertical, 7)
        .frame(width: menuRowWidth, alignment: .leading)
    }
}

/// "5-hour  resets in 3h 24m ............ 94% left" over a full-width bar.
struct MetricRowView: View {
    let row: UsageMetricRow
    var stale = false

    /// "94% left !" → ("94%", "left !").
    private var value: (number: String, suffix: String) {
        let parts = row.valueText.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? row.valueText, parts.count > 1 ? parts[1] : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(row.label).font(.system(size: 12, weight: .medium))
                if let reset = row.resetText {
                    Text("  \(reset)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                Text(value.number)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(row.tone == .critical ? row.tone.color : .primary)
                Text(" \(value.suffix)")
                    .font(.system(size: 11))
                    .foregroundStyle(row.tone == .critical ? row.tone.color : .secondary)
            }
            UsageBar(fraction: row.fraction, color: row.tone.color)
                .opacity(stale ? 0.55 : 1)
        }
    }
}

struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.6))
                Capsule().fill(color)
                    .frame(width: max(fraction > 0 ? 4 : 0,
                                      geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 4)
    }
}

/// The provider's monochrome mark, from its installed app or the fallback glyph.
struct ProviderMarkView: View {
    let provider: AiProviderId

    var body: some View {
        if let image = ProviderMark.template(provider) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.primary)
        } else {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.08,
                                                                     dy: size.height * 0.08)
                let path = Path(ProviderGlyph.path(provider, in: rect, yUp: false))
                context.stroke(path, with: .color(.primary),
                               style: StrokeStyle(lineWidth: ProviderGlyph.lineWidth(provider,
                                                                                     rect.width),
                                                  lineCap: .round, lineJoin: .round))
            }
        }
    }
}
