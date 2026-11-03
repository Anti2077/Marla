import AppKit
import XCTest
@testable import MarlaApp

final class ScreenshotElementSelectionTests: XCTestCase {
    private let window = CGRect(x: -300, y: 20, width: 600, height: 400)
    private let point = CGPoint(x: -200, y: 100)
    private var leaf: ScreenshotElementCandidate {
        ScreenshotElementCandidate(frame: CGRect(x: -230, y: 80, width: 80, height: 40), role: "AXButton")
    }
    private var parent: ScreenshotElementCandidate {
        ScreenshotElementCandidate(frame: CGRect(x: -260, y: 60, width: 240, height: 160), role: "AXGroup")
    }
    private func path(_ candidates: [ScreenshotElementCandidate]) -> ScreenshotElementPath {
        .make(windowID: 7, windowFrame: window, visibleBounds: window, point: point, leafToRoot: candidates)
    }

    func testScreenshotWindowOrderingUsesServerOrderAndStableFallback() {
        let targets = [ScreenshotWindowTarget(id: 1, frame: window), .init(id: 2, frame: window),
                       .init(id: 3, frame: window), .init(id: 4, frame: window)]
        let ordered = ScreenshotWindowTargeting.ordered(targets, frontToBackIDs: [2, 1, 2])
        XCTAssertEqual(ordered.map(\.id), [2, 1, 3, 4])
        XCTAssertEqual(ScreenshotWindowTargeting.hitTest(point: point, in: ordered)?.id, 2)
    }

    func testScreenshotElementPathClipsDeduplicatesAndRejectsUnrelatedGeometry() {
        let duplicate = ScreenshotElementCandidate(frame: leaf.frame.offsetBy(dx: 0.2, dy: 0), role: "AXGroup")
        let unrelated = ScreenshotElementCandidate(frame: CGRect(x: -210, y: 90, width: 200, height: 20), role: "AXGroup")
        let huge = ScreenshotElementCandidate(frame: window.insetBy(dx: -50, dy: -50), role: "AXGroup")
        let result = path([leaf, duplicate, unrelated, parent, huge])
        XCTAssertEqual(result.candidates.map(\.frame), [leaf.frame, parent.frame, window])
        XCTAssertEqual(result.candidates.last?.role, "AXWindow")
        XCTAssertTrue(path([.init(frame: CGRect(x: CGFloat.nan, y: 0, width: 20, height: 20), role: "AXButton")])
            .candidates.allSatisfy { $0.frame == window })
    }

    func testScreenshotElementPathClipsNegativeAndOffDisplayWindowEdges() {
        let visible = CGRect(x: -250, y: 0, width: 500, height: 350)
        let result = ScreenshotElementPath.make(windowID: 7, windowFrame: window, visibleBounds: visible,
                                               point: point, leafToRoot: [leaf, parent])
        XCTAssertEqual(result.candidates.last?.frame, window.intersection(visible))
        XCTAssertTrue(result.candidates.allSatisfy { visible.contains($0.frame) })
        XCTAssertTrue(ScreenshotElementPath.make(windowID: 7, windowFrame: window,
            visibleBounds: visible, point: CGPoint(x: 900, y: 0), leafToRoot: []).candidates.isEmpty)
    }

    func testScreenshotExplicitLevelSurvivesRefinementAndRepeatedPath() {
        var choice = ScreenshotElementChoice()
        choice.replace(path([parent]))
        choice.step(1)
        XCTAssertEqual(choice.selected?.frame, window)
        choice.replace(path([leaf, parent]))
        XCTAssertEqual(choice.selected?.frame, window)
        choice.step(-1)
        XCTAssertEqual(choice.selected, parent)
        choice.replace(path([leaf, parent]))
        XCTAssertEqual(choice.selected, parent)
        choice.replace(path([leaf]))
        XCTAssertEqual(choice.selected, parent)
        choice.lock()
        choice.replace(nil)
        choice.step(-1)
        XCTAssertEqual(choice.selected, parent)
    }

