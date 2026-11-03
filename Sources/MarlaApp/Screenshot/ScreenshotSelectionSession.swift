import AppKit
import Foundation
import MarlaCore

@MainActor
final class ScreenshotSelectionSession: NSObject {
    private(set) var startPoint: NSPoint?
    private(set) var currentPoint: NSPoint?
    private(set) var pointerPoint: NSPoint?
    private(set) var isConfirming = false
    private(set) var confirmationProgress: CGFloat = 0
    private(set) var selectionMode: ScreenshotSelectionMode = .region
    private(set) var elementChoice = ScreenshotElementChoice()
    private var scroll = ScreenshotLevelScroll()
    private var transition = ScreenshotSelectionTransition()
    private var transitionTimer: Timer?
    private var pressedPoint: CGPoint?
    private var hoverSettlement: Task<Void, Never>?
    private var resolvedPointer: CGPoint?
    private let primaryScreenMaxY: CGFloat
    private let providerAccessibility = ScreenshotProviderAccessibility()
    private var elementQuery: ScreenshotElementQueryCoordinator.Query = ScreenshotElementQuery.query
    private lazy var elementQueries = ScreenshotElementQueryCoordinator(query: elementQuery) { [weak self] result in
        self?.applyElementResult(result)
    }
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
        selectionMode = allowsWindowSelection ? .window : .region
        primaryScreenMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        onSelectionFinish = nil
        showsOCRProviderPicker = false
        self.reducesMotion = reducesMotion ?? (
            ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
                || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        self.confirmationDuration = max(0, confirmationDuration)
        self.onFinish = onFinish
        super.init()
        let provider = providerAccessibility
        self.elementQuery = { request, cancellation in provider.query(request, cancellation: cancellation) }
    }

