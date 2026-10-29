import Foundation

public enum UsageDisplayMode: String, Codable, CaseIterable {
    /// Bars and numbers show remaining capacity, as on Cardputer.
    case left
    /// Bars and numbers show consumed capacity.
    case used
}

public struct UsageSettings: Equatable, Codable {
    public var displayMode: UsageDisplayMode
    /// Display order of providers in the menu bar and in the popover.
    public var providerOrder: [AiProviderId]
    /// Providers left out of the menu bar title; the popover still shows them.
    public var hiddenInMenuBar: Set<AiProviderId>
    public var notificationsEnabled: Bool

    public static let defaultOrder: [AiProviderId] = [.codex, .claude, .cursor]

    public init(displayMode: UsageDisplayMode = .left,
                providerOrder: [AiProviderId] = UsageSettings.defaultOrder,
                hiddenInMenuBar: Set<AiProviderId> = [], notificationsEnabled: Bool = true) {
        self.displayMode = displayMode
        self.providerOrder = UsageSettings.completeOrder(providerOrder)
        self.hiddenInMenuBar = hiddenInMenuBar
        self.notificationsEnabled = notificationsEnabled
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            displayMode: (try? values.decodeIfPresent(UsageDisplayMode.self, forKey: .displayMode))
                .flatMap { $0 } ?? .left,
            providerOrder: (try? values.decodeIfPresent([AiProviderId].self, forKey: .providerOrder))
                .flatMap { $0 } ?? UsageSettings.defaultOrder,
            hiddenInMenuBar: (try? values.decodeIfPresent(Set<AiProviderId>.self,
                                                          forKey: .hiddenInMenuBar))
                .flatMap { $0 } ?? [],
            notificationsEnabled: (try? values.decodeIfPresent(Bool.self,
                                                               forKey: .notificationsEnabled))
                .flatMap { $0 } ?? true)
    }

    /// Every provider exactly once: the stored order first, unknown ones last.
    static func completeOrder(_ order: [AiProviderId]) -> [AiProviderId] {
        var seen = Set<AiProviderId>()
        let stored = order.filter { seen.insert($0).inserted }
        return stored + defaultOrder.filter { !seen.contains($0) }
    }

    public func ordered<T>(_ items: [T], by provider: (T) -> AiProviderId) -> [T] {
        items.sorted {
            (providerOrder.firstIndex(of: provider($0)) ?? Int.max) <
                (providerOrder.firstIndex(of: provider($1)) ?? Int.max)
        }
    }

    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { providerOrder[$0] }
        var rest = providerOrder.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.filter { $0 < destination }.count
        rest.insert(contentsOf: moving, at: max(0, min(insertAt, rest.count)))
        providerOrder = rest
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func decoded(_ data: Data?) -> UsageSettings {
        data.flatMap { try? JSONDecoder().decode(UsageSettings.self, from: $0) } ?? UsageSettings()
    }
}
