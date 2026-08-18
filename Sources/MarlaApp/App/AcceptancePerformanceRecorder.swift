import AppKit
import Foundation
import MarlaCore
import QuartzCore

@MainActor
final class AcceptancePerformanceRecorder {
    static let shared = AcceptancePerformanceRecorder()

    private struct Entry: Encodable {
        let schemaVersion = 1
        let metric: String
        let durationNanoseconds: UInt64
    }

    private let reportPath: String?
    private var pendingShellStart: UInt64?

    init(reportPath: String? = ProcessInfo.processInfo.environment["MARLA_PERFORMANCE_REPORT_PATH"]) {
        self.reportPath = reportPath?.isEmpty == false ? reportPath : nil
    }

    var isEnabled: Bool { reportPath != nil }

    func beginShellSample(at uptimeNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        guard isEnabled else { return }
        pendingShellStart = uptimeNanoseconds
    }

    func completeShellSampleWhenVisible(in panel: NSPanel, attempt: Int = 0) {
        guard pendingShellStart != nil else { return }
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        CATransaction.flush()
        if panel.isVisible, panel.occlusionState.contains(.visible) {
            guard let startedAt = pendingShellStart else { return }
            pendingShellStart = nil
            append(metric: "local_entry_to_visible_shell", startedAt: startedAt)
            exitAfterSampleIfRequested()
            return
        }
        guard attempt < 20 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2)) { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.completeShellSampleWhenVisible(in: panel, attempt: attempt + 1)
        }
    }

    func completeRustDeltaSampleIfAvailable(for requestID: UUID, in panel: NSPanel?) {
        guard isEnabled,
              let panel,
              let startedAt = TranslationCallbackMetrics.takeDeltaReceipt(for: requestID)
        else { return }
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel else { return }
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.displayIfNeeded()
            CATransaction.flush()
            self.append(metric: "rust_callback_to_swift_visible_delta", startedAt: startedAt)
            self.exitAfterSampleIfRequested()
        }
    }

    private func append(metric: String, startedAt: UInt64) {
        guard let reportPath else { return }
        let completedAt = DispatchTime.now().uptimeNanoseconds
        let entry = Entry(
            metric: metric,
            durationNanoseconds: completedAt >= startedAt ? completedAt - startedAt : 0
        )
        do {
            var data = try JSONEncoder().encode(entry)
            data.append(0x0A)
            let url = URL(fileURLWithPath: reportPath)
            if !FileManager.default.fileExists(atPath: reportPath) {
                guard FileManager.default.createFile(atPath: reportPath, contents: nil) else {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            FileHandle.standardError.write(
                Data("Performance report write failed: \(error.localizedDescription)\n".utf8)
            )
        }
    }

    private func exitAfterSampleIfRequested() {
        guard ProcessInfo.processInfo.environment["MARLA_PERFORMANCE_EXIT_AFTER_SAMPLE"] == "1" else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(40)) {
            NSApp.terminate(nil)
        }
    }
}

extension MarlaApplicationModel {
    func presentPerformanceUIAutomationFixture(named scenario: String) -> Bool {
        switch scenario {
        case "performance-shell":
            AcceptancePerformanceRecorder.shared.beginShellSample()
            showQuickInput()
            return true
        case "performance-rust-delta":
            guard let baseURL = ProcessInfo.processInfo.environment["MARLA_PERFORMANCE_BASE_URL"],
                  !baseURL.isEmpty
            else { return false }
            let profileID = settings.addProfile()
            settings.updateProfile(
                id: profileID,
                name: "RV-003 Local SSE",
                baseURL: baseURL,
                modelName: "rv-003-local"
            )
            settings.setDefaultProfile(profileID)
            sessionStore.installUIAutomationFixture(
                surface: .quickInput,
                sourceText: "Local performance fixture",
                translation: "",
                state: .awaitingFirstToken,
                contentFormat: .plainText
            )
            panelCoordinator.showResult(
                store: sessionStore,
                at: nil,
                pointer: NSEvent.mouseLocation,
                activate: true
            )
            if let requestID = sessionStore.session?.id {
                sessionStore.startRequest(for: requestID)
            }
            return true
        default:
            return false
        }
    }
}
