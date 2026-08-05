import Foundation

public enum SurfaceType: String, Codable, CaseIterable, Sendable {
    case terminal
    case codeEditor
    case browser
    case document
    case email
    case chat
    case fileManager
    case image
    case unknown
}

public enum TranslationDomain: String, Codable, CaseIterable, Sendable {
    case softwareDevelopment
    case business
    case academic
    case conversational
    case creative
    case general
}

public struct ContextSnapshot: Codable, Equatable, Sendable {
    public let applicationBundleID: String?
    public let surface: SurfaceType
    public let domain: TranslationDomain
    public let sanitizedWindowTitle: String?
    public let textBefore: String?
    public let textAfter: String?
    public let recentTerms: [String: String]

    public init(
        applicationBundleID: String? = nil,
        surface: SurfaceType = .unknown,
        domain: TranslationDomain = .general,
        sanitizedWindowTitle: String? = nil,
        textBefore: String? = nil,
        textAfter: String? = nil,
        recentTerms: [String: String] = [:]
    ) {
        self.applicationBundleID = applicationBundleID
        self.surface = surface
        self.domain = domain
        self.sanitizedWindowTitle = sanitizedWindowTitle
        self.textBefore = textBefore
        self.textAfter = textAfter
        self.recentTerms = recentTerms
    }

    public static let empty = ContextSnapshot()
}

public struct ContextCacheKey: Hashable, Sendable {
    public let applicationBundleID: String
    public let windowIdentifier: String

    public init(applicationBundleID: String, windowIdentifier: String) {
        self.applicationBundleID = applicationBundleID
        self.windowIdentifier = windowIdentifier
    }
}

public actor ContextCache {
    private struct Entry: Sendable {
        let snapshot: ContextSnapshot
        let expiresAt: Date
    }

    private var entries: [ContextCacheKey: Entry] = [:]
    private let timeToLive: TimeInterval

    public init(timeToLive: TimeInterval = 15 * 60) {
        self.timeToLive = max(0, timeToLive)
    }

    public func store(
        _ snapshot: ContextSnapshot,
        for key: ContextCacheKey,
        now: Date = Date()
    ) {
        entries[key] = Entry(
            snapshot: snapshot,
            expiresAt: now.addingTimeInterval(timeToLive)
        )
    }

    public func value(for key: ContextCacheKey, now: Date = Date()) -> ContextSnapshot? {
        guard let entry = entries[key] else {
            return nil
        }

        guard entry.expiresAt > now else {
            entries.removeValue(forKey: key)
            return nil
        }

        return entry.snapshot
    }

    public func removeExpired(now: Date = Date()) {
        entries = entries.filter { $0.value.expiresAt > now }
    }

    public func removeAll() {
        entries.removeAll(keepingCapacity: false)
    }
}
