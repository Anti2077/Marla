import Foundation

enum StreamingMarkdownProjectionPolicy {
    static let updateIntervalMilliseconds = 40
}

struct MarkdownProjectionInput: Equatable {
    enum Phase: Equatable {
        case streaming
        case completed
    }

    let sessionID: UUID
    let markdown: String
    let phase: Phase

    init?(session: CardSession?) {
        guard let session,
              session.sourceContent.format == .semanticMarkdown,
              !session.translation.isEmpty
        else { return nil }

        let phase: Phase
        switch session.state {
        case .streaming:
            phase = .streaming
        case .completed:
            phase = .completed
        default:
            return nil
        }

        self.sessionID = session.id
        markdown = session.translation
        self.phase = phase
    }
}

struct MarkdownProjectionSnapshot {
    let input: MarkdownProjectionInput
    let document: MarkdownResultDocument
    let attributedDocument: NSAttributedString

    @MainActor
    init?(input: MarkdownProjectionInput) {
        guard let document = MarkdownResultDocument.parse(input.markdown) else { return nil }
        self.input = input
        self.document = document
        attributedDocument = MarkdownResultAttributedDocument.build(
            document,
            showsStreamingCursor: input.phase == .streaming
        )
    }

    func matches(_ session: CardSession) -> Bool {
        input.sessionID == session.id && session.shouldRenderMarkdownProjection
    }
}
