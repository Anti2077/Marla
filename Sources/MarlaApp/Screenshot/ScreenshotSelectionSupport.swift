import AppKit
import Foundation
import MarlaCore
import ScreenCaptureKit
import SwiftUI

final class ScreenshotSelectionWindow: NSWindow {
    private let onCancel: () -> Void
    private let onKeyEvent: (NSEvent) -> Bool

    init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool,
        onCancel: @escaping () -> Void = {},
        onKeyEvent: @escaping (NSEvent) -> Bool = { _ in false }
    ) {
        self.onCancel = onCancel
        self.onKeyEvent = onKeyEvent
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard ScreenshotEscapeMonitor.isCancelKeyCode(event.keyCode) else {
            return super.performKeyEquivalent(with: event)
        }
        onCancel()
        return true
    }

    override func sendEvent(_ event: NSEvent) {
        if (event.type == .keyDown || event.type == .keyUp), onKeyEvent(event) { return }
        if event.type == .keyDown, ScreenshotEscapeMonitor.isCancelKeyCode(event.keyCode) {
            onCancel()
            return
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
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

enum ScreenshotSelectionMode: Equatable {
    case region
    case window
}

enum ScreenshotSelectionLayout {
    static let defaultTopHintOffset: CGFloat = 28
    static let safeAreaSpacing: CGFloat = 12

    static func topHintOriginY(
        bounds: CGRect,
        hintHeight: CGFloat,
        safeAreaTopInset: CGFloat
    ) -> CGFloat {
        let topOffset = max(
            defaultTopHintOffset,
            max(0, safeAreaTopInset) + safeAreaSpacing
        )
        return bounds.maxY - hintHeight - topOffset
    }
}

struct ScreenshotWindowTarget: Identifiable {
    let id: CGWindowID
    let frame: CGRect
    let title: String
    let processID: pid_t
    let bundleIdentifier: String?
    let window: SCWindow?

    init(
        id: CGWindowID,
        frame: CGRect,
        title: String = "",
        processID: pid_t = 0,
        bundleIdentifier: String? = nil,
        window: SCWindow? = nil
    ) {
        self.id = id
        self.frame = frame
        self.title = title
        self.processID = processID
        self.bundleIdentifier = bundleIdentifier
        self.window = window
    }
}

enum ScreenshotWindowTargeting {
    static func isEligible(
        windowID: CGWindowID,
        frame: CGRect,
        isOnScreen: Bool,
        windowLayer: Int,
        ownerProcessID: pid_t?,
        excludingProcessID processID: pid_t
    ) -> Bool {
        windowID != 0
            && isOnScreen
            && windowLayer == 0
            && frame.width > 0
            && frame.height > 0
            && ownerProcessID != nil
            && ownerProcessID != processID
    }

    static func targets(
        from content: SCShareableContent,
        excludingProcessID processID: pid_t,
        primaryScreenMaxY: CGFloat
    ) -> [ScreenshotWindowTarget] {
        content.windows.compactMap { window in
            let owningApplication = window.owningApplication
            guard isEligible(
                    windowID: window.windowID,
                    frame: window.frame,
                    isOnScreen: window.isOnScreen,
                    windowLayer: window.windowLayer,
                    ownerProcessID: owningApplication?.processID,
                    excludingProcessID: processID
                  ),
                  let owningProcessID = owningApplication?.processID
            else { return nil }
            return ScreenshotWindowTarget(
                id: window.windowID,
                frame: appKitFrame(
                    screenCaptureFrame: window.frame,
                    primaryScreenMaxY: primaryScreenMaxY
                ),
                title: window.title ?? "",
                processID: owningProcessID,
                bundleIdentifier: owningApplication?.bundleIdentifier,
                window: window
            )
        }
    }

    static func appKitFrame(
        screenCaptureFrame: CGRect,
        primaryScreenMaxY: CGFloat
    ) -> CGRect {
        CGRect(
            x: screenCaptureFrame.minX,
            y: primaryScreenMaxY - screenCaptureFrame.maxY,
            width: screenCaptureFrame.width,
            height: screenCaptureFrame.height
        )
    }

    static func hitTest(
        point: CGPoint,
        in targets: [ScreenshotWindowTarget]
    ) -> ScreenshotWindowTarget? {
        targets.first(where: { $0.frame.contains(point) })
    }

    static func visibleBounds(for sources: [ScreenshotMagnifierSource]) -> CGRect {
        sources.reduce(into: CGRect.null) { result, source in
            result = result.union(source.screenFrame)
        }
    }

    static func clamped(
        rect: CGRect,
        to bounds: CGRect
    ) -> CGRect {
        guard !bounds.isNull, !bounds.isEmpty else { return rect }
        let width = min(rect.width, bounds.width)
        let height = min(rect.height, bounds.height)
        let x = min(max(rect.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(rect.minY, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

struct ScreenshotSelectionResult {
    let globalRect: CGRect
    let mode: ScreenshotSelectionMode
    let windowTarget: ScreenshotWindowTarget?
    let ocrProvider: OCRProviderKind
    let cancelled: Bool
}

enum ScreenshotOCRProviderOption: CaseIterable, Identifiable {
    case vision
    case ollamaGLMOCR
    case glmOCR

    var id: OCRProviderKind { provider }

    var provider: OCRProviderKind {
        switch self {
        case .vision: .vision
        case .ollamaGLMOCR: .ollamaGLMOCR
        case .glmOCR: .glmOCR
        }
    }

    var shortcut: String {
        switch self {
        case .vision: "1"
        case .ollamaGLMOCR: "2"
        case .glmOCR: "3"
        }
    }

    var shortLabel: String {
        switch self {
        case .vision: "Vision"
        case .ollamaGLMOCR: "本机 OCR"
        case .glmOCR: "云端 GLM"
        }
    }

    static func option(for provider: OCRProviderKind) -> Self {
        switch provider {
        case .vision: .vision
        case .ollamaGLMOCR: .ollamaGLMOCR
        case .glmOCR: .glmOCR
        }
    }

    static func provider(forKey key: String) -> OCRProviderKind? {
        allCases.first(where: { $0.shortcut == key })?.provider
    }
}

struct ScreenshotOCRPicker: View {
    let selectedProvider: OCRProviderKind
    let onSelect: (OCRProviderKind) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ScreenshotOCRProviderOption.allCases) { option in
                Button {
                    onSelect(option.provider)
                } label: {
                    HStack(spacing: 4) {
                        Text(option.shortcut)
                            .font(AppFont.micro.monospacedDigit().weight(.semibold))
                        Text(option.shortLabel)
                            .font(AppFont.micro.weight(.medium))
                    }
                    .foregroundStyle(option.provider == selectedProvider ? .white : .white.opacity(0.78))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(
                        option.provider == selectedProvider
                            ? Color.accentColor.opacity(0.85)
                            : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("OCR 服务：\(option.shortLabel)")
                .accessibilityHint("按 \(option.shortcut) 切换")
                .accessibilityAddTraits(option.provider == selectedProvider ? .isSelected : [])
            }
        }
        .padding(4)
        .marlaGlassSurface(cornerRadius: 8)
        .fixedSize()
    }
}
