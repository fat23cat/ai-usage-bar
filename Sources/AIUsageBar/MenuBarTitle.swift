import AppKit
import UsageCore

/// Simple one-color marks that echo each provider's logo at menu bar size:
/// a three-loop knot for Codex, a ray burst for Claude, a cube for Cursor.
/// They are drawn here and stay plain shapes, not copies of the logos.
enum ProviderGlyph {
    static func lineWidth(_ provider: AiProviderId, _ side: CGFloat) -> CGFloat {
        switch provider {
        case .codex: return max(1.1, side / 12)
        case .claude: return max(1.4, side / 8.5)
        case .cursor: return max(1.2, side / 10.5)
        }
    }

    /// `yUp` is true for AppKit's unflipped drawing and false for SwiftUI.
    static func path(_ provider: AiProviderId, in rect: CGRect, yUp: Bool = true) -> CGPath {
        let inset = lineWidth(provider, rect.width) / 2 + 0.25
        let box = rect.insetBy(dx: inset, dy: inset)
        let center = CGPoint(x: box.midX, y: box.midY)
        let radius = min(box.width, box.height) / 2
        let up: CGFloat = yUp ? 1 : -1
        func point(_ degrees: CGFloat, _ distance: CGFloat) -> CGPoint {
            let angle = degrees * .pi / 180
            return CGPoint(x: center.x + distance * cos(angle),
                           y: center.y + up * distance * sin(angle))
        }
        let path = CGMutablePath()
        switch provider {
        case .codex:
            // Three stadiums at 60° steps overlap into a six-lobed knot.
            let length = radius * 1.9, thickness = radius * 0.78
            let stadium = CGRect(x: -length / 2, y: -thickness / 2,
                                 width: length, height: thickness)
            for index in 0..<3 {
                var transform = CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: CGFloat(index) * .pi / 3 + .pi / 6)
                path.addPath(CGPath(roundedRect: stadium, cornerWidth: thickness / 2,
                                    cornerHeight: thickness / 2, transform: &transform))
            }
        case .claude:
            // Uneven rays around a small open center, like a hand-drawn spark.
            let lengths: [CGFloat] = [1, 0.78, 0.94, 0.72, 0.98, 0.8, 0.9, 0.74, 1, 0.84]
            for (index, length) in lengths.enumerated() {
                let degrees = CGFloat(index) * 36 + 90
                path.move(to: point(degrees, radius * 0.22))
                path.addLine(to: point(degrees, radius * length))
            }
        case .cursor:
            // A pointy-top hexagon with the three inner edges of a cube.
            let corners = (0..<6).map { point(CGFloat($0) * 60 + 90, radius) }
            path.addLines(between: corners)
            path.closeSubpath()
            for degrees in [-90, 30, 150] as [CGFloat] {
                path.move(to: center)
                path.addLine(to: point(degrees, radius))
            }
        }
        return path
    }
}

/// Draws the T2 title: per provider a glyph, the first limit large and the
/// second as a small raised index, for example "⬡64⁸¹ ✳35⁸⁸ △4".
enum MenuBarTitle {
    private static let height: CGFloat = 18
    private static let glyphSide: CGFloat = 15
    private static let primaryFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
    private static let secondaryFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)

    private static func color(_ tone: UsageTone?, stale: Bool, secondary: Bool) -> NSColor {
        switch tone {
        case .low?, .critical?: return .systemRed
        default: return stale || secondary ? .secondaryLabelColor : .labelColor
        }
    }

    private static func strings(_ segment: UsageMenuBarSegment)
        -> (NSAttributedString, NSAttributedString?) {
        let primary = NSAttributedString(string: segment.primary, attributes: [
            .font: primaryFont,
            .foregroundColor: color(segment.primaryTone, stale: segment.stale, secondary: false),
        ])
        let secondary = segment.secondary.map {
            NSAttributedString(string: $0, attributes: [
                .font: secondaryFont,
                .foregroundColor: color(segment.secondaryTone, stale: segment.stale,
                                        secondary: true),
            ])
        }
        return (primary, secondary)
    }

    /// Draws at display time in `appearance`, so text and glyph colors follow
    /// the menu bar, which can be dark on a light system and vice versa.
    static func image(_ segments: [UsageMenuBarSegment],
                      appearance: @escaping () -> NSAppearance?) -> NSImage {
        let parts = segments.map { (segment: $0, strings: strings($0)) }
        let widths = parts.map { part -> CGFloat in
            glyphSide + 3 + ceil(part.strings.0.size().width) +
                (part.strings.1.map { 1 + ceil($0.size().width) } ?? 0)
        }
        let spacing: CGFloat = 9
        let width = widths.reduce(0, +) + spacing * CGFloat(max(0, parts.count - 1))
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let draw = {
                var x: CGFloat = 0
                for (index, part) in parts.enumerated() {
                    let glyphRect = CGRect(x: x, y: (height - glyphSide) / 2,
                                           width: glyphSide, height: glyphSide)
                    ProviderMark.draw(part.segment.provider, in: glyphRect,
                                      color: part.segment.stale
                                          ? .secondaryLabelColor : .labelColor)
                    var textX = x + glyphSide + 3
                    let primarySize = part.strings.0.size()
                    let baseline = (height - primarySize.height) / 2
                    part.strings.0.draw(at: CGPoint(x: textX, y: baseline))
                    textX += ceil(primarySize.width) + 1
                    if let secondary = part.strings.1 {
                        // Raise the index so its top sits just above the digits' top.
                        let raise = primaryFont.capHeight - secondaryFont.capHeight + 1.5
                        secondary.draw(at: CGPoint(
                            x: textX, y: baseline - primaryFont.descender + secondaryFont.descender
                                + raise))
                    }
                    x += widths[index] + spacing
                }
            }
            if let appearance = appearance() {
                appearance.performAsCurrentDrawingAppearance(draw)
            } else {
                draw()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// The app mark (three remaining-capacity bars) for when nothing can be shown.
    static func placeholder() -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { _ in
            NSColor.black.setFill()
            for (row, length) in [(0, 1.0), (1, 0.65), (2, 0.35)] as [(CGFloat, CGFloat)] {
                let rect = NSRect(x: 1, y: 11 - row * 4.5, width: 14 * length, height: 3)
                NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "AI usage"
        return image
    }
}