    func testScreenshotLevelScrollAccumulatesPreciseInputAndIgnoresMomentum() {
        var scroll = ScreenshotLevelScroll()
        XCTAssertEqual(scroll.step(delta: 5, precise: true, began: true, momentum: false, ended: false, timestamp: 1), 0)
        XCTAssertEqual(scroll.step(delta: 8, precise: true, began: false, momentum: false, ended: false, timestamp: 1.01), 1)
        XCTAssertEqual(scroll.step(delta: 90, precise: true, began: false, momentum: true, ended: false, timestamp: 1.2), 0)
        XCTAssertEqual(scroll.step(delta: -13, precise: true, began: true, momentum: false, ended: false, timestamp: 1.3), -1)
        XCTAssertEqual(scroll.step(delta: -13, precise: true, began: false, momentum: false, ended: false, timestamp: 1.31), 0)
        XCTAssertEqual(scroll.step(delta: 0, precise: true, began: false, momentum: false, ended: true, timestamp: 1.4), 0)
        XCTAssertEqual(scroll.step(delta: 1, precise: false, began: false, momentum: false, ended: false, timestamp: 2), 1)
    }

    func testScreenshotTrackpadOneFingerGestureNeverCrossesTwoLevels() {
        var scroll = ScreenshotLevelScroll()
        var steps: [Int] = []
        for (index, delta) in [CGFloat(3), 6, 9, 18, 12, 7, 5, 3].enumerated() {
            let step = scroll.step(delta: delta, precise: true, began: index == 0, momentum: false,
                                   ended: false, timestamp: Double(index) * 0.12)
            if step != 0 { steps.append(step) }
        }
        XCTAssertEqual(steps, [1])
        XCTAssertEqual(scroll.step(delta: 0, precise: true, began: false, momentum: false, ended: true, timestamp: 1), 0)
        XCTAssertEqual(scroll.step(delta: 30, precise: true, began: false, momentum: true, ended: false, timestamp: 1.1), 0)
        XCTAssertEqual(scroll.step(delta: -15, precise: true, began: true, momentum: false, ended: false, timestamp: 1.2), -1)
    }

    func testScreenshotTransitionFirstFrameReverseInterruptionAndReduceMotion() {
        var transition = ScreenshotSelectionTransition(duration: 0.08)
        transition.update(leaf.frame, at: 0, animated: true)
        XCTAssertEqual(transition.displayed, leaf.frame)
        transition.update(window, at: 1, animated: true)
        transition.advance(at: 1.04)
        let intermediate = transition.displayed
        XCTAssertNotEqual(intermediate, leaf.frame)
        XCTAssertNotEqual(intermediate, window)
        transition.update(parent.frame, at: 1.04, animated: true)
        XCTAssertEqual(transition.displayed, intermediate)
        transition.advance(at: 1.13)
        XCTAssertEqual(transition.displayed, parent.frame)
        XCTAssertFalse(transition.isRunning)
        transition.update(window, at: 2, animated: true)
        transition.update(window, at: 2.01, animated: false)
        XCTAssertEqual(transition.displayed, window)
        XCTAssertFalse(transition.isRunning)
    }

    @MainActor
    func testScreenshotPointerLocksExactTargetAndConfirmsDuringAnimation() {
        var finished: ScreenshotSelectionResult?
        let session = ScreenshotSelectionSession(windowTargets: [.init(id: 7, frame: window)],
                                                 reducesMotion: false, onSelectionFinish: { finished = $0 })
        XCTAssertEqual(session.selectionMode, .window)
        session.hover(at: point)
        session.applyElementResult(result(refined: false, candidates: [leaf, parent]))
        XCTAssertEqual(session.selectionRect, leaf.frame)
        // Display is still on the window at this instant; the click must crop the leaf.
        XCTAssertNotEqual(session.displayedSelectionRect, leaf.frame)
        session.pointerDown(at: point)
        session.applyElementResult(result(refined: true, candidates: [parent]))
        session.scrollLevel(delta: 1, precise: false, timestamp: 1)
        session.pointerUp(at: point)
        XCTAssertEqual(finished?.globalRect, leaf.frame)
        XCTAssertFalse(finished?.cancelled ?? true)
        session.pointerUp(at: point)
    }

