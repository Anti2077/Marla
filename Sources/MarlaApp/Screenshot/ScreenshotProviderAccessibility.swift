import AppKit
import ApplicationServices
import Foundation

/// Exposure flags belong to the provider, not TCC. No system permission is changed here.
/// Shared ownership prevents an old session's cleanup from disabling a replacement session's lease.
final class ScreenshotProviderAccessibility: Sendable {
    private let owner = UUID()
    private static let registry = Registry()

    func query(_ request: ScreenshotElementQueryRequest,
               cancellation: ScreenshotQueryCancellation) -> ScreenshotElementQueryResult {
        Self.registry.query(request, owner: owner, cancellation: cancellation)
    }

    func stop() { Self.registry.stop(owner: owner) }

    private final class Registry: @unchecked Sendable {
        private struct Lease {
            let processID: Int32
            let launchDate: Date
            let attribute: String
            var owners: Set<UUID>
        }
        private let lock = NSLock()
        private var leases: [Lease] = []

        func query(_ request: ScreenshotElementQueryRequest, owner: UUID,
                   cancellation: ScreenshotQueryCancellation) -> ScreenshotElementQueryResult {
            // The same lock owns the lease table and one synchronous worker invocation.
            // AX references never leave that invocation or enter the table.
            lock.withLock {
                ScreenshotElementQuery.run(request, cancellation: cancellation) { application in
                    self.prepare(application, processID: request.processID, owner: owner)
                }
            }
        }

        func stop(owner: UUID) {
            lock.withLock {
                for index in leases.indices { leases[index].owners.remove(owner) }
                for lease in leases where lease.owners.isEmpty {
                    guard NSRunningApplication(processIdentifier: lease.processID)?.launchDate == lease.launchDate else { continue }
                    let application = AXUIElementCreateApplication(lease.processID)
                    AXUIElementSetMessagingTimeout(application, 0.025)
                    ScreenshotProviderFlagLease.restore(
                        read: { self.read(lease.attribute, application) },
                        write: { AXUIElementSetAttributeValue(application, lease.attribute as CFString,
                                                             $0 ? kCFBooleanTrue : kCFBooleanFalse) }
                    )
                }
                leases.removeAll { $0.owners.isEmpty }
            }
        }

        private func prepare(_ application: AXUIElement, processID: Int32, owner: UUID) {
            guard let date = NSRunningApplication(processIdentifier: processID)?.launchDate else { return }
            if let index = leases.firstIndex(where: { $0.processID == processID && $0.launchDate == date }) {
                leases[index].owners.insert(owner)
                return
            }
            // Chromium's AXManualAccessibility and provider-exposed AXEnhancedUserInterface are
            // queried through public AX APIs. Unreadable or readonly attributes are never written.
            for name in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
                if read(name, application) == true { return }
                let changed = ScreenshotProviderFlagLease.acquire(
                    read: { self.read(name, application) },
                    isSettable: {
                        var settable: DarwinBoolean = false
                        return AXUIElementIsAttributeSettable(application, name as CFString, &settable) == .success
                            && settable.boolValue
                    },
                    write: { AXUIElementSetAttributeValue(application, name as CFString,
                                                         $0 ? kCFBooleanTrue : kCFBooleanFalse) }
                )
                if changed {
                    leases.append(Lease(processID: processID, launchDate: date, attribute: name, owners: [owner]))
                    return
                }
            }
        }

        private func read(_ name: String, _ application: AXUIElement) -> Bool? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(application, name as CFString, &value) == .success,
                  let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
            return CFBooleanGetValue((value as! CFBoolean))
        }
    }
}

enum ScreenshotProviderFlagLease {
    /// A reported write failure can still mutate a provider; readback is the authority.
    static func acquire(read: () -> Bool?, isSettable: () -> Bool,
                        write: (Bool) -> AXError) -> Bool {
        guard read() == false, isSettable() else { return false }
        _ = write(true)
        guard read() == true else { _ = write(false); return false }
        return true
    }

    static func restore(read: () -> Bool?, write: (Bool) -> AXError) {
        if read() == true { _ = write(false) }
    }
}
