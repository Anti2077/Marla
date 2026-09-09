import AppKit
import Combine
import Foundation
import MarlaCore
import SwiftUI
final class MarlaPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
@MainActor
final class ResultPanelHorizontalResizeHandleView: NSView {
    let edge: ResultPanelHorizontalResizeEdge
    private var dragStart: (point: NSPoint, frame: NSRect, visibleFrame: NSRect)?
    private var hoverTrackingArea: NSTrackingArea?
    private var isPointerInside = false
    private var sourceApplicationBeforeHover: NSRunningApplication?
    private var madePanelKeyForHover = false
    init(edge: ResultPanelHorizontalResizeEdge) {
        self.edge = edge
        super.init(frame: .zero)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var resizeCursor: NSCursor {
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition = edge == .left ? .left : .right
            return NSCursor.frameResize(position: position, directions: .all)
        }
        return .resizeLeftRight
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard !isHidden else { return }
        let cursorRect = bounds.intersection(visibleRect)
        guard !cursorRect.isEmpty else { return }
        addCursorRect(cursorRect, cursor: resizeCursor)
    }

    override func mouseEntered(with event: NSEvent) {
        isPointerInside = true
        prepareInactivePanelCursorRects()
    }

    override func mouseExited(with event: NSEvent) {
        isPointerInside = false
        if dragStart == nil {
            restoreSourceApplicationAfterHover()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        prepareInactivePanelCursorRects()
        let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
        let visibleFrame = window.screen?.visibleFrame
            ?? NSScreen.screens.first(where: { $0.frame.contains(screenPoint) })?.visibleFrame
            ?? window.frame
        dragStart = (screenPoint, window.frame, visibleFrame)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStart else { return }
        let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
        let frame = ResultPanelHorizontalResizeCalculator.resized(
            startFrame: dragStart.frame,
            currentFrame: window.frame,
            horizontalDelta: screenPoint.x - dragStart.point.x,
            edge: edge,
            visibleFrame: dragStart.visibleFrame
        )
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        if !isPointerInside {
            restoreSourceApplicationAfterHover()
        }
    }

    private func prepareInactivePanelCursorRects() {
        guard let window, !window.isKeyWindow else { return }
        if !NSApp.isActive {
            sourceApplicationBeforeHover = NSWorkspace.shared.frontmostApplication
        }
        // A nonactivating panel can become key without activating Marla.
        window.makeKey()
        madePanelKeyForHover = window.isKeyWindow
        window.resetCursorRects()
    }

    private func restoreSourceApplicationAfterHover() {
        guard madePanelKeyForHover else { return }
        defer {
            madePanelKeyForHover = false
            sourceApplicationBeforeHover = nil
        }
        guard
            !NSApp.isActive,
            let sourceApplicationBeforeHover,
            NSWorkspace.shared.frontmostApplication?.processIdentifier
                == sourceApplicationBeforeHover.processIdentifier
        else {
            return
        }
        // Reassert keyboard focus only for the app that stayed frontmost.
        sourceApplicationBeforeHover.activate(options: [])
    }
}

@MainActor
final class ResultPanelContentView: NSView {
    private let hostedView: NSView
    let leftResizeHandle = ResultPanelHorizontalResizeHandleView(edge: .left)
    let rightResizeHandle = ResultPanelHorizontalResizeHandleView(edge: .right)
    var allowsHorizontalResize: Bool {
        didSet {
            updateResizeHandleVisibility()
            window?.resetCursorRects()
        }
    }

    init(hostedView: NSView, allowsHorizontalResize: Bool) {
        self.hostedView = hostedView
        self.allowsHorizontalResize = allowsHorizontalResize
        super.init(frame: hostedView.frame)
        hostedView.frame = bounds
        hostedView.autoresizingMask = [.width, .height]
        addSubview(hostedView)
        addSubview(leftResizeHandle)
        addSubview(rightResizeHandle)
        updateResizeHandleVisibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // The edge handles own resize gestures; the container must still allow
    // background clicks to move the floating panel.
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        allowsHorizontalResize
    }

    override func layout() {
        super.layout()
        hostedView.frame = bounds
        let handleWidth = ResultPanelHorizontalResizeCalculator.hitWidth
        leftResizeHandle.frame = NSRect(
            x: bounds.minX,
            y: bounds.minY,
            width: handleWidth,
            height: bounds.height
        )
        rightResizeHandle.frame = NSRect(
            x: bounds.maxX - handleWidth,
            y: bounds.minY,
            width: handleWidth,
            height: bounds.height
        )
        // Keep geometry current before active-always hover makes the
        // nonactivating panel key and rebuilds these regions again.
        window?.resetCursorRects()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.resetCursorRects()
    }

