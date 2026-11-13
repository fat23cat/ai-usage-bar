import Foundation

/// Where the status menu opens, in screen points (y grows upward).
public enum StatusMenuPlacement {
    /// Space between the menu bar and the top of the menu's first item. AppKit
    /// draws the menu's edge about 5 pt above that item, so the edge sits 4 pt
    /// below the bar. Closer than about 6 pt, AppKit nudges the menu by an
    /// amount that depends on the first item's height, and menus with
    /// different content would no longer line up.
    public static let gap = 9.0

    /// The y where the menu's first item starts, just below the menu bar.
    /// macOS 27 hosts a status item in a window taller than the bar, centered
    /// on it, and opens the item's own menu about 28 pt below the bar; the app
    /// pops its menu up here instead. A screen whose visible frame reserves no
    /// bar (auto-hidden menu bar) is measured from the item window.
    public static func menuTop(screenTop: Double, visibleTop: Double, itemWindowMidY: Double) -> Double {
        let barBottom = visibleTop < screenTop ? visibleTop : itemWindowMidY * 2 - screenTop
        return barBottom - gap
    }
}
