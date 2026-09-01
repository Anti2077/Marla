import AppKit
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

enum APIProfileReorderPlacement: Equatable {
    case before
    case after
}

struct APIProfileReorderState {
    enum Phase: Equatable {
        case idle
        case dragging
        case settling
    }

    private(set) var phase: Phase = .idle
    private(set) var activeProfileID: UUID?
    private(set) var sourceIsHidden = false
    private(set) var initialOrder: [UUID] = []
    private(set) var visualOrder: [UUID] = []
    private var lastInsertion: (profileID: UUID, placement: APIProfileReorderPlacement)?

    mutating func begin(profileID: UUID, order: [UUID]) {
        guard order.contains(profileID) else { return }
        phase = .dragging
        activeProfileID = profileID
        sourceIsHidden = true
        initialOrder = order
        visualOrder = order
        lastInsertion = nil
    }

    @discardableResult
    mutating func moveInsertion(
        relativeTo targetProfileID: UUID,
        placement: APIProfileReorderPlacement
    ) -> Bool {
        guard phase == .dragging,
              let activeProfileID,
              activeProfileID != targetProfileID,
              visualOrder.contains(activeProfileID),
              visualOrder.contains(targetProfileID) else { return false }

        if lastInsertion?.profileID == targetProfileID,
           lastInsertion?.placement == placement {
            return false
        }
        lastInsertion = (targetProfileID, placement)

        var candidate = visualOrder
        candidate.removeAll(where: { $0 == activeProfileID })
        guard let targetIndex = candidate.firstIndex(of: targetProfileID) else { return false }
        let insertionIndex = placement == .before ? targetIndex : targetIndex + 1
        candidate.insert(activeProfileID, at: insertionIndex)
        guard candidate != visualOrder else { return false }
        visualOrder = candidate
        return true
    }

    @discardableResult
    mutating func moveInsertion(
        relativeTo targetProfileID: UUID,
        pointerYFraction: CGFloat
    ) -> Bool {
        guard let activeProfileID,
              let activeVisualIndex = visualOrder.firstIndex(of: activeProfileID),
              let targetVisualIndex = visualOrder.firstIndex(of: targetProfileID) else { return false }
        let threshold = activeVisualIndex < targetVisualIndex
            ? APIProfileDragGeometry.downwardInsertionFraction
            : APIProfileDragGeometry.upwardInsertionFraction
        let placement: APIProfileReorderPlacement = pointerYFraction < threshold ? .before : .after
        return moveInsertion(relativeTo: targetProfileID, placement: placement)
    }

    @discardableResult
    mutating func moveInsertion(
        screenY: CGFloat,
        startingFrame: CGRect
    ) -> Bool {
        guard phase == .dragging,
              let activeProfileID,
              let activeInitialIndex = initialOrder.firstIndex(of: activeProfileID),
              !visualOrder.isEmpty else { return false }
        let slotIndex = APIProfileDragGeometry.slotIndex(
            screenY: screenY,
            startingFrame: startingFrame,
            activeInitialIndex: activeInitialIndex,
            profileCount: visualOrder.count
        )
        let targetProfileID = visualOrder[slotIndex]
        guard targetProfileID != activeProfileID else { return false }
        let pointerYFraction = APIProfileDragGeometry.pointerYFraction(
            screenY: screenY,
            targetSlotIndex: slotIndex,
            startingFrame: startingFrame,
            activeInitialIndex: activeInitialIndex
        )
        return moveInsertion(
            relativeTo: targetProfileID,
            pointerYFraction: pointerYFraction
        )
    }

    mutating func resolve(success: Bool) -> [UUID]? {
        guard phase == .dragging else { return nil }
        phase = .settling
        lastInsertion = nil
        if success {
            return visualOrder
        }
        visualOrder = initialOrder
        return nil
    }

    var activeIndexDelta: Int {
        guard let activeProfileID,
              let initialIndex = initialOrder.firstIndex(of: activeProfileID),
              let visualIndex = visualOrder.firstIndex(of: activeProfileID) else { return 0 }
        return visualIndex - initialIndex
    }

    mutating func revealSource() {
        guard phase == .settling else { return }
        sourceIsHidden = false
    }

