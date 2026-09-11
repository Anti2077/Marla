import AppKit
import Foundation
import MarlaCore
import SwiftUI

enum ScreenCaptureGeometry {
    /// ScreenCaptureKit source rectangles use a display-local, top-left origin, while AppKit
    /// selection windows report global points with a bottom-left origin.
    static func sourceRect(intersection: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: intersection.minX - screenFrame.minX,
            y: screenFrame.maxY - intersection.maxY,
            width: intersection.width,
            height: intersection.height
        )
    }

    static func destinationRect(intersection: CGRect, selection: CGRect, scale: CGFloat) -> CGRect {
        CGRect(
            x: (intersection.minX - selection.minX) * scale,
            y: (intersection.minY - selection.minY) * scale,
            width: intersection.width * scale,
            height: intersection.height * scale
        )
    }
}

enum ScreenshotFrozenCapture {
    struct Fragment {
        let displayIndex: Int
        let clipRect: CGRect
        let fullDisplayRect: CGRect
    }

    struct Layout {
        let pixelSize: CGSize
        let scale: CGFloat
        let fragments: [Fragment]
    }

    static func layout(
        global: CGRect,
        frozenDisplays: [ScreenshotMagnifierSource]
    ) -> Layout? {
        guard global.width > 0, global.height > 0 else { return nil }
        let intersectingDisplays = frozenDisplays.enumerated().filter {
            !$0.element.screenFrame.intersection(global).isNull
                && $0.element.screenFrame.intersection(global).width > 0
                && $0.element.screenFrame.intersection(global).height > 0
        }
        guard !intersectingDisplays.isEmpty else { return nil }
        let scale = intersectingDisplays.map(\.element.pixelScale).max() ?? 1
        let pixelSize = CGSize(
            width: max(1, (global.width * scale).rounded(.up)),
            height: max(1, (global.height * scale).rounded(.up))
        )
        let fragments = intersectingDisplays.map { index, source in
            let intersection = source.screenFrame.intersection(global)
            return Fragment(
                displayIndex: index,
                clipRect: ScreenCaptureGeometry.destinationRect(
                    intersection: intersection,
                    selection: global,
                    scale: scale
                ),
                fullDisplayRect: CGRect(
                    x: (source.screenFrame.minX - global.minX) * scale,
                    y: (source.screenFrame.minY - global.minY) * scale,
                    width: source.screenFrame.width * scale,
                    height: source.screenFrame.height * scale
                )
            )
        }
        return Layout(pixelSize: pixelSize, scale: scale, fragments: fragments)
    }

    static func image(
        global: CGRect,
        frozenDisplays: [ScreenshotMagnifierSource]
    ) -> CGImage? {
        guard let layout = layout(global: global, frozenDisplays: frozenDisplays),
              let context = CGContext(
                  data: nil,
                  width: Int(layout.pixelSize.width),
                  height: Int(layout.pixelSize.height),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        for fragment in layout.fragments {
            context.saveGState()
            context.clip(to: fragment.clipRect)
            context.draw(
                frozenDisplays[fragment.displayIndex].cgImage,
                in: fragment.fullDisplayRect
            )
            context.restoreGState()
        }
        return context.makeImage()
    }
}

struct ScreenshotMagnifierGeometry {
    static let size = NSSize(width: 104, height: 128)
    static let margin: CGFloat = 8
    static let offset = NSSize(width: 18, height: 18)

    static func frame(pointer: NSPoint, in bounds: NSRect) -> NSRect {
        var origin = NSPoint(
            x: pointer.x + offset.width,
            y: pointer.y + offset.height
        )
        if origin.x + size.width > bounds.maxX - margin {
            origin.x = pointer.x - offset.width - size.width
        }
        if origin.y + size.height > bounds.maxY - margin {
            origin.y = pointer.y - offset.height - size.height
        }
        origin.x = min(max(origin.x, bounds.minX + margin), bounds.maxX - size.width - margin)
        origin.y = min(max(origin.y, bounds.minY + margin), bounds.maxY - size.height - margin)
        return NSRect(origin: origin, size: size)
    }

