import AppKit
import Foundation
import MarlaCore

enum ScreenshotTranslationOverlayError: LocalizedError {
    case complexBackground
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .complexBackground:
            "原图背景过于复杂，无法可靠遮住原文字。"
        case .renderingFailed:
            "无法生成原位译文画面。"
        }
    }
}

enum InPlaceOverlayStage: Equatable {
    case recognizing
    case translating
    case translated(renderedBlockCount: Int, omittedBlockCount: Int)
    case failed(String)
}

@MainActor
final class ScreenshotTranslationOverlayCoordinator: NSObject, NSWindowDelegate {
    private var panel: InPlaceTranslationPanel?
    private var contentView: InPlaceTranslationOverlayView?
    private var escapeMonitor: ScreenshotEscapeMonitor?
    private var onCancel: (() -> Void)?
    private var onTransfer: ((UUID) -> Bool)?
    private var chromeState: InPlaceChromeState?
    private(set) var activeRequestID: UUID?
    private(set) var stage: InPlaceOverlayStage?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    var isPresented: Bool { panel?.isVisible == true }
    var presentedFrame: CGRect? {
        guard let panel, let contentView else { return nil }
        return panel.convertToScreen(contentView.convert(contentView.bounds, to: nil))
    }
    var chromeFrame: CGRect? { panel?.frame }
    var canTransfer: Bool { chromeState?.canTransfer == true }
    var panelIdentity: ObjectIdentifier? { panel.map(ObjectIdentifier.init) }

    func presentWaiting(
        capture: CapturedScreenshot,
        requestID: UUID,
        onCancel: @escaping () -> Void,
        onTransfer: ((UUID) -> Bool)? = nil
    ) {
        dismiss(notifyCancellation: true)
        let contentView = InPlaceTranslationOverlayView(
            frame: CGRect(origin: .zero, size: capture.globalRect.size),
            image: capture.image
        )
        let chromeState = InPlaceChromeState()
        let container = InPlaceChromeContainer(
            captureView: contentView, state: chromeState,
            onClose: { [weak self] in self?.close() },
            onTransfer: { [weak self] in self?.transferToWindow(for: requestID) }
        )
        let windowFrame = InPlaceChromeGeometry.windowFrame(for: capture.globalRect)
        let panel = InPlaceTranslationPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.contentView = container
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.acceptsMouseMovedEvents = true
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.setFrame(windowFrame, display: true)

        self.panel = panel
        self.contentView = contentView
        self.onCancel = onCancel
        self.onTransfer = onTransfer
        self.chromeState = chromeState
        activeRequestID = requestID
        stage = .recognizing

        let escapeMonitor = ScreenshotEscapeMonitor { [weak self] in self?.close() }
        self.escapeMonitor = escapeMonitor
        escapeMonitor.install()
        panel.orderFrontRegardless()
    }

    @discardableResult
    func updateStage(_ newStage: InPlaceOverlayStage, for requestID: UUID) -> Bool {
        guard requestID == activeRequestID, let contentView else { return false }
        stage = newStage
        switch newStage {
        case .translated: break
        default: chromeState?.canTransfer = false
        }
        contentView.update(stage: newStage)
        return true
    }

    @discardableResult
    func apply(layout: InPlaceOverlayLayout, for requestID: UUID) throws -> Bool {
        guard requestID == activeRequestID, let contentView else { return false }
        let result = try contentView.apply(layout: layout)
        let newStage = InPlaceOverlayStage.translated(
            renderedBlockCount: result.renderedSourceBlockCount,
            omittedBlockCount: layout.sourceBlockCount - result.renderedSourceBlockCount
        )
        stage = newStage
        contentView.update(stage: newStage)
        return true
    }

    @discardableResult
    func showFailure(_ message: String, for requestID: UUID) -> Bool {
        updateStage(.failed(message), for: requestID)
    }

    func close() {
        dismiss(notifyCancellation: true)
    }

    func enableTransfer(for requestID: UUID) {
        guard requestID == activeRequestID, case .translated = stage, onTransfer != nil else { return }
        chromeState?.canTransfer = true
    }

    @discardableResult
    func transferToWindow(for requestID: UUID) -> Bool {
        guard requestID == activeRequestID, case .translated = stage,
              canTransfer, let onTransfer, onTransfer(requestID) else { return false }
        // A successful handoff keeps the completed text session; it is not cancellation.
        dismiss(notifyCancellation: false)
        return true
    }

    func setChromeProximityForUIAutomation(_ isNear: Bool) {
        chromeState?.fixtureProximity = isNear
    }

    func windowWillClose(_ notification: Notification) {
        dismiss(notifyCancellation: true)
    }

    @objc private func applicationWillTerminate() {
        dismiss(notifyCancellation: true)
    }

