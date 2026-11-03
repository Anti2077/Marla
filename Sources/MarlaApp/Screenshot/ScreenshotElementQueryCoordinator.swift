import Foundation

@MainActor
final class ScreenshotElementQueryCoordinator {
    typealias Query = @Sendable (ScreenshotElementQueryRequest, ScreenshotQueryCancellation) -> ScreenshotElementQueryResult
    private let query: Query
    private let onResult: (ScreenshotElementQueryResult) -> Void
    private var generation: UInt64 = 0
    private var pending: ScreenshotElementQueryRequest?
    private var running: ScreenshotQueryCancellation?
    private var targetChangedAt: TimeInterval = 0
    private var refinement: Task<Void, Never>?
    private var stopped = false
    private(set) var diagnostics: [ScreenshotElementQueryResult] = []

    init(query: @escaping Query = ScreenshotElementQuery.query, onResult: @escaping (ScreenshotElementQueryResult) -> Void) {
        self.query = query
        self.onResult = onResult
    }

    func hover(window: ScreenshotWindowTarget, point: CGPoint, visibleBounds: CGRect, primaryScreenMaxY: CGFloat) {
        guard !stopped else { return }
        generation &+= 1
        running?.cancel()
        refinement?.cancel()
        let request = ScreenshotElementQueryRequest(
            generation: generation, windowID: window.id, processID: window.processID,
            windowFrame: window.frame, visibleBounds: visibleBounds, point: point,
            primaryScreenMaxY: primaryScreenMaxY, refined: false
        )
        targetChangedAt = ProcessInfo.processInfo.systemUptime
        pending = request
        launchPending()

    }

    func invalidate() {
        generation &+= 1
        pending = nil
        running?.cancel()
        refinement?.cancel()
    }

    func stop() { stopped = true; invalidate(); diagnostics.removeAll() }

    private func refined(_ request: ScreenshotElementQueryRequest) -> ScreenshotElementQueryRequest {
        ScreenshotElementQueryRequest(
            generation: request.generation, windowID: request.windowID, processID: request.processID,
            windowFrame: request.windowFrame, visibleBounds: request.visibleBounds, point: request.point,
            primaryScreenMaxY: request.primaryScreenMaxY, refined: true
        )
    }

    private func launchPending() {
        guard !stopped, running == nil, let request = pending else { return }
        pending = nil
        let cancellation = ScreenshotQueryCancellation()
        running = cancellation
        let query = self.query
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { query(request, cancellation) }.value
            guard let self else { return }
            running = nil
            // Bounded, in-memory, geometry-only diagnostics, released at session teardown.
            if !stopped {
                diagnostics.append(result)
                if diagnostics.count > 32 { diagnostics.removeFirst() }
            }
            if !stopped, generation == request.generation, !cancellation.isCancelled {
                onResult(result)
                if !request.refined {
                    refinement = Task { [weak self] in
                        guard let self else { return }
                        let remaining = max(0, 0.08 - (ProcessInfo.processInfo.systemUptime - targetChangedAt))
                        try? await Task.sleep(for: .seconds(remaining))
                        guard !Task.isCancelled, !stopped,
                              generation == request.generation else { return }
                        pending = refined(request)
                        launchPending()
                    }
                }
            }
            launchPending()
        }
    }
}