    static func sourceRect(
        pointer: NSPoint,
        in sourceBounds: NSRect,
        destinationSize: NSSize,
        zoom: CGFloat
    ) -> NSRect {
        let width = min(sourceBounds.width, destinationSize.width / zoom)
        let height = min(sourceBounds.height, destinationSize.height / zoom)
        let x = min(max(pointer.x - width / 2, sourceBounds.minX), sourceBounds.maxX - width)
        let y = min(max(pointer.y - height / 2, sourceBounds.minY), sourceBounds.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

struct ScreenshotMagnifierSource {
    let screenFrame: NSRect
    let cgImage: CGImage
    let image: NSImage

    init(screenFrame: NSRect, cgImage: CGImage) {
        self.screenFrame = screenFrame
        self.cgImage = cgImage
        image = NSImage(cgImage: cgImage, size: screenFrame.size)
    }

    init?(screen: NSScreen) {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let cgImage = CGDisplayCreateImage(CGDirectDisplayID(screenNumber.uint32Value)) else {
            return nil
        }
        self.init(screenFrame: screen.frame, cgImage: cgImage)
    }

    var pixelScale: CGFloat {
        guard screenFrame.width > 0, screenFrame.height > 0 else { return 1 }
        return max(
            CGFloat(cgImage.width) / screenFrame.width,
            CGFloat(cgImage.height) / screenFrame.height
        )
    }

    func contains(_ point: NSPoint) -> Bool {
        screenFrame.contains(point)
    }

    func localPoint(for globalPoint: NSPoint) -> NSPoint {
        NSPoint(x: globalPoint.x - screenFrame.minX, y: globalPoint.y - screenFrame.minY)
    }
}

@MainActor
final class ScreenshotSelectionSession: NSObject {
    private(set) var startPoint: NSPoint?
    private(set) var currentPoint: NSPoint?
    private(set) var pointerPoint: NSPoint?
    private(set) var isConfirming = false
    private(set) var confirmationProgress: CGFloat = 0
    private(set) var selectionMode: ScreenshotSelectionMode = .region
    private(set) var highlightedWindow: ScreenshotWindowTarget?
    private(set) var selectedOCRProvider: OCRProviderKind
    let magnifierSources: [ScreenshotMagnifierSource]
    let windowTargets: [ScreenshotWindowTarget]
    let visibleBounds: CGRect
    let allowsWindowSelection: Bool
    private var redrawCallbacks: [() -> Void] = []
    private var hasFinished = false
    private let reducesMotion: Bool
    private let confirmationDuration: TimeInterval
    private var confirmationStartedAt: TimeInterval?
    private var confirmationTimer: Timer?
    private var isPanning = false
    private var panStartPointer: NSPoint?
    private var panOriginRect: NSRect?
    private var panOriginStartPoint: NSPoint?
    private var panOriginCurrentPoint: NSPoint?
    private var resizePointerOffset = NSPoint.zero
    private let onFinish: (NSRect, Bool) -> Void
    private let onSelectionFinish: ((ScreenshotSelectionResult) -> Void)?

    init(
        magnifierSources: [ScreenshotMagnifierSource] = [],
        windowTargets: [ScreenshotWindowTarget] = [],
        initialOCRProvider: OCRProviderKind = .vision,
        allowsWindowSelection: Bool = true,
        reducesMotion: Bool? = nil,
        confirmationDuration: TimeInterval = MarlaMotion.screenshotConfirmationDuration,
        onFinish: @escaping (NSRect, Bool) -> Void
    ) {
        self.magnifierSources = magnifierSources
        self.windowTargets = windowTargets
        visibleBounds = ScreenshotWindowTargeting.visibleBounds(for: magnifierSources)
        selectedOCRProvider = initialOCRProvider
        self.allowsWindowSelection = allowsWindowSelection
        onSelectionFinish = nil
        showsOCRProviderPicker = false
        self.reducesMotion = reducesMotion ?? (
            ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
                || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        self.confirmationDuration = max(0, confirmationDuration)
        self.onFinish = onFinish
        super.init()
    }

    init(
        magnifierSources: [ScreenshotMagnifierSource] = [],
        windowTargets: [ScreenshotWindowTarget] = [],
        initialOCRProvider: OCRProviderKind = .vision,
        allowsWindowSelection: Bool = true,
        showsOCRProviderPicker: Bool = true,
        reducesMotion: Bool? = nil,
        confirmationDuration: TimeInterval = MarlaMotion.screenshotConfirmationDuration,
        onSelectionFinish: @escaping (ScreenshotSelectionResult) -> Void
    ) {
        self.magnifierSources = magnifierSources
        self.windowTargets = windowTargets
        visibleBounds = ScreenshotWindowTargeting.visibleBounds(for: magnifierSources)
        selectedOCRProvider = initialOCRProvider
        self.allowsWindowSelection = allowsWindowSelection
        onFinish = { _, _ in }
        self.onSelectionFinish = onSelectionFinish
        self.showsOCRProviderPicker = showsOCRProviderPicker
        self.reducesMotion = reducesMotion ?? (
            ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
                || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        self.confirmationDuration = max(0, confirmationDuration)
        super.init()
    }

    let showsOCRProviderPicker: Bool

    var selectionRect: NSRect {
        guard let startPoint, let currentPoint else { return .zero }
        return NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }

    var confirmationCornerInset: CGFloat {
        reducesMotion ? 0 : 4 * confirmationProgress
    }

    var confirmationOpacity: CGFloat {
        reducesMotion ? 1 - (0.45 * confirmationProgress) : 1
    }

    func attach(_ view: ScreenshotSelectionView) {
        redrawCallbacks.append { [weak view] in view?.needsDisplay = true }
    }

    func begin(at point: NSPoint) {
        guard !hasFinished, !isConfirming, selectionMode == .region else { return }
        pointerPoint = point
        startPoint = point
        currentPoint = point
        resizePointerOffset = .zero
        redraw()
    }

    func move(to point: NSPoint) {
        guard startPoint != nil, !hasFinished, !isConfirming else { return }
        pointerPoint = point
        if isPanning,
           let panStartPointer,
           let panOriginRect,
           let panOriginStartPoint,
           let panOriginCurrentPoint {
            let translated = CGRect(
                x: panOriginRect.minX + point.x - panStartPointer.x,
                y: panOriginRect.minY + point.y - panStartPointer.y,
                width: panOriginRect.width,
                height: panOriginRect.height
            )
            let clamped = ScreenshotWindowTargeting.clamped(rect: translated, to: visibleBounds)
            let delta = NSPoint(
                x: clamped.minX - panOriginRect.minX,
                y: clamped.minY - panOriginRect.minY
            )
            startPoint = NSPoint(
                x: panOriginStartPoint.x + delta.x,
                y: panOriginStartPoint.y + delta.y
            )
            currentPoint = NSPoint(
                x: panOriginCurrentPoint.x + delta.x,
                y: panOriginCurrentPoint.y + delta.y
            )
        } else {
            currentPoint = NSPoint(
                x: point.x + resizePointerOffset.x,
                y: point.y + resizePointerOffset.y
            )
        }
        redraw()
    }

    func hover(at point: NSPoint) {
        guard !hasFinished, !isConfirming else { return }
        pointerPoint = point
        if selectionMode == .window {
            highlightedWindow = ScreenshotWindowTargeting.hitTest(point: point, in: windowTargets)
        }
        redraw()
    }

    func setOCRProvider(_ provider: OCRProviderKind) {
        guard !hasFinished else { return }
        selectedOCRProvider = provider
        redraw()
    }

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            return handleKeyDown(event)
        case .keyUp:
            return handleKeyUp(event)
        default:
            return false
        }
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard !hasFinished else { return true }
        if ScreenshotSelectionView.isCancelKeyCode(event.keyCode) {
            cancel()
            return true
        }
        if event.keyCode == 49 {
            if startPoint != nil {
                beginPanning()
            } else if allowsWindowSelection, !event.isARepeat {
                selectionMode = selectionMode == .window ? .region : .window
                highlightedWindow = nil
                redraw()
            }
            return true
        }
        if showsOCRProviderPicker,
           let characters = event.charactersIgnoringModifiers,
           let provider = ScreenshotOCRProviderOption.provider(forKey: characters) {
            setOCRProvider(provider)
            return true
        }
        return false
    }

    func handleKeyUp(_ event: NSEvent) -> Bool {
        guard event.keyCode == 49 else { return false }
        endPanning()
        return true
    }

    func selectWindow(at point: NSPoint) {
        guard !hasFinished, !isConfirming, selectionMode == .window,
              let target = ScreenshotWindowTargeting.hitTest(point: point, in: windowTargets)
        else { return }
        pointerPoint = point
        highlightedWindow = target
        isConfirming = true
        confirmationProgress = 1
        hasFinished = true
        onSelectionFinish?(ScreenshotSelectionResult(
            globalRect: target.frame,
            mode: .window,
            windowTarget: target,
            ocrProvider: selectedOCRProvider,
            cancelled: false
        ))
    }

    private func beginPanning() {
        guard !isPanning, selectionRect.width > 0, selectionRect.height > 0 else { return }
        isPanning = true
        panStartPointer = pointerPoint
        panOriginRect = selectionRect
        panOriginStartPoint = startPoint
        panOriginCurrentPoint = currentPoint
    }

    private func endPanning() {
        guard isPanning else { return }
        isPanning = false
        if let pointerPoint, let currentPoint {
            resizePointerOffset = NSPoint(
                x: currentPoint.x - pointerPoint.x,
                y: currentPoint.y - pointerPoint.y
            )
        }
        panStartPointer = nil
        panOriginRect = nil
        panOriginStartPoint = nil
        panOriginCurrentPoint = nil
    }

    func confirm(at point: NSPoint) {
        guard !hasFinished, !isConfirming else { return }
        move(to: point)
        guard selectionRect.width > 4, selectionRect.height > 4 else {
            finish(cancelled: true)
            return
        }
        isConfirming = true
        confirmationProgress = 0
        redraw()
        guard confirmationDuration > 0 else {
            confirmationProgress = 1
            redraw()
            finish(cancelled: false)
            return
        }
        confirmationStartedAt = ProcessInfo.processInfo.systemUptime
        let timer = Timer(
            timeInterval: 1 / 60,
            target: self,
            selector: #selector(advanceConfirmation),
            userInfo: nil,
            repeats: true
        )
        confirmationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func cancel() {
        finish(cancelled: true)
    }

    private func redraw() {
        redrawCallbacks.forEach { $0() }
    }

    @objc private func advanceConfirmation() {
        guard isConfirming, let confirmationStartedAt else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - confirmationStartedAt
        let linearProgress = min(max(elapsed / confirmationDuration, 0), 1)
        confirmationProgress = CGFloat(1 - pow(1 - linearProgress, 3))
        redraw()
        if linearProgress >= 1 {
            finish(cancelled: false)
        }
    }

    private func finish(cancelled: Bool) {
        guard !hasFinished else { return }
        hasFinished = true
        endPanning()
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        confirmationStartedAt = nil
        isConfirming = false
        if cancelled {
            confirmationProgress = 0
        } else {
            confirmationProgress = 1
        }
        if let onSelectionFinish {
            onSelectionFinish(ScreenshotSelectionResult(
                globalRect: selectionRect,
                mode: selectionMode,
                windowTarget: highlightedWindow,
                ocrProvider: selectedOCRProvider,
                cancelled: cancelled
            ))
        } else {
            onFinish(selectionRect, cancelled)
        }
    }
}

final class ScreenshotSelectionView: NSView {
    private let session: ScreenshotSelectionSession
    private let frozenSource: ScreenshotMagnifierSource?
    private let hintView: NSHostingView<ScreenshotGlassLabel>
    private let sizeView: NSHostingView<ScreenshotGlassLabel>
    private let ocrPickerView: NSHostingView<ScreenshotOCRPicker>

    init(
        session: ScreenshotSelectionSession,
        frozenSource: ScreenshotMagnifierSource? = nil
    ) {
        self.session = session
        self.frozenSource = frozenSource
        hintView = NSHostingView(
            rootView: ScreenshotGlassLabel(
                text: "拖动框选要翻译的区域 · Esc 取消",
                usesMonospacedDigits: false
            )
        )
        sizeView = NSHostingView(
            rootView: ScreenshotGlassLabel(text: "0 × 0", usesMonospacedDigits: true)
        )
        ocrPickerView = NSHostingView(
            rootView: ScreenshotOCRPicker(
                selectedProvider: session.selectedOCRProvider,
                onSelect: { [weak session] provider in session?.setOCRProvider(provider) }
            )
        )
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(hintView)
        addSubview(sizeView)
        addSubview(ocrPickerView)
        sizeView.isHidden = true
        ocrPickerView.isHidden = !session.showsOCRProviderPicker
        session.attach(self)
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let window else { return }
        session.hover(at: window.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        if session.selectionMode == .region {
            session.begin(at: point)
        } else {
            session.hover(at: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        if session.selectionMode == .window {
            session.hover(at: point)
        } else {
            session.move(to: point)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let window else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        if session.selectionMode == .window {
            session.selectWindow(at: point)
        } else {
            session.confirm(at: point)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        session.cancel()
    }

    override func keyDown(with event: NSEvent) {
        _ = session.handleKeyDown(event)
    }

    override func keyUp(with event: NSEvent) {
        _ = session.handleKeyUp(event)
    }

    static func isCancelKeyCode(_ keyCode: UInt16) -> Bool {
        keyCode == 53
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        hintView.rootView = ScreenshotGlassLabel(
            text: session.selectionMode == .window
                ? "窗口模式 · 移动到窗口后单击 · Space 返回框选 · Esc 取消"
                : "拖动框选要翻译的区域 · Space 平移 · Esc 取消",
            usesMonospacedDigits: false
        )
        ocrPickerView.rootView = ScreenshotOCRPicker(
            selectedProvider: session.selectedOCRProvider,
            onSelect: { [weak session] provider in session?.setOCRProvider(provider) }
        )
        ocrPickerView.isHidden = !session.showsOCRProviderPicker
        let pickerSize = ocrPickerView.fittingSize
        ocrPickerView.frame = NSRect(
            x: bounds.maxX - pickerSize.width - 16,
            y: bounds.minY + 16,
            width: pickerSize.width,
            height: pickerSize.height
        )
        frozenSource?.image.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: frozenSource?.image.size ?? .zero),
            operation: .copy,
            fraction: 1
        )
        NSColor.black.withAlphaComponent(0.42).setFill()
        bounds.fill()
        guard let window else { return }
        let rect = window.convertFromScreen(session.selectionRect)
        if rect.width <= 0 || rect.height <= 0 {
            hintView.isHidden = false
            sizeView.isHidden = true
            let size = hintView.fittingSize
            hintView.frame = NSRect(
                x: bounds.midX - size.width / 2,
                y: ScreenshotSelectionLayout.topHintOriginY(
                    bounds: bounds,
                    hintHeight: size.height,
                    safeAreaTopInset: window.screen?.safeAreaInsets.top ?? 0
                ),
                width: size.width,
                height: size.height
            )
            if session.selectionMode == .window,
               let target = session.highlightedWindow {
                let targetRect = window.convertFromScreen(target.frame)
                NSColor.systemBlue.withAlphaComponent(0.12).setFill()
                targetRect.fill()
                NSColor.systemBlue.withAlphaComponent(0.95).setStroke()
                let border = NSBezierPath(rect: targetRect)
                border.lineWidth = 2
                border.stroke()
            }
        }
        if rect.width > 0, rect.height > 0 {
            hintView.isHidden = true
            if let frozenSource {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: rect).addClip()
                frozenSource.image.draw(
                    in: bounds,
                    from: NSRect(origin: .zero, size: frozenSource.image.size),
                    operation: .copy,
                    fraction: 1
                )
                NSGraphicsContext.restoreGraphicsState()
            } else {
                NSGraphicsContext.current?.compositingOperation = .clear
                rect.fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
            }
            NSColor.white.withAlphaComponent(session.confirmationOpacity).setStroke()
            let border = NSBezierPath(rect: rect)
            border.lineWidth = 1
            border.stroke()
            let length: CGFloat = 10
            let cornerRect = rect.insetBy(
                dx: session.confirmationCornerInset,
                dy: session.confirmationCornerInset
            )
            let corners = [
                (NSPoint(x: cornerRect.minX, y: cornerRect.minY), NSPoint(x: cornerRect.minX + length, y: cornerRect.minY), NSPoint(x: cornerRect.minX, y: cornerRect.minY + length)),
                (NSPoint(x: cornerRect.maxX, y: cornerRect.minY), NSPoint(x: cornerRect.maxX - length, y: cornerRect.minY), NSPoint(x: cornerRect.maxX, y: cornerRect.minY + length)),
                (NSPoint(x: cornerRect.minX, y: cornerRect.maxY), NSPoint(x: cornerRect.minX + length, y: cornerRect.maxY), NSPoint(x: cornerRect.minX, y: cornerRect.maxY - length)),
                (NSPoint(x: cornerRect.maxX, y: cornerRect.maxY), NSPoint(x: cornerRect.maxX - length, y: cornerRect.maxY), NSPoint(x: cornerRect.maxX, y: cornerRect.maxY - length))
            ]
            corners.forEach { first, second, third in
                let path = NSBezierPath()
                path.move(to: first); path.line(to: second); path.move(to: first); path.line(to: third)
                path.lineWidth = 2
                path.stroke()
            }
            sizeView.rootView = ScreenshotGlassLabel(
                text: "\(Int(rect.width)) × \(Int(rect.height))",
                usesMonospacedDigits: true
            )
            let labelSize = sizeView.fittingSize
            sizeView.frame = NSRect(
                x: rect.minX,
                y: max(bounds.minY + 8, rect.minY - labelSize.height - 6),
                width: labelSize.width,
                height: labelSize.height
            )
            sizeView.isHidden = false
        }
        if !session.isConfirming, session.selectionMode == .region {
            drawMagnifier(in: window)
        }
    }

    private func drawMagnifier(in window: NSWindow) {
        guard let globalPoint = session.pointerPoint,
              let source = session.magnifierSources.first(where: { $0.contains(globalPoint) }) else { return }
        let localPoint = window.convertFromScreen(NSRect(origin: globalPoint, size: .zero)).origin
        guard bounds.contains(localPoint) else { return }

        let frame = ScreenshotMagnifierGeometry.frame(pointer: localPoint, in: bounds)
        let outerPath = NSBezierPath(roundedRect: frame, xRadius: 14, yRadius: 14)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.set()
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        outerPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        let imageRect = NSRect(x: frame.minX + 4, y: frame.minY + 28, width: 96, height: 96)
        let imagePath = NSBezierPath(roundedRect: imageRect, xRadius: 11, yRadius: 11)
        NSGraphicsContext.saveGraphicsState()
        imagePath.addClip()
        let sourceBounds = NSRect(origin: .zero, size: source.image.size)
        let sourceRect = ScreenshotMagnifierGeometry.sourceRect(
            pointer: source.localPoint(for: globalPoint),
            in: sourceBounds,
            destinationSize: imageRect.size,
            zoom: 6
        )
        source.image.draw(
            in: imageRect,
            from: sourceRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.none]
        )
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.92).setStroke()
        outerPath.lineWidth = 1.5
        outerPath.stroke()
        imagePath.lineWidth = 0.5
        imagePath.stroke()

        let center = NSPoint(x: imageRect.midX, y: imageRect.midY)
        let crosshair = NSBezierPath()
        crosshair.move(to: NSPoint(x: center.x - 10, y: center.y))
        crosshair.line(to: NSPoint(x: center.x + 10, y: center.y))
        crosshair.move(to: NSPoint(x: center.x, y: center.y - 10))
        crosshair.line(to: NSPoint(x: center.x, y: center.y + 10))
        NSColor.systemBlue.setStroke()
        crosshair.lineWidth = 1
        crosshair.stroke()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)).fill()

        let coordinateText = "x \(Int(globalPoint.x))   y \(Int(globalPoint.y))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let textSize = coordinateText.size(withAttributes: attributes)
        coordinateText.draw(
            at: NSPoint(x: frame.midX - textSize.width / 2, y: frame.minY + 7),
            withAttributes: attributes
        )
    }
}

private struct ScreenshotGlassLabel: View {
    let text: String
    let usesMonospacedDigits: Bool

    var body: some View {
        Group {
            if usesMonospacedDigits {
                Text(text)
                    .font(AppFont.micro.monospacedDigit().weight(.medium))
            } else {
                Text(text)
                    .font(AppFont.caption.weight(.medium))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, usesMonospacedDigits ? 8 : 12)
        .padding(.vertical, usesMonospacedDigits ? 5 : 7)
        .marlaGlassSurface(cornerRadius: usesMonospacedDigits ? 6 : 8)
        .fixedSize()
    }
}
