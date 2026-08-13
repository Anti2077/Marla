import AppKit
import Foundation
import SwiftUI

final class ScreenshotSelectionWindow: NSWindow {
    private let onCancel: () -> Void

    init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool,
        onCancel: @escaping () -> Void = {}
    ) {
        self.onCancel = onCancel
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // AppKit can route Escape as a key equivalent or cancelOperation rather
    // than delivering keyDown to the content view. Keep a window-owned path
    // so cancellation does not depend on first-responder identity.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard ScreenshotEscapeMonitor.isCancelKeyCode(event.keyCode) else {
            return super.performKeyEquivalent(with: event)
        }
        onCancel()
        return true
    }

    // A borderless overlay can receive the key event through NSWindow's
    // dispatch path without ever asking the first responder to handle it.
    // Catch Escape here as well so cancellation remains independent of the
    // hosted SwiftUI view and of AppKit key-equivalent routing details.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           ScreenshotEscapeMonitor.isCancelKeyCode(event.keyCode) {
            onCancel()
            return
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}

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

enum ScreenshotError: LocalizedError {
    case cancelled
    case invalidRegion
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .cancelled: "已取消截图。"
        case .invalidRegion: "选取的区域太小。"
        case .captureFailed: "无法捕获选取区域，请检查屏幕录制权限。"
        }
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

final class ScreenshotSelectionSession {
    private(set) var startPoint: NSPoint?
    private(set) var currentPoint: NSPoint?
    private(set) var pointerPoint: NSPoint?
    let magnifierSources: [ScreenshotMagnifierSource]
    private var redrawCallbacks: [() -> Void] = []
    private var hasFinished = false
    private let onFinish: (NSRect, Bool) -> Void

    init(
        magnifierSources: [ScreenshotMagnifierSource] = [],
        onFinish: @escaping (NSRect, Bool) -> Void
    ) {
        self.magnifierSources = magnifierSources
        self.onFinish = onFinish
    }

    var selectionRect: NSRect {
        guard let startPoint, let currentPoint else { return .zero }
        return NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }

    func attach(_ view: ScreenshotSelectionView) {
        redrawCallbacks.append { [weak view] in view?.needsDisplay = true }
    }

    func begin(at point: NSPoint) {
        guard !hasFinished else { return }
        pointerPoint = point
        startPoint = point
        currentPoint = point
        redraw()
    }

    func move(to point: NSPoint) {
        guard startPoint != nil, !hasFinished else { return }
        pointerPoint = point
        currentPoint = point
        redraw()
    }

    func hover(at point: NSPoint) {
        guard !hasFinished else { return }
        pointerPoint = point
        redraw()
    }

    func confirm(at point: NSPoint) {
        move(to: point)
        finish(cancelled: selectionRect.width <= 4 || selectionRect.height <= 4)
    }

    func cancel() {
        finish(cancelled: true)
    }

    private func redraw() {
        redrawCallbacks.forEach { $0() }
    }

    private func finish(cancelled: Bool) {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish(selectionRect, cancelled)
    }
}

final class ScreenshotSelectionView: NSView {
    private let session: ScreenshotSelectionSession
    private let frozenSource: ScreenshotMagnifierSource?
    private let hintView: NSHostingView<ScreenshotGlassLabel>
    private let sizeView: NSHostingView<ScreenshotGlassLabel>

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
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(hintView)
        addSubview(sizeView)
        sizeView.isHidden = true
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
        session.begin(at: window.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        session.move(to: window.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseUp(with event: NSEvent) {
        guard let window else { return }
        session.confirm(at: window.convertPoint(toScreen: event.locationInWindow))
    }

    override func rightMouseDown(with event: NSEvent) {
        session.cancel()
    }

    override func keyDown(with event: NSEvent) {
        if Self.isCancelKeyCode(event.keyCode) { session.cancel() }
    }

    static func isCancelKeyCode(_ keyCode: UInt16) -> Bool {
        keyCode == 53
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
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
                y: bounds.maxY - size.height - 16,
                width: size.width,
                height: size.height
            )
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
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: rect)
            border.lineWidth = 1
            border.stroke()
            let length: CGFloat = 10
            let corners = [
                (NSPoint(x: rect.minX, y: rect.minY), NSPoint(x: rect.minX + length, y: rect.minY), NSPoint(x: rect.minX, y: rect.minY + length)),
                (NSPoint(x: rect.maxX, y: rect.minY), NSPoint(x: rect.maxX - length, y: rect.minY), NSPoint(x: rect.maxX, y: rect.minY + length)),
                (NSPoint(x: rect.minX, y: rect.maxY), NSPoint(x: rect.minX + length, y: rect.maxY), NSPoint(x: rect.minX, y: rect.maxY - length)),
                (NSPoint(x: rect.maxX, y: rect.maxY), NSPoint(x: rect.maxX - length, y: rect.maxY), NSPoint(x: rect.maxX, y: rect.maxY - length))
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
        drawMagnifier(in: window)
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
