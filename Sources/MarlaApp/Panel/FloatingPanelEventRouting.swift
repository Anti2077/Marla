import AppKit

enum FloatingPanelEventRouting {
    /// SwiftUI popovers are represented by an AppKit child/attached window.
    /// Treat those windows as part of the result surface so clicking a width
    /// preset does not look like an outside click and dismiss the translation.
    static func isPanelRelatedWindow(_ eventWindow: NSWindow?, panel: NSWindow?) -> Bool {
        guard let eventWindow, let panel else { return false }
        if eventWindow === panel { return true }

        var ancestor = eventWindow.parent
        while let window = ancestor {
            if window === panel { return true }
            ancestor = window.parent
        }

        func contains(_ candidate: NSWindow, in root: NSWindow) -> Bool {
            guard let children = root.childWindows else { return false }
            for child in children {
                if child === candidate || contains(candidate, in: child) {
                    return true
                }
            }
            return false
        }
        return contains(eventWindow, in: panel)
    }
}
