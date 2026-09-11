import AppKit
import Foundation
import MarlaCore
import ScreenCaptureKit

struct CapturedScreenshot {
    let image: CGImage
    let globalRect: CGRect
}

struct ScreenshotCaptureResult {
    let capture: CapturedScreenshot
    let mode: ScreenshotSelectionMode
    let ocrProvider: OCRProviderKind
}

@MainActor
protocol ScreenshotCapturing: AnyObject {
    func present(
        initialOCRProvider: OCRProviderKind,
        allowsWindowSelection: Bool,
        showsOCRProviderPicker: Bool,
        completion: @escaping (Result<ScreenshotCaptureResult, Error>) -> Void
    )
}

@MainActor
final class ScreenshotCaptureCoordinator: ScreenshotCapturing {
    private var windows: [NSWindow] = []
    private var completion: ((Result<ScreenshotCaptureResult, Error>) -> Void)?
    private var selectionSession: ScreenshotSelectionSession?
    private var escapeMonitor: ScreenshotEscapeMonitor?
    private var capturePreparationTask: Task<Void, Never>?
    private var windowCaptureTask: Task<Void, Never>?
    private var capturePreparationID: UUID?

    func present(
        initialOCRProvider: OCRProviderKind = .vision,
        allowsWindowSelection: Bool = true,
        showsOCRProviderPicker: Bool = true,
        completion: @escaping (Result<ScreenshotCaptureResult, Error>) -> Void
    ) {
        if self.completion != nil {
            finish(.failure(ScreenshotError.cancelled))
        }
        self.completion = completion
        let preparationID = UUID()
        capturePreparationID = preparationID
        let escapeMonitor = ScreenshotEscapeMonitor { [weak self] in
            guard let self, self.capturePreparationID == preparationID else { return }
            if let selectionSession {
                selectionSession.cancel()
            } else {
                finish(.failure(ScreenshotError.cancelled))
            }
        }
        self.escapeMonitor = escapeMonitor
        escapeMonitor.install()

        capturePreparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let preparation = try await capturePreparation()
                try Task.checkCancellation()
                guard capturePreparationID == preparationID else { return }
                capturePreparationTask = nil
                showSelection(
                    using: preparation,
                    initialOCRProvider: initialOCRProvider,
                    allowsWindowSelection: allowsWindowSelection,
                    showsOCRProviderPicker: showsOCRProviderPicker
                )
            } catch is CancellationError {
                return
            } catch {
                guard capturePreparationID == preparationID else { return }
                finish(.failure(error))
            }
        }
    }

    private struct CapturePreparation {
        let frozenDisplays: [ScreenshotMagnifierSource]
        let windowTargets: [ScreenshotWindowTarget]
    }

    private func showSelection(
        using preparation: CapturePreparation,
        initialOCRProvider: OCRProviderKind,
        allowsWindowSelection: Bool,
        showsOCRProviderPicker: Bool
    ) {
        let frozenDisplays = preparation.frozenDisplays
        let session = ScreenshotSelectionSession(
            magnifierSources: frozenDisplays,
            windowTargets: preparation.windowTargets,
            initialOCRProvider: initialOCRProvider,
            allowsWindowSelection: allowsWindowSelection,
            showsOCRProviderPicker: showsOCRProviderPicker
        ) { [weak self] selection in
            guard let self else { return }
            if selection.cancelled {
                finish(.failure(ScreenshotError.cancelled))
            } else if selection.mode == .window,
                      let target = selection.windowTarget {
                capture(window: target, ocrProvider: selection.ocrProvider)
            } else {
                capture(
                    global: selection.globalRect,
                    from: frozenDisplays,
                    mode: selection.mode,
                    ocrProvider: selection.ocrProvider
                )
            }
        }
        selectionSession = session
        windows = frozenDisplays.map { source in
            let window = ScreenshotSelectionWindow(
                contentRect: source.screenFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                onCancel: { [weak session] in session?.cancel() },
                onKeyEvent: { [weak session] event in session?.handleKeyEvent(event) ?? false }
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.acceptsMouseMovedEvents = true
            window.contentView = ScreenshotSelectionView(session: session, frozenSource: source)
            window.makeFirstResponder(window.contentView)
            window.orderFrontRegardless()
            return window
        }
        NSApp.activate(ignoringOtherApps: true)
        let pointer = NSEvent.mouseLocation
        let keyWindow = windows.first(where: { $0.frame.contains(pointer) }) ?? windows.first
        keyWindow?.makeKey()
        keyWindow?.makeFirstResponder(keyWindow?.contentView)
    }

    func presentUIAutomationFixture() {
        present { _ in }
        Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<100 where selectionSession == nil {
                try? await Task.sleep(for: .milliseconds(10))
            }
            guard let screen = NSScreen.main else { return }
            let frame = screen.frame
            selectionSession?.begin(
                at: NSPoint(x: frame.minX + frame.width * 0.24, y: frame.minY + frame.height * 0.3)
            )
            selectionSession?.move(
                to: NSPoint(x: frame.minX + frame.width * 0.76, y: frame.minY + frame.height * 0.68)
            )
        }
    }

    private func capture(
        global: NSRect,
        from frozenDisplays: [ScreenshotMagnifierSource],
        mode: ScreenshotSelectionMode,
        ocrProvider: OCRProviderKind
    ) {
        guard global.width > 4, global.height > 4 else {
            finish(.failure(ScreenshotError.invalidRegion))
            return
        }
        guard let image = ScreenshotFrozenCapture.image(
            global: global,
            frozenDisplays: frozenDisplays
        ) else {
            finish(.failure(ScreenshotError.captureFailed))
            return
        }
        finish(.success(ScreenshotCaptureResult(
            capture: CapturedScreenshot(image: image, globalRect: global),
            mode: mode,
            ocrProvider: ocrProvider
        )))
    }

    private func capture(window target: ScreenshotWindowTarget, ocrProvider: OCRProviderKind) {
        guard let window = target.window, let captureID = capturePreparationID else {
            finish(.failure(ScreenshotError.captureFailed))
            return
        }
        let scale = NSScreen.screens
            .first(where: { $0.frame.intersects(target.frame) })?
            .backingScaleFactor ?? 2
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((target.frame.width * scale).rounded(.up)))
        configuration.height = max(1, Int((target.frame.height * scale).rounded(.up)))
        configuration.showsCursor = false
        windowCaptureTask = Task { @MainActor [weak self] in
            do {
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: SCContentFilter(desktopIndependentWindow: window),
                    configuration: configuration
                )
                try Task.checkCancellation()
                guard let self, capturePreparationID == captureID else { return }
                finish(.success(ScreenshotCaptureResult(
                    capture: CapturedScreenshot(image: image, globalRect: target.frame),
                    mode: .window,
                    ocrProvider: ocrProvider
                )))
            } catch is CancellationError {
                return
            } catch {
                self?.finish(.failure(ScreenshotError.captureFailed))
            }
        }
    }

    private func capturePreparation() async throws -> CapturePreparation {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        let ownApplication = shareableContent.applications.first {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        var frozenDisplays: [ScreenshotMagnifierSource] = []
        for screen in NSScreen.screens {
            try Task.checkCancellation()
            guard let screenNumber = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                  ] as? NSNumber,
                  let display = shareableContent.displays.first(where: {
                      $0.displayID == CGDirectDisplayID(screenNumber.uint32Value)
                  }) else {
                continue
            }

            let configuration = SCStreamConfiguration()
            configuration.sourceRect = CGRect(origin: .zero, size: screen.frame.size)
            configuration.width = max(1, Int(screen.frame.width * screen.backingScaleFactor))
            configuration.height = max(1, Int(screen.frame.height * screen.backingScaleFactor))
            configuration.showsCursor = false
            let filter: SCContentFilter
            if let ownApplication {
                filter = SCContentFilter(
                    display: display,
                    excludingApplications: [ownApplication],
                    exceptingWindows: []
                )
            } else {
                filter = SCContentFilter(display: display, excludingWindows: [])
            }
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            frozenDisplays.append(
                ScreenshotMagnifierSource(screenFrame: screen.frame, cgImage: image)
            )
        }
        guard !frozenDisplays.isEmpty, frozenDisplays.count == NSScreen.screens.count else {
            throw ScreenshotError.captureFailed
        }
        return CapturePreparation(
            frozenDisplays: frozenDisplays,
            windowTargets: ScreenshotWindowTargeting.targets(
                from: shareableContent,
                excludingProcessID: ProcessInfo.processInfo.processIdentifier,
                primaryScreenMaxY: NSScreen.screens.first?.frame.maxY ?? 0
            )
        )
    }

    private func finish(_ result: Result<ScreenshotCaptureResult, Error>) {
        capturePreparationTask?.cancel()
        capturePreparationTask = nil
        windowCaptureTask?.cancel()
        windowCaptureTask = nil
        capturePreparationID = nil
        escapeMonitor?.remove()
        escapeMonitor = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        selectionSession = nil
        let completion = self.completion
        self.completion = nil
        completion?(result)
    }
}

