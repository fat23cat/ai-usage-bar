import AppKit
import Combine
import SwiftUI
import UsageCore

/// Owns the status item and its menu, like Cardputer Companion: provider
/// blocks are custom views; Refresh, Settings and Quit are standard items, so
/// highlight, shortcuts and keyboard navigation come from AppKit.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let store: UsageStore
    private let loginItem: LoginItem
    private let openSettings: () -> Void
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let loginRow = SwitchMenuRowView(title: "Launch at Login")
    private var contentItems: [NSMenuItem] = []
    private var lastContent: UsageMenuContent?
    private var changes: AnyCancellable?
    private var isOpen = false

    init(store: UsageStore, loginItem: LoginItem, openSettings: @escaping () -> Void) {
        self.store = store
        self.loginItem = loginItem
        self.openSettings = openSettings
        super.init()

        menu.autoenablesItems = false
        menu.showsStateColumn = false
        menu.delegate = self

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        loginRow.toggle.target = self
        loginRow.toggle.action = #selector(setLaunchAtLogin(_:))
        let login = NSMenuItem()
        login.view = loginRow
        menu.addItem(login)

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit AI Usage Bar", action: #selector(quit),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu

        changes = store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTitle()
                if self?.isOpen == true { self?.updateContent() }
            }
        updateTitle()
        updateContent()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        store.refresh()
        loginItem.refresh()
        loginRow.toggle.state = loginItem.enabled ? .on : .off
        updateContent()
    }

    func menuWillOpen(_ menu: NSMenu) { isOpen = true }
    func menuDidClose(_ menu: NSMenu) { isOpen = false }

    private func updateTitle() {
        guard let button = item.button else { return }
        let segments = UsagePresentation.menuBar(store.snapshot, settings: store.settings)
        if segments.isEmpty {
            button.image = MenuBarTitle.placeholder()
            button.setAccessibilityLabel("AI usage")
        } else {
            button.image = MenuBarTitle.image(segments) { [weak button] in button?.effectiveAppearance }
            button.setAccessibilityLabel(segments.map(\.accessibilityText).joined(separator: "; "))
        }
        button.imagePosition = .imageOnly
    }

    /// Rebuilds the provider blocks above Refresh; the menu may be open.
    private func updateContent() {
        let content = UsagePresentation.menuContent(store.snapshot, settings: store.settings,
                                                now: store.now)
        guard content != lastContent else { return }
        lastContent = content
        contentItems.forEach(menu.removeItem)
        var views: [AnyView]
        var accessNeeded: [AiProviderId] = []
        switch content {
        case .checking:
            views = [AnyView(MenuNoticeView(title: "Checking AI providers…", detail: nil,
                                            showsProgress: true))]
        case .empty:
            views = [AnyView(MenuNoticeView(
                title: "No AI providers found",
                detail: "Sign in to Codex, Cursor, or Claude Code on this Mac."))]
        case .cards(let cards, let waiting, let access, let unreadable):
            accessNeeded = access
            views = cards.map { AnyView(ProviderCardView(card: $0)) } + waiting.map {
                AnyView(MenuNoticeView(
                    provider: $0, title: UsageFormat.providerName($0),
                    detail: "Waiting for Keychain access. Choose Always Allow in the macOS prompt."))
            }
            views += access.filter { id in !cards.contains { $0.provider == id } }.map {
                AnyView(MenuNoticeView(
                    provider: $0, title: UsageFormat.providerName($0),
                    detail: "Keychain access needed to read the \(Self.credentialOwner($0)) sign-in."))
            }
            views += unreadable.map {
                AnyView(MenuNoticeView(
                    provider: $0, title: UsageFormat.providerName($0),
                    detail: "No current reading. Retrying automatically."))
            }
        }
        contentItems = []
        for (index, view) in views.enumerated() {
            if index > 0 { contentItems.append(.separator()) }
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            let row = NSMenuItem()
            row.view = host
            contentItems.append(row)
        }
        for provider in accessNeeded {
            let allow = NSMenuItem(title: "Allow Access to \(UsageFormat.providerName(provider))…",
                                   action: #selector(requestAccess(_:)), keyEquivalent: "")
            allow.target = self
            allow.tag = Int(provider.rawValue)
            contentItems.append(allow)
        }
        contentItems.append(.separator())
        for (index, row) in contentItems.enumerated() { menu.insertItem(row, at: index) }
    }

    private static func credentialOwner(_ provider: AiProviderId) -> String {
        switch provider {
        case .codex: return "Codex"
        case .claude: return "Claude Code"
        case .cursor: return "Cursor Agent"
        }
    }

    @objc private func requestAccess(_ sender: NSMenuItem) {
        guard let provider = AiProviderId(rawValue: UInt8(sender.tag)) else { return }
        store.requestAccess(provider)
    }

    @objc private func refreshNow() { store.refresh() }

    @objc private func setLaunchAtLogin(_ sender: NSSwitch) {
        loginItem.setEnabled(sender.state == .on)
        sender.state = loginItem.enabled ? .on : .off
    }

    @objc private func showSettings() { openSettings() }

    @objc private func quit() { NSApp.terminate(nil) }
}

/// A menu row with a trailing system `NSSwitch`, like the Wi-Fi menu header.
private final class SwitchMenuRowView: NSView {
    let toggle = NSSwitch()

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: menuRowWidth, height: 30))
        autoresizingMask = .width
        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 0)
        toggle.controlSize = .small
        toggle.setAccessibilityLabel(title)

        for view in [label, toggle] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: menuContentInset),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -menuContentInset),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }
}
