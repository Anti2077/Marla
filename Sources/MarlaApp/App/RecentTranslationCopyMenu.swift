import AppKit
import SwiftUI

/// A native pull-down button exposes menu tracking so the row stays revealed
/// while the pointer moves out of it to choose a menu item.
struct RecentTranslationCopyMenu: NSViewRepresentable {
    let isEnabled: Bool
    let isConfirmed: Bool
    let identifier: String
    let onCopySource: () -> Void
    let onTrackingChange: (Bool) -> Void
    let onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> FocusReportingPopUpButton {
        let button = FocusReportingPopUpButton(frame: .zero, pullsDown: true)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.focusRingType = .default
        button.preferredEdge = .maxY
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        button.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.parent.onFocusChange(focused)
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = context.coordinator
        menu.addItem(NSMenuItem(title: "", action: nil, keyEquivalent: ""))
        let copy = NSMenuItem(title: "复制原文", action: #selector(Coordinator.copySource), keyEquivalent: "")
        copy.target = context.coordinator
        menu.addItem(copy)
        button.menu = menu
        updateNSView(button, context: context)
        return button
    }

    func updateNSView(_ button: FocusReportingPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.isEnabled = isEnabled
        button.menu?.item(at: 1)?.isEnabled = isEnabled
        button.menu?.item(at: 0)?.image = NSImage(
            systemSymbolName: isConfirmed ? "checkmark" : "chevron.down",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 9, weight: .medium))
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = isConfirmed ? "已复制原文" : "更多复制选项"
        button.setAccessibilityLabel(button.toolTip)
        button.setAccessibilityIdentifier(identifier)
    }

    final class Coordinator: NSObject, NSMenuDelegate {
        var parent: RecentTranslationCopyMenu
        init(_ parent: RecentTranslationCopyMenu) { self.parent = parent }
        func menuWillOpen(_ menu: NSMenu) { parent.onTrackingChange(true) }
        func menuDidClose(_ menu: NSMenu) { parent.onTrackingChange(false) }
        @objc func copySource() { parent.onCopySource() }
    }

    final class FocusReportingPopUpButton: NSPopUpButton {
        var onFocusChange: ((Bool) -> Void)?

        override func becomeFirstResponder() -> Bool {
            let accepted = super.becomeFirstResponder()
            if accepted { onFocusChange?(true) }
            return accepted
        }

        override func resignFirstResponder() -> Bool {
            let accepted = super.resignFirstResponder()
            if accepted { onFocusChange?(false) }
            return accepted
        }
    }
}