    private func dismiss(notifyCancellation: Bool) {
        let cancellation = onCancel
        onCancel = nil
        onTransfer = nil
        chromeState = nil
        activeRequestID = nil
        stage = nil
        escapeMonitor?.remove()
        escapeMonitor = nil
        panel?.orderOut(nil)
        panel?.delegate = nil
        panel = nil
        contentView = nil
        if notifyCancellation {
            cancellation?()
        }
    }
}

@MainActor
private final class InPlaceTranslationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class InPlaceTranslationOverlayView: NSView {
    private final class StatusView: NSView {
        private let progress = NSProgressIndicator()
        private let label = NSTextField(labelWithString: "")

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.cornerRadius = 6
            layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor

            progress.style = .spinning
            progress.controlSize = .small
            progress.frame = CGRect(x: 8, y: 8, width: 14, height: 14)
            addSubview(progress)

            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .white
            label.lineBreakMode = .byTruncatingTail
            label.frame = CGRect(x: 28, y: 6, width: 110, height: 18)
            addSubview(label)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        func update(stage: InPlaceOverlayStage, availableWidth: CGFloat) {
            switch stage {
            case .recognizing:
                configure(text: "正在识别", showsProgress: true, availableWidth: availableWidth)
            case .translating:
                configure(text: "正在翻译", showsProgress: true, availableWidth: availableWidth)
            case .translated:
                isHidden = true
                progress.stopAnimation(nil)
            case let .failed(message):
                configure(text: message, showsProgress: false, availableWidth: availableWidth)
                toolTip = message
            }
        }

        private func configure(text: String, showsProgress: Bool, availableWidth: CGFloat) {
            isHidden = false
            label.stringValue = text
            let reducesMotion = ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
                || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            progress.isHidden = !showsProgress || reducesMotion
            if progress.isHidden {
                progress.stopAnimation(nil)
            } else {
                progress.startAnimation(nil)
            }
            let labelX: CGFloat = progress.isHidden ? 10 : 28
            let measuredWidth = ceil(
                (text as NSString).size(
                    withAttributes: [.font: label.font ?? NSFont.systemFont(ofSize: 12, weight: .medium)]
                ).width
            )
            let width = min(max(64, measuredWidth + labelX + 18), max(64, availableWidth))
            frame.size = CGSize(width: width, height: 30)
            label.frame = CGRect(x: labelX, y: 6, width: max(1, width - labelX - 10), height: 18)
            setAccessibilityLabel(text)
        }
    }

    private let sourceImage: CGImage
    private var displayImage: NSImage
    private var renderedBlocks: [RestoredScreenshotBlock] = []
    private let statusView = StatusView(frame: .zero)

