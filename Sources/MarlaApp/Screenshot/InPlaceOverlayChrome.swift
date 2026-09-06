import AppKit
import SwiftUI

enum InPlaceChromeGeometry {
    static let margin: CGFloat = 12
    static let idleThickness: CGFloat = 6
    static let activeThickness: CGFloat = 10
    static let topReserve: CGFloat = 40
    static let expandedTopHeight: CGFloat = 36

    static func windowFrame(for capture: CGRect) -> CGRect {
        CGRect(x: capture.minX - margin, y: capture.minY - margin,
               width: capture.width + margin * 2, height: capture.height + margin + topReserve)
    }

    static func captureRect(in size: CGSize) -> CGRect {
        CGRect(x: margin, y: topReserve, width: size.width - margin * 2,
               height: size.height - topReserve - margin)
    }

    static func outerRect(in size: CGSize, expanded: Bool) -> CGRect {
        let capture = captureRect(in: size)
        let thickness = expanded ? activeThickness : idleThickness
        let top = expanded ? expandedTopHeight : idleThickness
        return CGRect(x: capture.minX - thickness, y: capture.minY - top,
                      width: capture.width + thickness * 2, height: capture.height + top + thickness)
    }

    static func transferRect(in size: CGSize) -> CGRect {
        let width: CGFloat = size.width >= 320 ? 164 : min(30, size.width - margin * 2)
        return CGRect(x: (size.width - width) / 2, y: topReserve - expandedTopHeight + 4,
                      width: max(1, width), height: 28)
    }

    // Hysteresis keeps the ring stable while the pointer crosses the activation boundary.
    static func isNearEdge(_ point: CGPoint, size: CGSize, wasNear: Bool) -> Bool {
        let rect = CGRect(origin: .zero, size: size)
        guard rect.contains(point) else { return false }
        let distance: CGFloat = wasNear ? 36 : 24
        let capture = captureRect(in: size)
        return !capture.insetBy(dx: distance, dy: distance).contains(point)
    }
}

@MainActor
final class InPlaceChromeState: ObservableObject {
    @Published var isNearEdge = false
    @Published var canTransfer = false
    @Published var fixtureProximity: Bool?
}

struct InPlaceOverlayChrome: View {
    @ObservedObject var state: InPlaceChromeState
    let size: CGSize
    let onClose: () -> Void
    let onTransfer: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var focusedAction: Bool

    private var expanded: Bool { (state.fixtureProximity ?? state.isNearEdge) || focusedAction }
    private var reducesMotion: Bool {
        reduceMotion || ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
    }
    private var reducesTransparency: Bool {
        reduceTransparency || ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_TRANSPARENCY"] == "1"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ring
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            if state.canTransfer {
                Button(action: onTransfer) {
                    if size.width >= 320 {
                        Label("移到翻译窗口", systemImage: "arrow.up.forward.square")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Image(systemName: "arrow.up.forward.square")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: InPlaceChromeGeometry.transferRect(in: size).width, height: 28)
                .contentShape(Rectangle())
                .help("移到翻译窗口")
                .accessibilityLabel("移到翻译窗口")
                .accessibilityIdentifier("in-place-transfer")
                .focused($focusedAction)
                .opacity(expanded ? 1 : 0)
                .allowsHitTesting(expanded)
                .position(x: InPlaceChromeGeometry.transferRect(in: size).midX,
                          y: InPlaceChromeGeometry.transferRect(in: size).midY)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: 30, height: 30)
            }
            .padding(4)
            .background { glassSurface(cornerRadius: 10) }
            .help("关闭原位翻译")
            .accessibilityLabel("关闭原位翻译")
            .accessibilityIdentifier("in-place-close")
            .position(x: max(20, size.width - InPlaceChromeGeometry.margin - 24),
                      y: InPlaceChromeGeometry.topReserve + 24)
        }
        .frame(width: size.width, height: size.height)
        .font(.system(size: 12, weight: .medium))
        .buttonStyle(.plain)
        .animation(reducesMotion ? nil : MarlaMotion.feedback, value: expanded)
        .contextMenu {
            Button("移到翻译窗口", systemImage: "arrow.up.forward.square", action: onTransfer)
                .disabled(!state.canTransfer)
            Button("关闭原位翻译", systemImage: "xmark", action: onClose)
        }
    }

    private var ring: some View {
        let outer = InPlaceChromeGeometry.outerRect(in: size, expanded: expanded)
        return glassSurface(cornerRadius: 12)
            .frame(width: outer.width, height: outer.height)
            .mask {
                InPlaceChromeRing(
                    side: expanded ? InPlaceChromeGeometry.activeThickness : InPlaceChromeGeometry.idleThickness,
                    top: expanded ? InPlaceChromeGeometry.expandedTopHeight : InPlaceChromeGeometry.idleThickness
                ).fill(style: FillStyle(eoFill: true))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.primary.opacity(contrast == .increased ? 0.65 : 0.18), lineWidth: 0.5)
            }
            .position(x: outer.midX, y: outer.midY)
    }

    @ViewBuilder
    private func glassSurface(cornerRadius: CGFloat) -> some View {
        if reducesTransparency {
            RoundedRectangle(cornerRadius: cornerRadius).fill(.background)
        } else if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius).fill(.ultraThinMaterial)
        }
    }
}

@MainActor
final class InPlaceChromeContainer: NSView {
    let state: InPlaceChromeState
    private let captureView: NSView
    private var hosting: InPlaceChromeHostingView!
    private var pointerTracking: NSTrackingArea?

    init(captureView: NSView, state: InPlaceChromeState, onClose: @escaping () -> Void, onTransfer: @escaping () -> Void) {
        self.captureView = captureView
        self.state = state
        let size = CGSize(
            width: captureView.frame.width + InPlaceChromeGeometry.margin * 2,
            height: captureView.frame.height + InPlaceChromeGeometry.margin + InPlaceChromeGeometry.topReserve
        )
        super.init(frame: CGRect(origin: .zero, size: size))
        captureView.setFrameOrigin(CGPoint(x: InPlaceChromeGeometry.margin, y: InPlaceChromeGeometry.margin))
        addSubview(captureView)
        hosting = InPlaceChromeHostingView(rootView: InPlaceOverlayChrome(
            state: state, size: size, onClose: onClose, onTransfer: onTransfer
        ))
        hosting.frame = bounds
        hosting.sizingOptions = []
        addSubview(hosting)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTracking { removeTrackingArea(pointerTracking) }
        let tracking = NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        pointerTracking = tracking
        addTrackingArea(tracking)
    }

    override func mouseEntered(with event: NSEvent) { updatePointer(event) }
    override func mouseMoved(with event: NSEvent) { updatePointer(event) }
    override func mouseExited(with event: NSEvent) { state.isNearEdge = false }

    private func updatePointer(_ event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let isNear = InPlaceChromeGeometry.isNearEdge(
            CGPoint(x: local.x, y: bounds.height - local.y), size: bounds.size, wasNear: state.isNearEdge
        )
        if state.isNearEdge != isNear { state.isNearEdge = isNear }
    }
}

@MainActor
private final class InPlaceChromeHostingView: NSHostingView<InPlaceOverlayChrome> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct InPlaceChromeRing: Shape {
    var side: CGFloat
    var top: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(side, top) }
        set { side = newValue.first; top = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 12)
        // The transparent hole stays exactly on the captured content throughout expansion.
        path.addRect(CGRect(x: rect.minX + side, y: rect.minY + top,
                            width: max(0, rect.width - side * 2), height: max(0, rect.height - top - side)))
        return path
    }
}
