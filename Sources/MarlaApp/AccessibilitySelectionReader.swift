import AppKit
import ApplicationServices
import MarlaCore

@MainActor
final class AccessibilitySelectionReader: SelectionReader {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestAccess() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    func readSelection() throws -> TextSelection {
        guard isTrusted else {
            throw SelectionReadingError.accessibilityPermissionRequired
        }

        let systemWideElement = AXUIElementCreateSystemWide()
        guard let focusedElement = copyFocusedElement(from: systemWideElement) else {
            throw SelectionReadingError.focusedElementUnavailable
        }

        guard let selectedText = copyStringAttribute(
            kAXSelectedTextAttribute as CFString,
            from: focusedElement
        ) else {
            throw SelectionReadingError.selectedTextUnavailable
        }

        let application = NSWorkspace.shared.frontmostApplication
        let selection = TextSelection(
            text: selectedText,
            bounds: copySelectionBounds(from: focusedElement),
            applicationBundleID: application?.bundleIdentifier,
            applicationName: application?.localizedName
        )

        guard selection.hasVisibleText else {
            throw SelectionReadingError.emptySelection
        }

        return selection
    }

    private func copyFocusedElement(from systemWideElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        let element = value as! AXUIElement
        return element
    }

    private func copyStringAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success else {
            return nil
        }

        return value as? String
    }

    private func copySelectionBounds(from element: AXUIElement) -> ScreenRect? {
        var rangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )

        guard rangeResult == .success, let rangeValue else {
            return nil
        }

        var boundsValue: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )

        guard boundsResult == .success,
              let boundsValue,
              CFGetTypeID(boundsValue) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = boundsValue as! AXValue
        guard AXValueGetType(axValue) == .cgRect else {
            return nil
        }

        var rectangle = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rectangle) else {
            return nil
        }

        return ScreenRect(
            x: rectangle.origin.x,
            y: rectangle.origin.y,
            width: rectangle.width,
            height: rectangle.height
        )
    }
}