    private func updateResizeHandleVisibility() {
        leftResizeHandle.isHidden = !allowsHorizontalResize
        rightResizeHandle.isHidden = !allowsHorizontalResize
    }
}

@MainActor
enum FloatingPanelStyle {
    static let cornerRadius = DesignTokens.radiusL

    static func apply(to panel: NSPanel) {
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        // Keep the title-bar geometry that AppKit uses for native resize
        // cursor hit testing, while rendering it completely transparent so
        // the result card remains a single borderless-looking surface.
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.titlebarSeparatorStyle = .none
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.hasShadow = true
    }

    static func apply(to contentView: NSView) {
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = cornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
    }
}

@MainActor
final class FloatingPanelCoordinator: NSObject, NSWindowDelegate {
    private weak var model: MarlaApplicationModel?
    private var panel: MarlaPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var resultLayoutCancellable: AnyCancellable?
    private var markdownProjectionCancellable: AnyCancellable?
    private weak var resultLayoutStore: TranslationSessionStore?
    private var resultLayoutModel: ResultPanelLayoutModel?
    private var resultLayoutVisibleFrame: NSRect?
    private var resultLayoutGrowthAnchor: ResultPanelGrowthAnchor = .center
    private var resultLayoutHorizontalAnchor: ResultPanelHorizontalAnchor = .center
    private var resultLayoutAutomaticContext: AutomaticPanelPlacementContext?
    private var resultLayoutReduceMotion = false
    private var resultLayoutResizeGeneration: UInt = 0
    private var resultWidthPresetTransition = ResultPanelWidthPresetTransition()

    init(model: MarlaApplicationModel? = nil, installEventMonitors: Bool = true) {
        self.model = model
        super.init()
        guard installEventMonitors else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self else { return }
                _ = self.handleDismissalEvent(event, isLocal: false)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            return self.handleDismissalEvent(event, isLocal: true) ? nil : event
        }
    }