    @MainActor
    func testScreenshotPointerMovementResetsExplicitLevelButStationaryRefinementKeepsIt() {
        let session = ScreenshotSelectionSession(windowTargets: [.init(id: 7, frame: window)],
                                                 reducesMotion: true, onSelectionFinish: { _ in })
        session.hover(at: point)
        session.applyElementResult(result(refined: false, candidates: [leaf, parent]))
        session.scrollLevel(delta: 1, precise: false, timestamp: 1)
        XCTAssertEqual(session.selectionRect, parent.frame)
        session.applyElementResult(result(refined: true, candidates: [leaf, parent]))
        XCTAssertEqual(session.selectionRect, parent.frame)
        session.hover(at: CGPoint(x: point.x + 1, y: point.y))
        session.settleHover(at: CGPoint(x: point.x + 1, y: point.y))
        XCTAssertFalse(session.elementChoice.isExplicit)
        // The next async result for the new location starts at its leaf.
        let nextRequest = ScreenshotElementQueryRequest(generation: 2, windowID: 7, processID: 0,
            windowFrame: window, visibleBounds: window, point: CGPoint(x: point.x + 1, y: point.y),
            primaryScreenMaxY: 900, refined: false)
        session.applyElementResult(.init(request: nextRequest, path: path([leaf, parent]),
                                        elapsedMilliseconds: 1, visitedNodes: 2, termination: "complete"))
        XCTAssertEqual(session.selectionRect, leaf.frame)
        session.cancel()
    }

    @MainActor
    func testScreenshotThresholdDragConvertsToManualAndRejectsLateQuery() {
        let session = ScreenshotSelectionSession(windowTargets: [.init(id: 7, frame: window)],
                                                 onSelectionFinish: { _ in })
        session.hover(at: point)
        session.pointerDown(at: point)
        session.pointerDragged(to: point.applying(.init(translationX: 2, y: 1)))
        XCTAssertEqual(session.selectionMode, .window)
        session.pointerDragged(to: point.applying(.init(translationX: 90, y: 50)))
        XCTAssertEqual(session.selectionMode, .region)
        XCTAssertEqual(session.selectionRect, CGRect(x: point.x, y: point.y, width: 90, height: 50))
        session.applyElementResult(result(refined: false, candidates: [leaf]))
        XCTAssertEqual(session.selectionRect.width, 90)
        session.cancel()
    }

    @MainActor
    func testScreenshotPointerMustSettleBeforeReplacingHighlight() async {
        let target = ScreenshotWindowTarget(id: 7, frame: window)
        let session = ScreenshotSelectionSession(windowTargets: [target], reducesMotion: true,
            elementQuery: { request, _ in
                .init(request: request, path: .make(windowID: request.windowID, windowFrame: request.windowFrame,
                    visibleBounds: request.visibleBounds, point: request.point, leafToRoot: []),
                      elapsedMilliseconds: 0, visitedNodes: 0, termination: "synthetic")
            }, onSelectionFinish: { _ in })
        session.hover(at: point)
        session.applyElementResult(result(refined: false, candidates: [leaf, parent]))
        let outside = CGPoint(x: 100, y: 300)
        session.hover(at: outside)
        XCTAssertEqual(session.selectionRect, leaf.frame)
        try? await Task.sleep(for: .milliseconds(25))
        session.hover(at: CGPoint(x: outside.x + 10, y: outside.y))
        try? await Task.sleep(for: .milliseconds(25))
        XCTAssertEqual(session.selectionRect, leaf.frame)
        try? await Task.sleep(for: .milliseconds(70))
        XCTAssertEqual(session.selectionRect, window)
        session.cancel()
    }

    @MainActor
    func testScreenshotScrollClampsAndInPlaceRetainsManualOnly() {
        let session = ScreenshotSelectionSession(windowTargets: [.init(id: 7, frame: window)],
                                                 reducesMotion: true, onSelectionFinish: { _ in })
        session.hover(at: point)
        session.applyElementResult(result(refined: false, candidates: [leaf, parent]))
        for index in 0..<6 { session.scrollLevel(delta: 1, precise: false, timestamp: Double(index)) }
        XCTAssertEqual(session.selectionRect, window)
        for index in 10..<16 { session.scrollLevel(delta: -1, precise: false, timestamp: Double(index)) }
        XCTAssertEqual(session.selectionRect, leaf.frame)
        XCTAssertEqual(session.displayedSelectionRect, leaf.frame)
        session.cancel()
        let inPlace = ScreenshotSelectionSession(allowsWindowSelection: false, showsOCRProviderPicker: false,
                                                onSelectionFinish: { _ in })
        XCTAssertEqual(inPlace.selectionMode, .region)
        inPlace.hover(at: point)
        XCTAssertNil(inPlace.highlightedWindow)
        XCTAssertEqual(inPlace.selectionRect, .zero)
        inPlace.cancel()
    }

