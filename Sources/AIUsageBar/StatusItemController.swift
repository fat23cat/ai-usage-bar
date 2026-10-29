import AppKit
import Combine
import SwiftUI
import UsageCore

/// The menu bar title and the popover under it.
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let store: UsageStore
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var changes: AnyCancellable?

    init(store: UsageStore, openSettings: @escaping () -> Void) {
        self.store = store
        super.init()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        let controller = NSHostingController(rootView: PopoverView(store: store, openSettings: { [weak self] in
            self?.popover.performClose(nil)
            openSettings()
        }))
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.setAccessibilityLabel("AI usage")
        changes = store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateTitle() }
        updateTitle()
    }

    private static func color(_ segment: UsageMenuBarSegment) -> NSColor? {
        switch segment.tone {
        case .critical: return .systemRed
        case .low: return .systemOrange
        case .plenty, .moderate: return segment.stale ? .secondaryLabelColor : nil
        }
    }

    private func updateTitle() {
        guard let button = item.button else { return }
        let segments = UsagePresentation.menuBar(store.snapshot, settings: store.settings)
        guard !segments.isEmpty else {
            button.attributedTitle = NSAttributedString()
            let image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent",
                                accessibilityDescription: "AI usage")
            image?.isTemplate = true
            button.image = image
            return
        }
        button.image = nil
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1,
                                                    weight: .medium)
        let title = NSMutableAttributedString()
        for (index, segment) in segments.enumerated() {
            if index > 0 { title.append(NSAttributedString(string: "  ", attributes: [.font: font])) }
            var attributes: [NSAttributedString.Key: Any] = [.font: font]
            if let color = Self.color(segment) { attributes[.foregroundColor] = color }
            title.append(NSAttributedString(string: segment.text, attributes: attributes))
        }
        button.attributedTitle = title
    }

    @objc private func toggle() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = item.button else { return }
        store.refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
