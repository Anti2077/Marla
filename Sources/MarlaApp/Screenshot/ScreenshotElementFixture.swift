import AppKit

/// Offline artwork only; screenshots of this fixture contain no user's desktop pixels.
@MainActor
enum ScreenshotElementFixture {
    struct Fixture {
        let source: ScreenshotMagnifierSource
        let target: ScreenshotWindowTarget
        let focusPoint: CGPoint
        let query: ScreenshotElementQueryCoordinator.Query
    }

    static func make() -> Fixture? {
        guard let screen = NSScreen.main else { return nil }
        let screenFrame = screen.frame
        let size = screenFrame.size
        let dark = ProcessInfo.processInfo.environment["MARLA_UI_TEST_APPEARANCE"] == "dark"
        let image = NSImage(size: size)
        let window = CGRect(x: screenFrame.minX + size.width * 0.16,
                            y: screenFrame.minY + size.height * 0.17,
                            width: size.width * 0.68, height: size.height * 0.66)
        let container = window.insetBy(dx: 40, dy: 70)
        let card = CGRect(x: container.minX + 24, y: container.minY + 40,
                          width: container.width * 0.58, height: 140)
        let button = CGRect(x: card.minX + 24, y: card.minY + 24, width: 120, height: 32)
        image.lockFocus()
        (dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.86, alpha: 1)).setFill()
        CGRect(origin: .zero, size: size).fill()
        let localWindow = window.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
        (dark ? NSColor(calibratedWhite: 0.2, alpha: 1) : .white).setFill()
        NSBezierPath(roundedRect: localWindow, xRadius: 14, yRadius: 14).fill()
        let foreground: NSColor = dark ? .white : .black
        func label(_ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular) {
            (text as NSString).draw(at: CGPoint(x: point.x - screenFrame.minX, y: point.y - screenFrame.minY),
                withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: foreground])
        }
        label("Marla · Selection Playground", at: CGPoint(x: window.minX + 40, y: window.maxY - 48), size: 22, weight: .semibold)
        (dark ? NSColor(calibratedWhite: 0.25, alpha: 1) : NSColor(calibratedWhite: 0.95, alpha: 1)).setFill()
        NSBezierPath(roundedRect: container.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY), xRadius: 8, yRadius: 8).fill()
        (dark ? NSColor(calibratedWhite: 0.32, alpha: 1) : .white).setFill()
        NSBezierPath(roundedRect: card.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY), xRadius: 8, yRadius: 8).fill()
        label("Read without leaving your place", at: CGPoint(x: card.minX + 24, y: card.maxY - 40), size: 18, weight: .medium)
        NSColor(calibratedRed: 0.8, green: 0.4, blue: 0.23, alpha: 1).setFill()
        NSBezierPath(roundedRect: button.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY), xRadius: 6, yRadius: 6).fill()
        label("Translate", at: CGPoint(x: button.minX + 24, y: button.minY + 8), size: 13, weight: .medium)
        label("Button → Card → Content → Window", at: CGPoint(x: container.minX + 24, y: container.maxY - 40), size: 14)
        image.unlockFocus()
        var rect = CGRect(origin: .zero, size: size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        let candidates = [ScreenshotElementCandidate(frame: button, role: "AXButton"),
                          .init(frame: card, role: "AXGroup"), .init(frame: container, role: "AXGroup")]
        return Fixture(source: ScreenshotMagnifierSource(screenFrame: screenFrame, cgImage: cgImage),
            target: ScreenshotWindowTarget(id: 54, frame: window),
            focusPoint: CGPoint(x: button.midX, y: button.midY), query: { request, cancellation in
                let path = ScreenshotElementPath.make(windowID: request.windowID, windowFrame: request.windowFrame,
                    visibleBounds: request.visibleBounds, point: request.point,
                    leafToRoot: candidates.filter { $0.frame.contains(request.point) })
                return ScreenshotElementQueryResult(request: request, path: path, elapsedMilliseconds: 0,
                    visitedNodes: candidates.count, termination: cancellation.isCancelled ? "cancelled" : "synthetic")
            })
    }
}