@MainActor
final class ScreenshotEscapeMonitor {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private let onEscape: () -> Void

    init(onEscape: @escaping () -> Void) {
        self.onEscape = onEscape
    }

    var isInstalled: Bool {
        localMonitor != nil || globalMonitor != nil || eventTap != nil
    }

    var hasEventTap: Bool {
        eventTap != nil
    }

    func install() {
        remove()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleLocal(event) ?? event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.isCancelKeyCode(event.keyCode) else { return }
            Task { @MainActor [weak self] in
                self?.onEscape()
            }
        }
        installEventTap()
    }

    func remove() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            self.eventTapSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    func handleLocal(_ event: NSEvent) -> NSEvent? {
        guard Self.isCancelKeyCode(event.keyCode) else { return event }
        onEscape()
        return nil
    }

    func handleGlobal(_ event: NSEvent) {
        guard Self.isCancelKeyCode(event.keyCode) else { return }
        onEscape()
    }

    func handleEventTapEscape() {
        onEscape()
    }

    nonisolated static func isCancelKeyCode(_ keyCode: UInt16) -> Bool {
        keyCode == 53
    }

    func reenableEventTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func installEventTap() {
        let keyDownMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        // A default tap can be denied when Marla is allowed to listen but not
        // suppress system keyboard events.  A listen-only tap still gives us a
        // process-independent Escape notification; local/global monitors remain
        // responsible for consuming it when AppKit owns the event.
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: keyDownMask,
            callback: handleScreenshotEscapeEventTap,
            userInfo: userInfo
        ) ?? CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: keyDownMask,
            callback: handleScreenshotEscapeEventTap,
            userInfo: userInfo
        )
        guard let eventTap else { return }
        guard let source = CFMachPortCreateRunLoopSource(nil, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            return
        }
        self.eventTap = eventTap
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}

private func handleScreenshotEscapeEventTap(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userData: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userData else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<ScreenshotEscapeMonitor>.fromOpaque(userData).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Task { @MainActor in monitor.reenableEventTap() }
        return Unmanaged.passUnretained(event)
    }
    guard type == .keyDown,
          ScreenshotEscapeMonitor.isCancelKeyCode(
              UInt16(event.getIntegerValueField(.keyboardEventKeycode))
          )
    else { return Unmanaged.passUnretained(event) }
    Task { @MainActor in monitor.handleEventTapEscape() }
    return nil
}
