import AppKit
import Foundation
import SwiftUI

enum SettingsWindowStyle {
    static func apply(to window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        // Keep dragging scoped to the native title bar. Treating the entire
        // content surface as a window-drag region steals pointer drags from
        // controls such as the API profile reorder handle.
        window.isMovableByWindowBackground = false
        apply(to: window.contentView)
    }

    static func apply(to contentView: NSView?) {
        guard let contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = DesignTokens.radiusL
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
    }
}

@MainActor
final class MarlaSettingsWindowCoordinator: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?

    init(window: NSWindow? = nil) {
        self.window = window
        super.init()
    }

    func present(settings: MarlaSettingsStore, appModel: MarlaApplicationModel) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Marla 设置"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 820, height: 560)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(
            rootView: SettingsView(settings: settings, appModel: appModel)
        )
        SettingsWindowStyle.apply(to: window)
        window.center()
        window.delegate = self
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func suspendForScreenshotSelection() -> Bool {
        guard let window, window.isVisible else { return false }
        window.orderOut(nil)
        return true
    }

    func restoreAfterScreenshotSelection(wasVisible: Bool) {
        guard wasVisible, let window else { return }
        window.orderBack(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}