    init(
        magnifierSources: [ScreenshotMagnifierSource] = [],
        windowTargets: [ScreenshotWindowTarget] = [],
        initialOCRProvider: OCRProviderKind = .vision,
        allowsWindowSelection: Bool = true,
        showsOCRProviderPicker: Bool = true,
        reducesMotion: Bool? = nil,
        confirmationDuration: TimeInterval = MarlaMotion.screenshotConfirmationDuration,
        elementQuery: ScreenshotElementQueryCoordinator.Query? = nil,
        onSelectionFinish: @escaping (ScreenshotSelectionResult) -> Void
    ) {
        self.magnifierSources = magnifierSources
        self.windowTargets = windowTargets
        visibleBounds = ScreenshotWindowTargeting.visibleBounds(for: magnifierSources)
        selectedOCRProvider = initialOCRProvider
        self.allowsWindowSelection = allowsWindowSelection
        selectionMode = allowsWindowSelection ? .window : .region
        primaryScreenMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        onFinish = { _, _ in }
        self.onSelectionFinish = onSelectionFinish
        self.showsOCRProviderPicker = showsOCRProviderPicker
        self.reducesMotion = reducesMotion ?? (
            ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
                || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        self.confirmationDuration = max(0, confirmationDuration)
        super.init()
        let provider = providerAccessibility
        self.elementQuery = elementQuery ?? { request, cancellation in provider.query(request, cancellation: cancellation) }
    }

    let showsOCRProviderPicker: Bool

    var selectionRect: NSRect {
        if selectionMode == .window { return elementChoice.selected?.frame ?? .zero }
        guard let startPoint, let currentPoint else { return .zero }
        return NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }

    var displayedSelectionRect: CGRect {
        if selectionMode == .region { return selectionRect }
        return transition.displayed
    }

    var selectionHint: String {
        if !allowsWindowSelection { return "拖动框选要翻译的区域 · Space 平移 · Esc 取消" }
        if selectionMode == .region { return "拖动框选 · 拖动时 Space 平移 · Space 切换吸附 · Esc 取消" }
        return "元素吸附 · 滚轮上滑扩大 / 下滑缩小 · 单击确认或拖动框选 · Space 手动 · Esc 取消"
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
        guard !hasFinished, !isConfirming else { return }
        selectionMode = .region
        hoverSettlement?.cancel()
        hoverSettlement = nil
        elementQueries.invalidate()
        elementChoice.reset()
        transitionTimer?.invalidate()
        transitionTimer = nil
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
        guard !hasFinished, !isConfirming, pressedPoint == nil else { return }
        let previousPoint = pointerPoint
        pointerPoint = point
        guard selectionMode == .window else { redraw(); return }
        guard previousPoint != point else { return }
        hoverSettlement?.cancel()
        elementQueries.invalidate()
        // The first visible hit is immediate. Subsequent targets wait for a stable pointer,
        // so traversing dense text does not animate through every intermediate element.
        if elementChoice.path == nil {
            settleHover(at: point)
        } else {
            hoverSettlement = Task { [weak self] in
                try? await Task.sleep(for: .seconds(MarlaMotion.screenshotHoverDwellDuration))
                guard !Task.isCancelled, let self, pointerPoint == point else { return }
                settleHover(at: point)
            }
        }
    }

    func settleHover(at point: CGPoint) {
        guard !hasFinished, !isConfirming, pressedPoint == nil, selectionMode == .window else { return }
        hoverSettlement?.cancel()
        hoverSettlement = nil
        pointerPoint = point
        let target = ScreenshotWindowTargeting.hitTest(point: point, in: windowTargets)
        if resolvedPointer != point || highlightedWindow?.id != target?.id {
            // Pointer movement starts a fresh hit. Only stationary refinements preserve a wheel choice.
            let cached = elementChoice.path
            elementChoice.reset()
            if let target, cached?.windowID == target.id {
                // Reuse only still-containing geometry while the newest hit is in flight.
                // Resetting to the full window on every pixel causes a visible expansion/shrink flash.
                elementChoice.replace(.make(windowID: target.id, windowFrame: target.frame,
                    visibleBounds: visibleBounds, point: point,
                    leafToRoot: cached?.candidates.filter { $0.frame.contains(point) } ?? []))
            } else {
                elementChoice.replace(target.map { fallback(for: $0, at: point) })
            }
        }
        highlightedWindow = target
        updateTransition()
        if let target, resolvedPointer != point {
            elementQueries.hover(window: target, point: point, visibleBounds: visibleBounds,
                                 primaryScreenMaxY: primaryScreenMaxY)
        } else if target == nil {
            elementQueries.invalidate()
        }
        resolvedPointer = point
        redraw()
    }

    private func fallback(for window: ScreenshotWindowTarget, at point: CGPoint) -> ScreenshotElementPath {
        .make(windowID: window.id, windowFrame: window.frame, visibleBounds: visibleBounds,
              point: point, leafToRoot: [])
    }

    func applyElementResult(_ result: ScreenshotElementQueryResult) {
        if ProcessInfo.processInfo.environment["MARLA_UI_TEST_ELEMENT_DIAGNOSTICS"] == "1" {
            print("Element query: provider=\(highlightedWindow?.bundleIdentifier ?? "unknown") refined=\(result.request.refined) elapsedMs=\(Int(result.elapsedMilliseconds)) nodes=\(result.visitedNodes) candidates=\(result.path.candidates.count) status=\(result.termination) roles=\(result.path.candidates.map(\.role).joined(separator: ","))")
        }
        guard !hasFinished, !isConfirming, pressedPoint == nil, selectionMode == .window,
              highlightedWindow?.id == result.request.windowID, pointerPoint == result.request.point else { return }
        if ["windowChanged", "windowChangedOrPermissionRevoked", "permissionUnavailable"].contains(result.termination) {
            elementChoice.reset()
        }
        elementChoice.replace(result.path)
        updateTransition()
        redraw()
    }

    func pointerDown(at point: CGPoint) {
        guard !hasFinished, !isConfirming else { return }
        if selectionMode == .region { begin(at: point); return }
        settleHover(at: point)
        pressedPoint = point
        elementChoice.lock()
        elementQueries.invalidate()
    }

    func pointerDragged(to point: CGPoint) {
        guard !hasFinished, !isConfirming else { return }
        if selectionMode == .window, let pressedPoint {
            guard hypot(point.x - pressedPoint.x, point.y - pressedPoint.y) >= 4 else { return }
            begin(at: pressedPoint)
            self.pressedPoint = nil
        }
        move(to: point)
    }

    func pointerUp(at point: CGPoint) {
        guard !hasFinished, !isConfirming else { return }
        if selectionMode == .window, pressedPoint != nil {
            // No hit test here: confirmation must use the target locked on mouse-down.
            if selectionRect.width > 4, selectionRect.height > 4 { finish(cancelled: false) }
            else { elementChoice.reset(); pressedPoint = nil; hover(at: point) }
        } else {
            confirm(at: point)
        }
    }

    func scrollLevel(delta: CGFloat, precise: Bool, began: Bool = false,
                     momentum: Bool = false, ended: Bool = false, timestamp: TimeInterval) {
        guard !hasFinished, !isConfirming, pressedPoint == nil, selectionMode == .window else { return }
        let step = scroll.step(delta: delta, precise: precise, began: began, momentum: momentum,
                               ended: ended, timestamp: timestamp)
        guard step != 0 else { return }
        elementChoice.step(step)
        updateTransition()
        redraw()
    }

    private func updateTransition() {
        let reduced = reducesMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        transition.update(selectionRect, at: ProcessInfo.processInfo.systemUptime,
                          animated: !reduced && !isConfirming)
        if transition.isRunning, transitionTimer == nil {
            let timer = Timer(timeInterval: 1 / 120, target: self, selector: #selector(advanceTransition),
                              userInfo: nil, repeats: true)
            transitionTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else if !transition.isRunning {
            transitionTimer?.invalidate()
            transitionTimer = nil
        }
    }

    @objc private func advanceTransition() {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            transition.update(selectionRect, at: ProcessInfo.processInfo.systemUptime, animated: false)
        } else { transition.advance(at: ProcessInfo.processInfo.systemUptime) }
        redraw()
        if !transition.isRunning { transitionTimer?.invalidate(); transitionTimer = nil }
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
            if isConfirming || pressedPoint != nil { return true }
            if startPoint != nil {
                beginPanning()
            } else if allowsWindowSelection, !event.isARepeat {
                selectionMode = selectionMode == .window ? .region : .window
                hoverSettlement?.cancel()
                hoverSettlement = nil
                resolvedPointer = nil
                elementQueries.invalidate()
                elementChoice.reset()
                scroll = ScreenshotLevelScroll()
                transition.update(.zero, at: ProcessInfo.processInfo.systemUptime, animated: false)
                highlightedWindow = nil
                let point = pointerPoint ?? NSEvent.mouseLocation
                pointerPoint = nil
                hover(at: point)
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

    func tearDown() {
        hoverSettlement?.cancel()
        hoverSettlement = nil
        elementQueries.stop()
        let provider = providerAccessibility
        Task.detached(priority: .utility) { provider.stop() }
        transitionTimer?.invalidate()
        transitionTimer = nil
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        hasFinished = true
    }

    private func finish(cancelled: Bool) {
        guard !hasFinished else { return }
        let confirmedRect = selectionRect
        hasFinished = true
        hoverSettlement?.cancel()
        hoverSettlement = nil
        elementQueries.stop()
        let provider = providerAccessibility
        Task.detached(priority: .utility) { provider.stop() }
        transitionTimer?.invalidate()
        transitionTimer = nil
        pressedPoint = nil
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
                globalRect: confirmedRect,
                mode: selectionMode,
                windowTarget: highlightedWindow,
                ocrProvider: selectedOCRProvider,
                cancelled: cancelled
            ))
        } else {
            onFinish(confirmedRect, cancelled)
        }
    }
}