    // Hidden result panels do not own the shared session (e.g. during in-place translation).
    @discardableResult
    func handleDismissalEvent(_ event: NSEvent, isLocal: Bool) -> Bool {
        guard panel?.isVisible == true, model?.sessionStore.session?.isPinned != true else { return false }
        if event.type == .keyDown {
            guard event.keyCode == 53 else { return false }
            hide()
            return isLocal
        }
        if !isLocal || !FloatingPanelEventRouting.isPanelRelatedWindow(event.window, panel: panel) { hide() }
        return false
    }
    func attach(model: MarlaApplicationModel) {
        self.model = model
    }
    func showResult(store: TranslationSessionStore, at anchor: ScreenRect?, pointer: CGPoint?, activate: Bool) {
        let width = model?.settings.translationWindowWidthPreset.width ?? ResultCardLayout.defaultWidth
        let placement = model?.settings.translationWindowPlacement ?? .automatic
        let lastTopLeft = model?.settings.translationWindowLastTopLeft
        let targetScreen = screen(
            anchor: anchor,
            pointer: pointer,
            placement: placement,
            lastTopLeft: lastTopLeft
        ) ?? NSScreen.main ?? NSScreen.screens.first!
        let baseMaximumHeight = ResultCardLayout.maximumPanelHeight(visibleHeight: targetScreen.visibleFrame.height)
        let source = anchor.map { NSRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        let initialPlacement = PanelPlacementCalculator.placement(
            visibleFrame: targetScreen.visibleFrame,
            requestedWidth: width,
            requestedHeight: ResultCardLayout.defaultPanelHeight,
            minimumWidth: ResultCardLayout.minimumWidth,
            maximumWidth: ResultCardLayout.maximumPanelWidth(visibleWidth: targetScreen.visibleFrame.width),
            anchor: anchor,
            pointer: pointer,
            surface: store.session?.surface,
            placement: placement
        )
        let maximumHeight = placement == .automatic
            ? AutomaticPanelPlacementCalculator.maximumPanelHeight(
                baseMaximum: baseMaximumHeight,
                side: initialPlacement.automaticSide,
                visibleFrame: targetScreen.visibleFrame,
                source: source
            )
            : baseMaximumHeight
        let growthAnchor = initialPlacement.automaticSide?.growthAnchor ?? growthAnchor(
            for: anchor,
            placement: placement,
            visibleFrame: targetScreen.visibleFrame
        )
        resultLayoutHorizontalAnchor = initialPlacement.automaticSide?.horizontalAnchor ?? .center
        let layout = configureResultLayout(
            store: store,
            width: width,
            maximumHeight: maximumHeight,
            visibleFrame: targetScreen.visibleFrame,
            growthAnchor: growthAnchor
        )
        let content = AnyView(
            TranslationCardView(
                store: store,
                onClose: { [weak self] in self?.hide() },
                onRecovery: { [weak self] action in self?.model?.performRecovery(action) },
                onVisionFallback: { [weak self] requestID in self?.model?.fallbackScreenshotOCRToVision(for: requestID) },
                onCancel: { [weak self] in self?.model?.cancelScreenshotTranslation() },
                onWidthPresetChange: { [weak self] preset in self?.setWidthPreset(preset) },
                layout: layout
            )
        )
        show(
            content: content,
            width: width,
            height: ResultCardLayout.preferredPanelHeight(
                session: store.session,
                cardWidth: width,
                maximumPanelHeight: maximumHeight,
                markdownProjection: layout.markdownProjection
            ),
            anchor: anchor,
            pointer: pointer,
            activate: activate,
            allowsWidthResize: true,
            placement: placement,
            lastTopLeft: lastTopLeft,
            surface: store.session?.surface,
            preferredAutomaticSide: initialPlacement.automaticSide
        )
    }

    func showQuickInput(store: TranslationSessionStore, pointer: CGPoint?) {
        store.close()
        let width = model?.settings.translationWindowWidthPreset.width ?? 420
        let placement = model?.settings.translationWindowPlacement ?? .automatic
        let lastTopLeft = model?.settings.translationWindowLastTopLeft
        let targetScreen = screen(
            anchor: nil,
            pointer: pointer,
            placement: placement,
            lastTopLeft: lastTopLeft
        ) ?? NSScreen.main ?? NSScreen.screens.first!
        let maximumHeight = ResultCardLayout.maximumPanelHeight(visibleHeight: targetScreen.visibleFrame.height)
        let layout = configureResultLayout(
            store: store,
            width: width,
            maximumHeight: maximumHeight,
            visibleFrame: targetScreen.visibleFrame,
            growthAnchor: .center
        )
        let content = AnyView(
            QuickInputContainerView(
                store: store,
                onClose: { [weak self] in self?.hide() },
                onRecovery: { [weak self] action in self?.model?.performRecovery(action) },
                onWidthPresetChange: { [weak self] preset in self?.setWidthPreset(preset) },
                layout: layout
            )
        )
        show(
            content: content,
            width: width,
            height: 300,
            anchor: nil,
            pointer: pointer,
            activate: true,
            allowsWidthResize: true,
            placement: placement,
            lastTopLeft: lastTopLeft,
            surface: .quickInput
        )
    }

    func showMenuAutomationSurface(model: MarlaApplicationModel) {
        let content = AnyView(MenuBarView(model: model, usesStandaloneGlassSurface: true))
        show(
            content: content,
            width: 330,
            height: 620,
            anchor: nil,
            pointer: CGPoint(x: NSScreen.main?.visibleFrame.maxX ?? 1200, y: NSScreen.main?.visibleFrame.maxY ?? 800),
            activate: true,
            allowsWidthResize: false,
            placement: .followMouse
        )
    }

    func hide() {
        resultLayoutResizeGeneration &+= 1
        resultWidthPresetTransition.reset()
        resultLayoutCancellable?.cancel()
        resultLayoutCancellable = nil
        markdownProjectionCancellable?.cancel()
        markdownProjectionCancellable = nil
        resultLayoutStore = nil
        resultLayoutModel = nil
        resultLayoutVisibleFrame = nil
        model?.clearActiveScreenshotVisionFallback()
        resultLayoutAutomaticContext = nil
        panel?.orderOut(nil)
        model?.sessionStore.close()
        SpeechCoordinator.shared.stop()
    }

    private func configureResultLayout(
        store: TranslationSessionStore,
        width: CGFloat,
        maximumHeight: CGFloat,
        visibleFrame: NSRect,
        growthAnchor: ResultPanelGrowthAnchor
    ) -> ResultPanelLayoutModel {
        resultLayoutResizeGeneration &+= 1
        resultWidthPresetTransition.reset()
        resultLayoutCancellable?.cancel()
        markdownProjectionCancellable?.cancel()
        let layout = ResultPanelLayoutModel(width: width, maximumPanelHeight: maximumHeight)
        layout.markdownProjection = MarkdownProjectionInput(session: store.session)
            .flatMap(MarkdownProjectionSnapshot.init)
        layout.sourceMarkdownProjection = SourceMarkdownProjectionInput(session: store.session)
            .flatMap(SourceMarkdownProjectionSnapshot.init)
        resultLayoutStore = store
        resultLayoutModel = layout
        resultLayoutVisibleFrame = visibleFrame
        resultLayoutGrowthAnchor = growthAnchor
        resultLayoutReduceMotion = ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        resultLayoutCancellable = store.$session.sink { [weak self] session in
            guard let self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let layout = self.resultLayoutModel else { return }
                let input = SourceMarkdownProjectionInput(session: session)
                if layout.sourceMarkdownProjection?.input != input {
                    layout.sourceMarkdownProjection = input.flatMap(SourceMarkdownProjectionSnapshot.init)
                }
                self.resizeResultPanel(for: session)
                if let session, session.state == .streaming {
                    AcceptancePerformanceRecorder.shared.completeRustDeltaSampleIfAvailable(
                        for: session.id,
                        in: self.panel
                    )
                }
            }
        }
        markdownProjectionCancellable = store.$session
            .map { MarkdownProjectionInput(session: $0) }
            .removeDuplicates()
            .throttle(
                for: .milliseconds(StreamingMarkdownProjectionPolicy.updateIntervalMilliseconds),
                scheduler: DispatchQueue.main,
                latest: true
            )
            .sink { [weak self, weak layout, weak store] input in
                layout?.markdownProjection = input.flatMap(MarkdownProjectionSnapshot.init)
                self?.resizeResultPanel(for: store?.session)
            }
        return layout
    }

