import AppKit
import ApplicationServices
import Foundation
import MarlaCore

enum ClipboardRestoreStatus: String, Codable, Equatable {
    case notAttempted
    case restored
    case skippedBecauseClipboardChanged
    case failed
}

enum PasteboardSnapshotError: Error, Equatable {
    case unreadableRepresentation(type: String)
}

struct PasteboardRepresentation: Equatable {
    let type: String
    let data: Data
}

struct PasteboardItemSnapshot: Equatable {
    let representations: [PasteboardRepresentation]
}

struct PasteboardSnapshot: Equatable {
    let items: [PasteboardItemSnapshot]

    static func capture(from pasteboard: NSPasteboard) throws -> PasteboardSnapshot {
        try capture(items: pasteboard.pasteboardItems ?? [])
    }

    static func capture(items: [NSPasteboardItem]) throws -> PasteboardSnapshot {
        return try PasteboardSnapshot(
            items: items.map { item in
                PasteboardItemSnapshot(
                    representations: try item.types.map { type in
                        guard let data = item.data(forType: type) else {
                            throw PasteboardSnapshotError.unreadableRepresentation(type: type.rawValue)
                        }
                        return PasteboardRepresentation(type: type.rawValue, data: data)
                    }
                )
            }
        )
    }

    func makePasteboardItems() -> [NSPasteboardItem] {
        items.map { itemSnapshot in
            let item = NSPasteboardItem()
            for representation in itemSnapshot.representations {
                item.setData(
                    representation.data,
                    forType: NSPasteboard.PasteboardType(rawValue: representation.type)
                )
            }
            return item
        }
    }
}

@MainActor
protocol SelectionClipboardAccess: AnyObject {
    var changeCount: Int { get }
    func snapshot() throws -> PasteboardSnapshot
    func translationContent() -> TranslationContent?
    func restore(_ snapshot: PasteboardSnapshot, ifUnchangedFrom expectedChangeCount: Int) -> ClipboardRestoreStatus
}

@MainActor
final class SystemSelectionClipboardAccess: SelectionClipboardAccess {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int { pasteboard.changeCount }

    func snapshot() throws -> PasteboardSnapshot {
        try PasteboardSnapshot.capture(from: pasteboard)
    }

    func translationContent() -> TranslationContent? {
        NativeFormattedContentNormalizer.content(from: pasteboard)
    }

    func restore(
        _ snapshot: PasteboardSnapshot,
        ifUnchangedFrom expectedChangeCount: Int
    ) -> ClipboardRestoreStatus {
        guard pasteboard.changeCount == expectedChangeCount else {
            return .skippedBecauseClipboardChanged
        }

        _ = pasteboard.clearContents()
        let items = snapshot.makePasteboardItems()
        if !items.isEmpty, !pasteboard.writeObjects(items) {
            return .failed
        }
        guard let restoredSnapshot = try? PasteboardSnapshot.capture(from: pasteboard),
              restoredSnapshot == snapshot
        else {
            return .failed
        }
        return .restored
    }
}

enum ClipboardSelectionFallbackError: Error, Equatable {
    case sourceApplicationChanged
    case cancelled
    case snapshotUnavailable
    case copyEventUnavailable
    case clipboardChangedDuringCopy
    case timedOut
    case selectedTextUnavailable
    case restoreFailed
}

struct ClipboardSelectionFallbackResult {
    let selection: TextSelection
    let restoreStatus: ClipboardRestoreStatus
}

/// One-shot Bob-compatible selection fallback. It never reads an unchanged
/// pasteboard value and never restores over a newer external write.
@MainActor
final class ClipboardSelectionFallback {
    private static let defaultTimeout: TimeInterval = 0.8
    private static let pollInterval: TimeInterval = 0.01

    private let clipboard: SelectionClipboardAccess
    private let timeout: TimeInterval
    private let now: () -> TimeInterval
    private let pump: (TimeInterval) -> Void
    private let sendCopy: @MainActor () -> Bool
    private let isFrontmost: (NSRunningApplication) -> Bool

    private(set) var lastRestoreStatus: ClipboardRestoreStatus = .notAttempted

    init(
        clipboard: SelectionClipboardAccess = SystemSelectionClipboardAccess(),
        timeout: TimeInterval = ClipboardSelectionFallback.defaultTimeout,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        pump: @escaping (TimeInterval) -> Void = { interval in
            RunLoop.current.run(until: Date(timeIntervalSinceNow: interval))
        },
        sendCopy: @escaping @MainActor () -> Bool = ClipboardSelectionFallback.sendCommandC,
        isFrontmost: @escaping (NSRunningApplication) -> Bool = {
            NSWorkspace.shared.frontmostApplication?.processIdentifier == $0.processIdentifier
        }
    ) {
        self.clipboard = clipboard
        self.timeout = timeout
        self.now = now
        self.pump = pump
        self.sendCopy = sendCopy
        self.isFrontmost = isFrontmost
    }