    init(frame: CGRect, image: CGImage) {
        sourceImage = image
        displayImage = NSImage(cgImage: image, size: frame.size)
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("原位翻译，正在识别截图结构")

        addSubview(statusView)
        layoutControls()
        update(stage: .recognizing)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        displayImage.draw(
            in: bounds,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        for item in renderedBlocks {
            draw(item)
        }
        drawTableGrids(in: renderedBlocks)
    }

    func apply(layout: InPlaceOverlayLayout) throws -> RestoredScreenshot {
        let result = try ScreenshotBackgroundRestorer.restore(image: sourceImage, layout: layout)
        displayImage = NSImage(cgImage: result.image, size: bounds.size)
        renderedBlocks = result.blocks
        needsDisplay = true
        setAccessibilityLabel(
            "原位翻译结果，共覆盖 \(result.renderedSourceBlockCount) 个文字块，\(layout.sourceBlockCount - result.renderedSourceBlockCount) 个区域保留原图"
        )
        setAccessibilityValue(result.blocks.map(\.block.text).joined(separator: "\n"))
        return result
    }

    func update(stage: InPlaceOverlayStage) {
        statusView.update(stage: stage, availableWidth: max(64, bounds.width - 56))
        switch stage {
        case .recognizing:
            setAccessibilityLabel("原位翻译，正在识别截图结构")
        case .translating:
            setAccessibilityLabel("原位翻译，正在生成译文")
        case .translated:
            break
        case let .failed(message):
            setAccessibilityLabel("原位翻译失败：\(message)")
        }
        layoutControls()
    }

    private func draw(_ item: RestoredScreenshotBlock) {
        let block = item.block
        let attributedText = block.attributedText ?? fallbackAttributedText(for: block)
        let drawableText = InPlaceMarkdownAttributedText.preparedForDrawing(
            attributedText,
            textColor: item.appearance.textColor
        )
        var drawingFrame = block.tableCell == nil
            ? block.frame.insetBy(dx: 2, dy: 1)
            : block.frame.insetBy(dx: 6, dy: 3)
        if block.tableCell != nil {
            let measured = InPlaceMarkdownAttributedText.measuredSize(
                attributedText,
                width: drawingFrame.width
            )
            drawingFrame.origin.y += max(0, (drawingFrame.height - measured.height) / 2)
            drawingFrame.size.height = min(drawingFrame.height, measured.height)
        }
        drawCodeBlockBackgrounds(
            for: attributedText,
            in: drawingFrame,
            textColor: item.appearance.textColor
        )
        drawableText.draw(
            with: drawingFrame,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
    }

    private func drawCodeBlockBackgrounds(
        for attributedText: NSAttributedString,
        in drawingFrame: CGRect,
        textColor: NSColor
    ) {
        let rects = InPlaceMarkdownAttributedText.codeBlockRects(
            in: attributedText,
            width: drawingFrame.width
        )
        for textKitRect in rects {
            let blockRect = CGRect(
                x: drawingFrame.minX,
                y: drawingFrame.maxY - textKitRect.maxY - 2,
                width: drawingFrame.width,
                height: textKitRect.height + 4
            ).intersection(drawingFrame)
            guard !blockRect.isNull, !blockRect.isEmpty else { continue }
            let path = NSBezierPath(roundedRect: blockRect, xRadius: 4, yRadius: 4)
            textColor.withAlphaComponent(0.085).setFill()
            path.fill()
            textColor.withAlphaComponent(0.16).setStroke()
            path.lineWidth = 0.75
            path.stroke()
        }
    }

    private func fallbackAttributedText(for block: InPlaceOverlayBlock) -> NSAttributedString {
        let font = block.usesMonospacedFont
            ? NSFont.monospacedSystemFont(ofSize: block.fontSize, weight: block.fontWeight)
            : NSFont.systemFont(ofSize: block.fontSize, weight: block.fontWeight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 0
        paragraph.alignment = block.tableCell?.alignment.appKitValue ?? .left
        return NSAttributedString(
            string: block.text,
            attributes: [.font: font, .paragraphStyle: paragraph]
        )
    }

    private func drawTableGrids(in items: [RestoredScreenshotBlock]) {
        var orderedKeys: [[String]] = []
        var groups: [[String]: [RestoredScreenshotBlock]] = [:]
        for item in items where item.block.tableCell != nil {
            if groups[item.block.sourceGroupKey] == nil {
                orderedKeys.append(item.block.sourceGroupKey)
            }
            groups[item.block.sourceGroupKey, default: []].append(item)
        }

        for key in orderedKeys {
            guard let group = groups[key],
                  let first = group.first,
                  let metadata = first.block.tableCell
            else { continue }
            let tableFrame = group.dropFirst().reduce(first.block.sourceFrame) {
                $0.union($1.block.sourceFrame)
            }
            let gridColor = first.appearance.textColor.withAlphaComponent(0.18)
            gridColor.setStroke()
            let path = NSBezierPath(rect: tableFrame)
            path.lineWidth = 0.75

            for column in 1..<metadata.columnCount {
                guard let cell = group.first(where: { $0.block.tableCell?.row == 0 && $0.block.tableCell?.column == column }) else {
                    continue
                }
                path.move(to: CGPoint(x: cell.block.sourceFrame.minX, y: tableFrame.minY))
                path.line(to: CGPoint(x: cell.block.sourceFrame.minX, y: tableFrame.maxY))
            }
            for row in 1..<metadata.rowCount {
                guard let cell = group.first(where: { $0.block.tableCell?.row == row && $0.block.tableCell?.column == 0 }) else {
                    continue
                }
                path.move(to: CGPoint(x: tableFrame.minX, y: cell.block.sourceFrame.maxY))
                path.line(to: CGPoint(x: tableFrame.maxX, y: cell.block.sourceFrame.maxY))
            }
            path.stroke()
        }
    }

    private func layoutControls() {
        let top = max(8, bounds.maxY - 38)
        statusView.frame.origin = CGPoint(
            x: max(8, bounds.maxX - 50 - statusView.frame.width),
            y: top
        )
    }
}

struct ScreenshotBackgroundAppearance {
    let color: NSColor
    let textColor: NSColor
    let variation: CGFloat
}

enum ScreenshotBackgroundSampler {
    static func robustAppearance(colors: [NSColor]) -> ScreenshotBackgroundAppearance {
        let converted = colors.compactMap { $0.usingColorSpace(.deviceRGB) }
        guard !converted.isEmpty else {
            return ScreenshotBackgroundAppearance(color: .windowBackgroundColor, textColor: .labelColor, variation: 0)
        }
        let red = median(converted.map(\.redComponent))
        let green = median(converted.map(\.greenComponent))
        let blue = median(converted.map(\.blueComponent))
        let deviations = converted.map { color in
            let deltaR = color.redComponent - red
            let deltaG = color.greenComponent - green
            let deltaB = color.blueComponent - blue
            return sqrt((deltaR * deltaR + deltaG * deltaG + deltaB * deltaB) / 3)
        }.sorted()
        let variation = deviations[Int(floor(Double(deviations.count - 1) * 0.75))]
        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        return ScreenshotBackgroundAppearance(
            color: NSColor(deviceRed: red, green: green, blue: blue, alpha: 1),
            textColor: luminance > 0.53 ? .black : .white,
            variation: variation
        )
    }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