    private func resizeResultPanel(for session: CardSession?) {
        guard let panel,
              let layout = resultLayoutModel,
              let visibleFrame = resultLayoutVisibleFrame,
              let session else { return }
        let height = ResultCardLayout.preferredPanelHeight(
            session: session,
            cardWidth: layout.width,
            maximumPanelHeight: layout.maximumPanelHeight,
            markdownProjection: layout.markdownProjection,
            sourceMarkdownProjection: layout.sourceMarkdownProjection
        )
        guard abs(panel.frame.height - height) > 0.5 else { return }
        let targetFrame = ResultPanelFrameCalculator.resized(
            current: panel.frame,
            height: height,
            visibleFrame: visibleFrame,
            anchor: resultLayoutGrowthAnchor
        )
        if resultLayoutReduceMotion || panel.inLiveResize {
            panel.setFrame(targetFrame, display: true, animate: false)
        } else {
            resultLayoutResizeGeneration &+= 1
            let generation = resultLayoutResizeGeneration
            NSAnimationContext.runAnimationGroup { context in
                context.duration = MarlaMotion.feedbackDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
            } completionHandler: { [weak self, weak panel] in
                Task { @MainActor [weak self, weak panel] in
                    guard
                        let self,
                        let panel,
                        self.resultLayoutResizeGeneration == generation,
                        panel === self.panel
                    else { return }
                    self.reconcileResultPanelFrame(panel)
                }
            }
        }
    }

    private func reconcileResultPanelFrame(_ panel: NSPanel) {
        guard let session = resultLayoutStore?.session,
              let layout = resultLayoutModel,
              let visibleFrame = resultLayoutVisibleFrame else { return }
        let height = ResultCardLayout.preferredPanelHeight(
            session: session,
            cardWidth: layout.width,
            maximumPanelHeight: layout.maximumPanelHeight,
            markdownProjection: layout.markdownProjection,
            sourceMarkdownProjection: layout.sourceMarkdownProjection
        )
        let targetFrame = ResultPanelFrameCalculator.resized(
            current: panel.frame,
            height: height,
            visibleFrame: visibleFrame,
            anchor: resultLayoutGrowthAnchor
        )
        panel.setFrame(targetFrame, display: true, animate: false)
    }

