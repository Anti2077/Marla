import AppKit

/// Copying history never restores a session or starts translation work.
enum RecentTranslationCopyContent {
    case translation
    case source

    func text(in recent: RecentTranslation) -> String {
        switch self {
        case .translation: recent.translation.removingTrailingLineBreaks()
        case .source: recent.sourceText.removingTrailingLineBreaks()
        }
    }
}

extension TranslationSessionStore {
    @discardableResult
    func copyRecentTranslation(
        id: UUID,
        content: RecentTranslationCopyContent = .translation,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard let recent = recentTranslations.first(where: { $0.id == id }) else { return false }
        let text = content.text(in: recent)
        guard !text.isEmpty else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
