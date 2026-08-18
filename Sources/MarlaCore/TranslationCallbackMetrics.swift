import Foundation

/// Keeps callback receipt timestamps in memory only while the explicit release
/// performance harness is active. No request or translation content is stored.
public enum TranslationCallbackMetrics {
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var deltaReceipts: [UUID: [UInt64]] = [:]
    }

    private static let storage = Storage()

    public static func record(
        _ event: TranslationFFIEvent,
        at uptimeNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds,
        enabled: Bool = ProcessInfo.processInfo.environment["MARLA_PERFORMANCE_REPORT_PATH"] != nil
    ) {
        guard enabled, event.type == "delta" else { return }
        storage.lock.lock()
        storage.deltaReceipts[event.requestID, default: []].append(uptimeNanoseconds)
        storage.lock.unlock()
    }

    public static func takeDeltaReceipt(for requestID: UUID) -> UInt64? {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        guard var receipts = storage.deltaReceipts[requestID], !receipts.isEmpty else { return nil }
        let receipt = receipts.removeFirst()
        if receipts.isEmpty {
            storage.deltaReceipts.removeValue(forKey: requestID)
        } else {
            storage.deltaReceipts[requestID] = receipts
        }
        return receipt
    }
}