    func setResultWidthForUIAutomation(_ proposedWidth: CGFloat) {
        guard MarlaRuntime.isUIAutomationSnapshot,
              let panel,
              let visibleFrame = resultLayoutVisibleFrame else { return }
        let width = ResultCardLayout.clampedPanelWidth(
            proposedWidth,
            visibleWidth: visibleFrame.width
        )
        var frame = panel.frame
        frame.origin.x = frame.midX - width / 2
        frame.size.width = width
        frame.origin.x = min(
            max(frame.origin.x, visibleFrame.minX + 8),
            visibleFrame.maxX - width - 8
        )
        panel.setFrame(frame, display: true, animate: false)
    }

    private func growthAnchor(
        for anchor: ScreenRect?,
        placement: TranslationWindowPlacement,
        visibleFrame: NSRect
    ) -> ResultPanelGrowthAnchor {
        if placement == .rememberLastPosition {
            return .top
        }
        guard let anchor else { return .center }
        let source = NSRect(x: anchor.x, y: anchor.y, width: anchor.width, height: anchor.height)
        let roomAbove = visibleFrame.maxY - source.maxY
        let roomBelow = source.minY - visibleFrame.minY
        return roomAbove >= roomBelow ? .bottom : .top
    }

    private func show(
        content: AnyView,
        width: CGFloat,
        height: CGFloat,
        anchor: ScreenRect?,
        pointer: CGPoint?,
        activate: Bool,
        allowsWidthResize: Bool,
        placement: TranslationWindowPlacement? = nil,
        lastTopLeft: CGPoint? = nil,
        surface: TranslationSurface? = nil,
        preferredAutomaticSide: AutomaticPanelPlacementSide? = nil
    ) {
        let panel = panel ?? makePanel()
        let resolvedPlacement = placement ?? model?.settings.translationWindowPlacement ?? .automatic
        let resolvedLastTopLeft = lastTopLeft ?? model?.settings.translationWindowLastTopLeft
        let targetScreen = screen(
            anchor: anchor,
            pointer: pointer,
            placement: resolvedPlacement,
            lastTopLeft: resolvedLastTopLeft
        ) ?? NSScreen.main ?? NSScreen.screens.first!
        ResultPanelWindowSizing.apply(
            to: panel,
            enabled: allowsWidthResize,
            visibleFrame: targetScreen.visibleFrame
        )
        let forcedReduceMotion = ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
        let hostingView = NSHostingView(
            rootView: content.environment(\.marlaReduceMotionOverride, forcedReduceMotion)
        )
        let panelContentView = ResultPanelContentView(
            hostedView: hostingView,
            allowsHorizontalResize: allowsWidthResize
        )
        FloatingPanelStyle.apply(to: panel)
        FloatingPanelStyle.apply(to: panelContentView)
        panel.contentView = panelContentView
        let placementResult = PanelPlacementCalculator.placement(
            visibleFrame: targetScreen.visibleFrame,
            requestedWidth: width,
            requestedHeight: height,
            minimumWidth: allowsWidthResize ? ResultCardLayout.minimumWidth : 320,
            maximumWidth: allowsWidthResize
                ? ResultCardLayout.maximumPanelWidth(visibleWidth: targetScreen.visibleFrame.width)
                : 520,
            anchor: anchor,
            pointer: pointer,
            surface: surface,
            placement: resolvedPlacement,
            fixedX: model?.settings.translationWindowFixedX ?? TranslationWindowPlacement.defaultFixedX,
            lastTopLeft: resolvedLastTopLeft,
            preferredAutomaticSide: preferredAutomaticSide
        )
        let targetFrame = placementResult.frame
        if let automaticSide = placementResult.automaticSide {
            resultLayoutGrowthAnchor = automaticSide.growthAnchor
            resultLayoutHorizontalAnchor = automaticSide.horizontalAnchor
        }
        if resolvedPlacement == .automatic,
           let side = placementResult.automaticSide,
           side != .pointer,
           let anchor,
           let surface {
            resultLayoutAutomaticContext = AutomaticPanelPlacementContext(
                source: NSRect(x: anchor.x, y: anchor.y, width: anchor.width, height: anchor.height),
                surface: surface,
                side: side
            )
        } else {
            resultLayoutAutomaticContext = nil
        }
        let reduceMotion = forcedReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        var entryFrame = targetFrame
        if !reduceMotion { entryFrame.origin.y -= 4 }
        panel.alphaValue = 0
        panel.setFrame(entryFrame, display: true, animate: false)
        panelContentView.layoutSubtreeIfNeeded()
        panel.resetCursorRects()
        panel.orderFrontRegardless()
        DispatchQueue.main.async { [weak panel] in
            guard let panel else { return }
            AcceptancePerformanceRecorder.shared.completeShellSampleWhenVisible(in: panel)
        }
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? MarlaMotion.reducedOpacityDuration : MarlaMotion.contentDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            if !reduceMotion { panel.animator().setFrame(targetFrame, display: true) }
        }
    }

    private func makePanel() -> MarlaPanel {
        let panel = MarlaPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        FloatingPanelStyle.apply(to: panel)
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        self.panel = panel
        return panel
    }

    private func screen(
        anchor: ScreenRect?,
        pointer: CGPoint?,
        placement: TranslationWindowPlacement = .followMouse,
        lastTopLeft: CGPoint? = nil
    ) -> NSScreen? {
        if placement == .rememberLastPosition, let lastTopLeft {
            if let rememberedScreen = NSScreen.screens.first(where: {
                $0.frame.insetBy(dx: 0, dy: -1).contains(lastTopLeft)
            }) {
                return rememberedScreen
            }
        }
        let screens = NSScreen.screens
        let source = anchor.map { NSRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        guard let index = PanelTargetScreenCalculator.index(
            screenFrames: screens.map(\.frame),
            source: source,
            pointer: pointer
        ) else {
            return nil
        }
        return screens[index]
    }
    func setWidthPreset(_ preset: TranslationWindowWidthPreset) {
        guard let panel,
              let layout = resultLayoutModel,
              let visibleFrame = resultLayoutVisibleFrame else { return }
        model?.settings.translationWindowWidthPreset = preset
        let width = ResultCardLayout.clampedPanelWidth(preset.width, visibleWidth: visibleFrame.width)
        let widthChange = ResultPanelWidthChangeCalculator.target(
            currentFrame: panel.frame,
            width: width,
            visibleFrame: visibleFrame,
            placement: model?.settings.translationWindowPlacement ?? .automatic,
            horizontalAnchor: resultLayoutHorizontalAnchor,
            currentMaximumHeight: layout.maximumPanelHeight,
            automaticContext: resultLayoutAutomaticContext,
            session: resultLayoutStore?.session,
            layout: layout
        )
        layout.maximumPanelHeight = widthChange.maximumHeight
        if let automaticSide = widthChange.automaticSide {
            resultLayoutAutomaticContext?.side = automaticSide
            resultLayoutGrowthAnchor = automaticSide.growthAnchor
            resultLayoutHorizontalAnchor = automaticSide.horizontalAnchor
        }
        resultLayoutResizeGeneration &+= 1
        resultWidthPresetTransition.begin(
            targetWidth: width,
            currentWidth: panel.frame.width
        )
        panel.setFrame(
            widthChange.frame,
            display: true,
            animate: !resultLayoutReduceMotion && !panel.inLiveResize
        )
    }
    func windowDidMove(_ notification: Notification) {
        guard let movedWindow = notification.object as? NSWindow,
              movedWindow === panel else { return }
        model?.settings.rememberTranslationWindowTopLeft(
            CGPoint(x: movedWindow.frame.minX, y: movedWindow.frame.maxY)
        )
    }

    func windowWillClose(_ notification: Notification) {
        model?.sessionStore.close()
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard sender === panel,
              resultLayoutModel != nil,
              let visibleFrame = resultLayoutVisibleFrame else { return frameSize }
        return NSSize(
            width: ResultCardLayout.clampedPanelWidth(
                frameSize.width,
                visibleWidth: visibleFrame.width
            ),
            height: sender.frame.height
        )
    }

    func windowDidResize(_ notification: Notification) {
        guard let resizedWindow = notification.object as? NSWindow,
              resizedWindow === panel,
              let layout = resultLayoutModel,
              let visibleFrame = resultLayoutVisibleFrame else { return }
        let width = ResultCardLayout.clampedPanelWidth(
            resizedWindow.frame.width,
            visibleWidth: visibleFrame.width
        )
        let widthChanged = abs(layout.width - width) > 0.5
        if widthChanged {
            layout.width = width
        }
        // The preset frame already contains its final height. Intermediate
        // resize notifications only keep SwiftUI aligned with AppKit.
        if resultWidthPresetTransition.consumesResize(at: width) {
            return
        }
        guard widthChanged else { return }
        resizeResultPanel(for: resultLayoutStore?.session)
    }
}
