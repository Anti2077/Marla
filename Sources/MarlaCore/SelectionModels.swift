import Foundation

/// A rectangle in the global macOS screen coordinate space.
public struct ScreenRect: Codable, Equatable, Hashable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = max(0, width)
        self.height = max(0, height)
    }
}

/// The source material acquired from the currently focused macOS application.
public struct TextSelection: Equatable, Sendable {
    public let text: String
    public let bounds: ScreenRect?
    public let applicationBundleID: String?
    public let applicationName: String?

    public init(
        text: String,
        bounds: ScreenRect? = nil,
        applicationBundleID: String? = nil,
        applicationName: String? = nil
    ) {
        self.text = text
        self.bounds = bounds
        self.applicationBundleID = applicationBundleID
        self.applicationName = applicationName
    }

    public var hasVisibleText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum SelectionReadingError: Error, Equatable, Sendable {
    case accessibilityPermissionRequired
    case focusedElementUnavailable
    case selectedTextUnavailable
    case emptySelection
    case selectionSearchLimitReached
    case selectionSearchTimedOut
    case selectionCancelled
    case copyFallbackUnavailable
    case copyFallbackTimedOut
    case clipboardRestoreFailed
}

@MainActor
public protocol SelectionReader: AnyObject {
    func readSelection() throws -> TextSelection
}