    mutating func finish() {
        phase = .idle
        activeProfileID = nil
        sourceIsHidden = false
        initialOrder = []
        visualOrder = []
        lastInsertion = nil
    }

    func orderedProfiles(_ profiles: [TranslationAPIProfile]) -> [TranslationAPIProfile] {
        guard phase != .idle,
              visualOrder.count == profiles.count else { return profiles }
        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        let ordered = visualOrder.compactMap { profilesByID[$0] }
        return ordered.count == profiles.count ? ordered : profiles
    }
}

struct APIProfileSummaryRow: View {
    let profile: TranslationAPIProfile
    let isDefault: Bool
    let onEnabledChange: (Bool) -> Void
    let onOpen: () -> Void
    let onSetDefault: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    let activeProfileID: UUID?
    let sourceIsHidden: Bool
    let onDragStarted: () -> Void
    let onDragMoved: (CGFloat, CGRect) -> Void
    let onDropEntered: (UUID, CGFloat) -> Void
    let onDropResolved: (Bool) -> Int
    let onSourceReveal: () -> Void
    let onDragFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.marlaReduceMotionOverride) private var reduceMotionOverride

    private var isActiveDragSource: Bool {
        activeProfileID == profile.id
    }

    var body: some View {
        HStack(spacing: DesignTokens.spaceM) {
            Toggle(
                "启用配置",
                isOn: Binding(
                    get: { profile.isEnabled },
                    set: { isEnabled in onEnabledChange(isEnabled) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .help(profile.isEnabled ? "停用配置" : "启用配置")
            .accessibilityLabel("启用配置")

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: DesignTokens.spaceS) {
                        Text(profile.name.isEmpty ? "未命名配置" : profile.name)
                            .font(AppFont.bodyEmphasis)
                        if isDefault {
                            Text("默认")
                                .font(AppFont.micro)
                                .foregroundStyle(DesignTokens.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(DesignTokens.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(profile.modelName.isEmpty ? "尚未配置模型" : profile.modelName)
                        .font(AppFont.micro)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: DesignTokens.spaceM)

            Label(
                profile.isConfigured ? "配置完整" : "需要完善",
                systemImage: profile.isConfigured ? "checkmark.shield" : "exclamationmark.triangle"
            )
            .font(AppFont.micro)
            .foregroundStyle(profile.isConfigured ? DesignTokens.success : DesignTokens.warning)

            Menu {
                Button("设为默认", action: onSetDefault).disabled(isDefault)
                Divider()
                Button("删除配置", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17))
            }
            .menuStyle(.borderlessButton)

            ZStack {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DesignTokens.tertiaryText)

                APIProfileDragSource(
                    profile: profile,
                    isDefault: isDefault,
                    reducesMotion: reducesMotion,
                    onDragStarted: onDragStarted,
                    onDragMoved: onDragMoved,
                    onDropResolved: onDropResolved,
                    onSourceReveal: onSourceReveal,
                    onDragFinished: onDragFinished
                )
            }
            .frame(
                width: APIProfileDragGeometry.handleSize.width,
                height: APIProfileDragGeometry.handleSize.height
            )
            .contentShape(Rectangle())
            .help("拖动以排序")
            .accessibilityLabel("拖动以排序 \(profile.name)")
            .accessibilityAction(named: "上移") {
                if canMoveUp { onMoveUp() }
            }
            .accessibilityAction(named: "下移") {
                if canMoveDown { onMoveDown() }
            }
        }
        .opacity(sourceIsHidden ? 0 : 1)
        .allowsHitTesting(!isActiveDragSource)
        .padding(.vertical, DesignTokens.spaceM)
        .onDrop(
            of: [UTType.plainText.identifier],
            delegate: APIProfileDropDelegate(
                targetProfileID: profile.id,
                activeProfileID: activeProfileID,
                reducesMotion: reducesMotion,
                onInsertionChanged: onDropEntered
            )
        )
    }

    private var reducesMotion: Bool {
        accessibilityReduceMotion || reduceMotionOverride
    }
}

enum APIProfileDragGeometry {
    static let rowSize = CGSize(width: 580, height: 76)
    static let handleSize = CGSize(width: 32, height: 44)
    static let systemDraggingImageSize = CGSize(width: 1, height: 1)
    static let previewHorizontalPadding: CGFloat = DesignTokens.spaceM
    static let previewVerticalPadding: CGFloat = DesignTokens.spaceM
    static let rowStride: CGFloat = handleSize.height + (2 * DesignTokens.spaceM) + 1
    static let downwardInsertionFraction: CGFloat = 0.40
    static let upwardInsertionFraction: CGFloat = 0.60

    static var previewSize: CGSize {
        rowSize
    }

    static var handleOriginInPreview: CGPoint {
        CGPoint(
            x: rowSize.width - previewHorizontalPadding - handleSize.width,
            y: previewVerticalPadding
        )
    }

    static func previewFrame(
        pointerLocation: CGPoint,
        handleLocation: CGPoint
    ) -> CGRect {
        let anchor = CGPoint(
            x: handleOriginInPreview.x + handleLocation.x,
            y: handleOriginInPreview.y + handleLocation.y
        )
        return CGRect(
            x: pointerLocation.x - anchor.x,
            y: pointerLocation.y - anchor.y,
            width: previewSize.width,
            height: previewSize.height
        )
    }

    static func landingFrame(startingFrame: CGRect, indexDelta: Int) -> CGRect {
        startingFrame.offsetBy(dx: 0, dy: -CGFloat(indexDelta) * rowStride)
    }

    static func slotIndex(
        screenY: CGFloat,
        startingFrame: CGRect,
        activeInitialIndex: Int,
        profileCount: Int
    ) -> Int {
        guard profileCount > 1 else { return 0 }
        let firstSlotFrame = startingFrame.offsetBy(
            dx: 0,
            dy: CGFloat(activeInitialIndex) * rowStride
        )
        let distanceFromTop = firstSlotFrame.maxY - screenY
        let rawIndex = Int(floor(distanceFromTop / rowStride))
        return min(max(rawIndex, 0), profileCount - 1)
    }

    static func pointerYFraction(
        screenY: CGFloat,
        targetSlotIndex: Int,
        startingFrame: CGRect,
        activeInitialIndex: Int
    ) -> CGFloat {
        let targetFrame = startingFrame.offsetBy(
            dx: 0,
            dy: -CGFloat(targetSlotIndex - activeInitialIndex) * rowStride
        )
        return min(max((targetFrame.maxY - screenY) / rowSize.height, 0), 1)
    }
}

private struct APIProfileDragSource: NSViewRepresentable {
    let profile: TranslationAPIProfile
    let isDefault: Bool
    let reducesMotion: Bool
    let onDragStarted: () -> Void
    let onDragMoved: (CGFloat, CGRect) -> Void
    let onDropResolved: (Bool) -> Int
    let onSourceReveal: () -> Void
    let onDragFinished: () -> Void

    func makeNSView(context: Context) -> APIProfileDragSourceView {
        let view = APIProfileDragSourceView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ nsView: APIProfileDragSourceView, context: Context) {
        nsView.profile = profile
        nsView.isDefault = isDefault
        nsView.reducesMotion = reducesMotion
        nsView.onDragStarted = onDragStarted
        nsView.onDragMoved = onDragMoved
        nsView.onDropResolved = onDropResolved
        nsView.onSourceReveal = onSourceReveal
        nsView.onDragFinished = onDragFinished
    }
}

@MainActor
private final class APIProfileDragSourceView: NSView, NSDraggingSource {
    var profile: TranslationAPIProfile?
    var isDefault = false
    var reducesMotion = false
    var onDragStarted: (() -> Void)?
    var onDragMoved: ((CGFloat, CGRect) -> Void)?
    var onDropResolved: ((Bool) -> Int)?
    var onSourceReveal: (() -> Void)?
    var onDragFinished: (() -> Void)?

    private var mouseDownEvent: NSEvent?
    private var mouseDownLocation = CGPoint.zero
    private var startedDragging = false
    private var dragPreviewPanel: NSPanel?
    private var startingPreviewFrame: CGRect?
    private var transitionTask: Task<Void, Never>?
    private var activeDragRetention: APIProfileDragSourceView?

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        mouseDownLocation = convert(event.locationInWindow, from: nil)
        startedDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !startedDragging,
              mouseDownEvent != nil,
              let profile else { return }

        let pointerLocation = convert(event.locationInWindow, from: nil)
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(profile.id.uuidString, forType: .string)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let systemImageSize = APIProfileDragGeometry.systemDraggingImageSize
        draggingItem.setDraggingFrame(
            CGRect(
                x: pointerLocation.x - (systemImageSize.width / 2),
                y: pointerLocation.y - (systemImageSize.height / 2),
                width: systemImageSize.width,
                height: systemImageSize.height
            ),
            contents: transparentDraggingImage
        )

        let screenPoint = NSEvent.mouseLocation
        dragPreviewPanel = makeDragPreviewPanel(profile: profile)
        showDragPreview(at: screenPoint)
        onDragStarted?()
        animatePickup()
        startedDragging = true
        activeDragRetention = self

        let session = beginDraggingSession(
            with: [draggingItem],
            event: event,
            source: self
        )
        session.draggingFormation = .none
        session.draggingLeaderIndex = 0
        session.animatesToStartingPositionsOnCancelOrFail = false
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
        if !startedDragging {
            clearDragState()
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    func draggingSession(
        _ session: NSDraggingSession,
        willBeginAt screenPoint: NSPoint
    ) {
        moveDragPreview(to: screenPoint)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        movedTo screenPoint: NSPoint
    ) {
        moveDragPreview(to: screenPoint)
        if let startingPreviewFrame {
            onDragMoved?(screenPoint.y, startingPreviewFrame)
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownEvent = nil
        startedDragging = false
        let succeeded = operation.contains(.move)
        let indexDelta = onDropResolved?(succeeded) ?? 0
        let destinationFrame = startingPreviewFrame.map {
            APIProfileDragGeometry.landingFrame(
                startingFrame: $0,
                indexDelta: succeeded ? indexDelta : 0
            )
        } ?? dragPreviewPanel?.frame
        settleDragPreview(to: destinationFrame)
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    private var transparentDraggingImage: NSImage {
        NSImage(size: APIProfileDragGeometry.systemDraggingImageSize, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            return true
        }
    }

    private func makeDragPreviewPanel(profile: TranslationAPIProfile) -> NSPanel {
        let colorScheme: ColorScheme = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .dark
            : .light
        let hostingView = NSHostingView(
            rootView: APIProfileDragPreview(profile: profile, isDefault: isDefault)
                .environment(\.colorScheme, colorScheme)
        )
        hostingView.frame = CGRect(origin: .zero, size: APIProfileDragGeometry.previewSize)
        hostingView.autoresizingMask = [.width, .height]

        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: APIProfileDragGeometry.previewSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.alphaValue = 0
        return panel
    }

    private func showDragPreview(at screenPoint: NSPoint) {
        guard let dragPreviewPanel else { return }
        moveDragPreview(to: screenPoint)
        startingPreviewFrame = dragPreviewPanel.frame
        if let window {
            window.addChildWindow(dragPreviewPanel, ordered: .above)
        }
        dragPreviewPanel.orderFront(nil)
    }

    private func moveDragPreview(to screenPoint: NSPoint) {
        dragPreviewPanel?.setFrame(
            APIProfileDragGeometry.previewFrame(
                pointerLocation: screenPoint,
                handleLocation: mouseDownLocation
            ),
            display: true
        )
    }

    private func animatePickup() {
        guard let dragPreviewPanel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reducesMotion
                ? MarlaMotion.reducedOpacityDuration
                : MarlaMotion.feedbackDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            dragPreviewPanel.animator().alphaValue = 1
        }
    }

    private func settleDragPreview(to destinationFrame: CGRect?) {
        guard let dragPreviewPanel else {
            onSourceReveal?()
            onDragFinished?()
            clearDragState()
            return
        }

        guard let destinationFrame, !reducesMotion else {
            if let destinationFrame {
                dragPreviewPanel.setFrame(destinationFrame, display: true)
            }
            beginSourceHandoff()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = MarlaMotion.apiProfileDropDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dragPreviewPanel.animator().setFrame(destinationFrame, display: true)
        }
        scheduleTransition(after: MarlaMotion.apiProfileDropDuration) { [self] in
            beginSourceHandoff()
        }
    }

    private func beginSourceHandoff() {
        guard let dragPreviewPanel else {
            onSourceReveal?()
            onDragFinished?()
            clearDragState()
            return
        }

        onSourceReveal?()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reducesMotion
                ? MarlaMotion.reducedOpacityDuration
                : MarlaMotion.feedbackDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            dragPreviewPanel.animator().alphaValue = 0
        }
        let handoffDuration = reducesMotion
            ? MarlaMotion.reducedOpacityDuration
            : MarlaMotion.feedbackDuration
        scheduleTransition(after: handoffDuration) { [self] in
            hideDragPreview()
            onDragFinished?()
            clearDragState()
        }
    }

    private func scheduleTransition(
        after duration: TimeInterval,
        operation: @escaping @MainActor () -> Void
    ) {
        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            operation()
        }
    }

    private func hideDragPreview() {
        guard let dragPreviewPanel else { return }
        dragPreviewPanel.parent?.removeChildWindow(dragPreviewPanel)
        dragPreviewPanel.orderOut(nil)
        self.dragPreviewPanel = nil
    }

    private func clearDragState() {
        transitionTask?.cancel()
        transitionTask = nil
        mouseDownEvent = nil
        startedDragging = false
        startingPreviewFrame = nil
        activeDragRetention = nil
    }
}

private struct APIProfileDragPreview: View {
    let profile: TranslationAPIProfile
    let isDefault: Bool

    var body: some View {
        HStack(spacing: DesignTokens.spaceM) {
            Toggle("启用配置", isOn: .constant(profile.isEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                HStack(spacing: DesignTokens.spaceS) {
                    Text(profile.name.isEmpty ? "未命名配置" : profile.name)
                        .font(AppFont.bodyEmphasis)
                    if isDefault {
                        Text("默认")
                            .font(AppFont.micro)
                            .foregroundStyle(DesignTokens.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DesignTokens.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(profile.modelName.isEmpty ? "尚未配置模型" : profile.modelName)
                    .font(AppFont.micro)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            Spacer(minLength: DesignTokens.spaceM)

            Label(
                profile.isConfigured ? "配置完整" : "需要完善",
                systemImage: profile.isConfigured ? "checkmark.shield" : "exclamationmark.triangle"
            )
            .font(AppFont.micro)
            .foregroundStyle(profile.isConfigured ? DesignTokens.success : DesignTokens.warning)

            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17))
                .foregroundStyle(DesignTokens.secondaryText)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DesignTokens.tertiaryText)
                .frame(width: 32, height: 44)
        }
        .padding(.horizontal, APIProfileDragGeometry.previewHorizontalPadding)
        .padding(.vertical, APIProfileDragGeometry.previewVerticalPadding)
        .frame(
            width: APIProfileDragGeometry.rowSize.width,
            height: APIProfileDragGeometry.rowSize.height,
            alignment: .leading
        )
        .background(DesignTokens.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous)
                .stroke(DesignTokens.divider.opacity(0.65), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        .frame(
            width: APIProfileDragGeometry.previewSize.width,
            height: APIProfileDragGeometry.previewSize.height
        )
    }
}

private struct APIProfileDropDelegate: DropDelegate {
    let targetProfileID: UUID
    let activeProfileID: UUID?
    let reducesMotion: Bool
    let onInsertionChanged: (UUID, CGFloat) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        activeProfileID != nil
    }

    func dropEntered(info: DropInfo) {
        updateInsertion(info: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateInsertion(info: info)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        activeProfileID != nil
    }

    private func updateInsertion(info: DropInfo) {
        guard let activeProfileID,
              activeProfileID != targetProfileID else { return }
        let pointerYFraction = min(max(info.location.y / APIProfileDragGeometry.rowSize.height, 0), 1)
        withAnimation(MarlaMotion.animation(MarlaMotion.reorder, reducesMotion: reducesMotion)) {
            onInsertionChanged(targetProfileID, pointerYFraction)
        }
    }
}

struct APIProfileExtendedDropDelegate: DropDelegate {
    let activeProfileID: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        activeProfileID != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        activeProfileID != nil
    }
}