    @MainActor
    func testScreenshotQueriesCoalesceRejectStaleAndStopWithoutWaitingForWorker() async {
        let received = expectation(description: "latest query")
        var delivered: [UInt64] = []
        let coordinator = ScreenshotElementQueryCoordinator(query: { request, cancellation in
            // Simulate a provider already inside a blocking AX call when cancellation arrives.
            Thread.sleep(forTimeInterval: 0.06)
            return ScreenshotElementQueryResult(request: request,
                path: .make(windowID: request.windowID, windowFrame: request.windowFrame,
                    visibleBounds: request.visibleBounds, point: request.point, leafToRoot: []),
                elapsedMilliseconds: 60, visitedNodes: 1,
                termination: cancellation.isCancelled ? "cancelled" : "complete")
        }, onResult: { result in
            delivered.append(result.request.generation)
            if !result.request.refined { received.fulfill() }
        })
        let target = ScreenshotWindowTarget(id: 7, frame: window)
        coordinator.hover(window: target, point: point, visibleBounds: window, primaryScreenMaxY: 900)
        try? await Task.sleep(for: .milliseconds(40))
        for index in 0..<10 {
            coordinator.hover(window: target, point: CGPoint(x: point.x + CGFloat(index), y: point.y),
                              visibleBounds: window, primaryScreenMaxY: 900)
        }
        await fulfillment(of: [received], timeout: 2)
        XCTAssertEqual(delivered, [11])
        coordinator.stop()
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(delivered, [11])
        XCTAssertTrue(coordinator.diagnostics.isEmpty)
    }

    func testScreenshotProviderFlagLeasePreservesEnabledUnsupportedAndReadonlyProviders() {
        for original: Bool? in [true, nil] {
            var writes: [Bool] = []
            XCTAssertFalse(ScreenshotProviderFlagLease.acquire(read: { original }, isSettable: { true },
                write: { writes.append($0); return .success }))
            XCTAssertTrue(writes.isEmpty)
        }
        XCTAssertFalse(ScreenshotProviderFlagLease.acquire(read: { false }, isSettable: { false },
            write: { _ in XCTFail("readonly flag was written"); return .failure }))
    }

    func testScreenshotProviderFlagLeaseVerifiesMutationAndRollsBackFailedReadback() {
        var state = false
        var writes: [Bool] = []
        XCTAssertTrue(ScreenshotProviderFlagLease.acquire(read: { state }, isSettable: { true }, write: {
            state = $0; writes.append($0); return .notImplemented
        }))
        ScreenshotProviderFlagLease.restore(read: { state }, write: { state = $0; writes.append($0); return .success })
        XCTAssertEqual(writes, [true, false])
        XCTAssertFalse(state)
        writes = []
        XCTAssertFalse(ScreenshotProviderFlagLease.acquire(read: { false }, isSettable: { true }, write: {
            writes.append($0); return .cannotComplete
        }))
        XCTAssertEqual(writes, [true, false])
        ScreenshotProviderFlagLease.restore(read: { false }, write: { _ in XCTFail("external reset overwritten"); return .failure })
    }

    func testScreenshotQueryCancellationIsBoundedAndContainsNoPlatformObject() {
        let cancellation = ScreenshotQueryCancellation()
        cancellation.cancel()
        let output = ScreenshotElementQuery.run(request(refined: false), cancellation: cancellation)
        XCTAssertLessThan(output.elapsedMilliseconds, 100)
        XCTAssertEqual(output.path.candidates.last?.frame, window)
        XCTAssertEqual(output.visitedNodes, 0)
    }

    private func request(refined: Bool) -> ScreenshotElementQueryRequest {
        .init(generation: 1, windowID: 7, processID: 0, windowFrame: window, visibleBounds: window,
              point: point, primaryScreenMaxY: 900, refined: refined)
    }
    private func result(refined: Bool, candidates: [ScreenshotElementCandidate]) -> ScreenshotElementQueryResult {
        .init(request: request(refined: refined), path: path(candidates), elapsedMilliseconds: 1,
              visitedNodes: candidates.count, termination: "complete")
    }
}
