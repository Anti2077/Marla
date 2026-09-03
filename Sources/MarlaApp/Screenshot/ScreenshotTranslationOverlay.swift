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
    var presentedFrame: CGRect? { panel?.frame }
    var panelIdentity: ObjectIdentifier? { panel.map(ObjectIdentifier.init) }

    func presentWaiting(
        capture: CapturedScreenshot,
        requestID: UUID,
        onCancel: @escaping () -> Void
    ) {
        dismiss(notifyCancellation: true)
        let contentView = InPlaceTranslationOverlayView(
            frame: CGRect(origin: .zero, size: capture.globalRect.size),
            image: capture.image,
            onClose: { [weak self] in self?.close() }
        )
        let panel = InPlaceTranslationPanel(
            contentRect: capture.globalRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.contentView = contentView
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.setFrame(capture.globalRect, display: true)

        self.panel = panel
        self.contentView = contentView
        self.onCancel = onCancel
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

    func windowWillClose(_ notification: Notification) {
        dismiss(notifyCancellation: true)
    }

    @objc private func applicationWillTerminate() {
        dismiss(notifyCancellation: true)
    }

    private func dismiss(notifyCancellation: Bool) {
        let cancellation = onCancel
        onCancel = nil
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
    override var canBecomeKey: Bool { false }
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
    private let closeButton: ClosureButton

    init(frame: CGRect, image: CGImage, onClose: @escaping () -> Void) {
        sourceImage = image
        displayImage = NSImage(cgImage: image, size: frame.size)
        closeButton = ClosureButton(frame: .zero)
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("原位翻译，正在识别截图结构")

        addSubview(statusView)
        closeButton.onPress = onClose
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭原位翻译")
        closeButton.imagePosition = .imageOnly
        closeButton.isBordered = false
        closeButton.contentTintColor = .white
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 15
        closeButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.62).cgColor
        closeButton.toolTip = "关闭原位翻译"
        closeButton.setAccessibilityLabel("关闭原位翻译")
        addSubview(closeButton)
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
        let font = block.usesMonospacedFont
            ? NSFont.monospacedSystemFont(ofSize: block.fontSize, weight: block.fontWeight)
            : NSFont.systemFont(ofSize: block.fontSize, weight: block.fontWeight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 0
        paragraph.alignment = block.tableCell?.alignment.appKitValue ?? .left
        var drawingFrame = block.tableCell == nil
            ? block.frame.insetBy(dx: 2, dy: 1)
            : block.frame.insetBy(dx: 6, dy: 3)
        if block.tableCell != nil {
            let measured = (block.text as NSString).boundingRect(
                with: CGSize(width: drawingFrame.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph]
            )
            drawingFrame.origin.y += max(0, (drawingFrame.height - ceil(measured.height)) / 2)
            drawingFrame.size.height = min(drawingFrame.height, ceil(measured.height))
        }
        (block.text as NSString).draw(
            with: drawingFrame,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .foregroundColor: item.appearance.textColor,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func drawTableGrids(in items: [RestoredScreenshotBlock]) {
        var orderedIDs: [String] = []
        var groups: [String: [RestoredScreenshotBlock]] = [:]
        for item in items where item.block.tableCell != nil {
            if groups[item.block.id] == nil {
                orderedIDs.append(item.block.id)
            }
            groups[item.block.id, default: []].append(item)
        }

        for id in orderedIDs {
            guard let group = groups[id],
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
        closeButton.frame = CGRect(x: max(8, bounds.maxX - 38), y: top, width: 30, height: 30)
        statusView.frame.origin = CGPoint(
            x: max(8, closeButton.frame.minX - statusView.frame.width - 6),
            y: top
        )
    }
}

@MainActor
private final class ClosureButton: NSButton {
    var onPress: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(press)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func press() { onPress?() }
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