    func readSelection(
        from application: NSRunningApplication,
        isCancelled: () -> Bool = { false }
    ) throws -> ClipboardSelectionFallbackResult {
        lastRestoreStatus = .notAttempted
        guard !isCancelled() else {
            throw ClipboardSelectionFallbackError.cancelled
        }
        guard isFrontmost(application) else {
            throw ClipboardSelectionFallbackError.sourceApplicationChanged
        }

        let initialChangeCount = clipboard.changeCount
        let snapshot: PasteboardSnapshot
        do {
            snapshot = try clipboard.snapshot()
        } catch {
            throw ClipboardSelectionFallbackError.snapshotUnavailable
        }
        guard clipboard.changeCount == initialChangeCount else {
            throw ClipboardSelectionFallbackError.snapshotUnavailable
        }
        guard !isCancelled() else {
            throw ClipboardSelectionFallbackError.cancelled
        }
        guard isFrontmost(application) else {
            throw ClipboardSelectionFallbackError.sourceApplicationChanged
        }

        guard sendCopy() else {
            throw ClipboardSelectionFallbackError.copyEventUnavailable
        }

        let deadline = now() + max(0, timeout)
        var copyChangeCount: Int?
        var content: TranslationContent?
        var previousCandidate: TranslationContent?
        var pendingAbort: ClipboardSelectionFallbackError?

        while now() < deadline {
            let currentChangeCount = clipboard.changeCount
            if currentChangeCount != initialChangeCount {
                if let copyChangeCount, copyChangeCount != currentChangeCount {
                    lastRestoreStatus = restore(snapshot, afterChange: copyChangeCount)
                    throw ClipboardSelectionFallbackError.clipboardChangedDuringCopy
                }
                copyChangeCount = copyChangeCount ?? currentChangeCount
            }

            if pendingAbort == nil {
                if isCancelled() {
                    pendingAbort = .cancelled
                } else if !isFrontmost(application) {
                    pendingAbort = .sourceApplicationChanged
                }
            }

            if let pendingAbort, let copyChangeCount {
                throw failureAfterRestoring(
                    snapshot,
                    afterChange: copyChangeCount,
                    primaryError: pendingAbort
                )
            }

            if pendingAbort == nil,
               currentChangeCount != initialChangeCount,
               let candidate = clipboard.translationContent(),
               !candidate.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if candidate == previousCandidate {
                    // A source may populate promised Pasteboard representations
                    // after its first change notification. Accept only after the
                    // normalized candidate remains stable across one RunLoop pump.
                    if isCancelled() {
                        pendingAbort = .cancelled
                    } else if !isFrontmost(application) {
                        pendingAbort = .sourceApplicationChanged
                    } else {
                        content = candidate
                        break
                    }
                } else {
                    previousCandidate = candidate
                }
            } else if currentChangeCount != initialChangeCount {
                previousCandidate = nil
            }

            if let pendingAbort, let copyChangeCount {
                throw failureAfterRestoring(
                    snapshot,
                    afterChange: copyChangeCount,
                    primaryError: pendingAbort
                )
            }
            pump(min(Self.pollInterval, max(0, deadline - now())))
        }

        if let pendingAbort {
            // No pasteboard mutation was observed before the bounded deadline,
            // so there is nothing that Marla can safely restore.
            throw pendingAbort
        }

        guard let copyChangeCount else {
            lastRestoreStatus = .notAttempted
            throw ClipboardSelectionFallbackError.timedOut
        }

        guard let content else {
            lastRestoreStatus = restore(snapshot, afterChange: copyChangeCount)
            if lastRestoreStatus == .failed {
                throw ClipboardSelectionFallbackError.restoreFailed
            }
            throw ClipboardSelectionFallbackError.selectedTextUnavailable
        }

        lastRestoreStatus = restore(snapshot, afterChange: copyChangeCount)
        guard lastRestoreStatus != .failed else {
            throw ClipboardSelectionFallbackError.restoreFailed
        }

        return ClipboardSelectionFallbackResult(
            selection: TextSelection(
                content: content,
                bounds: nil,
                applicationBundleID: application.bundleIdentifier,
                applicationName: application.localizedName
            ),
            restoreStatus: lastRestoreStatus
        )
    }

    private func restore(_ snapshot: PasteboardSnapshot, afterChange changeCount: Int) -> ClipboardRestoreStatus {
        clipboard.restore(snapshot, ifUnchangedFrom: changeCount)
    }

    private func failureAfterRestoring(
        _ snapshot: PasteboardSnapshot,
        afterChange changeCount: Int,
        primaryError: ClipboardSelectionFallbackError
    ) -> ClipboardSelectionFallbackError {
        lastRestoreStatus = restore(snapshot, afterChange: changeCount)
        return lastRestoreStatus == .failed ? .restoreFailed : primaryError
    }

    private static func sendCommandC() -> Bool {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        return true
    }
}
