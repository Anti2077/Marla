import Foundation
import MarlaCore

struct TranslationAPIProfile: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var baseURL: String
    var urlMode: TranslationEndpointURLMode
    var modelName: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String = "新配置",
        baseURL: String = "",
        urlMode: TranslationEndpointURLMode = .baseURL,
        modelName: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.urlMode = urlMode
        self.modelName = modelName
        self.isEnabled = isEnabled
    }

    var isConfigured: Bool {
        Self.isValidEndpointURL(baseURL) &&
            !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func isValidEndpointURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "") &&
            url.host != nil &&
            url.query == nil &&
            url.fragment == nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case baseURL
        case urlMode
        case modelName
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        urlMode = try container.decodeIfPresent(TranslationEndpointURLMode.self, forKey: .urlMode) ?? .baseURL
        modelName = try container.decode(String.self, forKey: .modelName)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

enum APIKeyDraftResolver {
    static func resolve(_ draft: String, fallback: () -> String?) -> String? {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDraft.isEmpty ? fallback() : trimmedDraft
    }
}

