import AppKit
import UsageCore

/// The provider's own monochrome menu bar icon, read at run time from its
/// installed app (the repository ships no provider artwork). Without the app,
/// `ProviderGlyph` draws a plain fallback.
enum ProviderMark {
    private static let sources: [AiProviderId: (bundleIds: [String], names: [String])] = [
        .codex: (["com.openai.codex", "com.openai.chat"], ["chatgptTemplate"]),
        .claude: (["com.anthropic.claudefordesktop"], ["TrayIconTemplate"]),
        .cursor: (["com.todesktop.230313mzl4w4u92"], ["TrayIconTemplate", "trayIconTemplate"]),
    ]
    private static var cache: [AiProviderId: NSImage] = [:]
    private static var missing: Set<AiProviderId> = []

    /// A template image, or nil when the provider's app is not installed.
    /// Main thread only.
    static func template(_ provider: AiProviderId) -> NSImage? {
        if let cached = cache[provider] { return cached }
        if missing.contains(provider) { return nil }
        guard let source = sources[provider] else { return nil }
        for id in source.bundleIds {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id),
                  let bundle = Bundle(url: url) else { continue }
            for name in source.names {
                guard let image = bundle.image(forResource: name) else { continue }
                image.isTemplate = true
                cache[provider] = image
                return image
            }
        }
        missing.insert(provider)
        return nil
    }

    /// Draws the mark into `rect` of the current AppKit context in `color`.
    static func draw(_ provider: AiProviderId, in rect: CGRect, color: NSColor) {
        if let image = template(provider) {
            let tinted = NSImage(size: rect.size, flipped: false) { bounds in
                image.draw(in: bounds)
                color.set()
                bounds.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: rect)
            return
        }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let glyph = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)
        context.saveGState()
        context.addPath(ProviderGlyph.path(provider, in: glyph))
        context.setLineWidth(ProviderGlyph.lineWidth(provider, glyph.width))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(color.cgColor)
        context.strokePath()
        context.restoreGState()
    }
}
