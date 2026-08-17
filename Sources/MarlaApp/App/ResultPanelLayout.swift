import AppKit
import Foundation
import MarlaCore
import SwiftUI

extension TranslationSessionState {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}

enum ResultPanelGrowthAnchor {
    case bottom
    case top
    case center
}

enum ResultPanelHorizontalResizeEdge: Equatable {
    case left
    case right
}

enum ResultCardLayout {
    static let defaultWidth: CGFloat = 380
    static let minimumWidth = defaultWidth
    static let maximumWidth = defaultWidth * 2
    static let visibleWorkspaceHorizontalInset: CGFloat = 16
    static let defaultPanelHeight: CGFloat = 224
    static let maximumVisibleHeightRatio: CGFloat = 0.6
    static let outerHorizontalPadding: CGFloat = 32
    static let minimumTranslationViewportHeight: CGFloat = 28
    static let translationLineHeight: CGFloat = 19
    static let sourceLineHeight: CGFloat = 16
    static let maximumSourceViewportHeight: CGFloat = 110

    static func maximumPanelWidth(visibleWidth: CGFloat) -> CGFloat {
        max(
            minimumWidth,
            min(maximumWidth, floor(visibleWidth - visibleWorkspaceHorizontalInset))
        )
    }

    static func clampedPanelWidth(_ proposedWidth: CGFloat, visibleWidth: CGFloat) -> CGFloat {
        min(max(proposedWidth, minimumWidth), maximumPanelWidth(visibleWidth: visibleWidth))
    }

    static func maximumPanelHeight(visibleHeight: CGFloat) -> CGFloat {
        max(defaultPanelHeight, floor(visibleHeight * maximumVisibleHeightRatio))
    }

    static func measuredTextHeight(
        _ text: String,
        font: NSFont,
        width: CGFloat,
        renderedLineHeight: CGFloat,
        minimum: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty else { return minimum }
        let boundingRect = (text as NSString).boundingRect(
            with: NSSize(width: max(1, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let measuredHeight = ceil(boundingRect.height)
        let appKitLineHeight = max(1, ceil(font.ascender - font.descender + font.leading))
        let lineCount = max(1, ceil(measuredHeight / appKitLineHeight))
        return max(minimum, measuredHeight, lineCount * renderedLineHeight)
    }

    static func translationTextHeight(_ text: String, width: CGFloat) -> CGFloat {
        measuredTextHeight(
            text,
            font: .systemFont(ofSize: 15),
            width: width - outerHorizontalPadding,
            renderedLineHeight: translationLineHeight,
            minimum: minimumTranslationViewportHeight
        )
    }

    @MainActor
    static func translationContentHeight(
        session: CardSession,
        cardWidth: CGFloat,
        markdownProjection: MarkdownProjectionSnapshot?
    ) -> CGFloat {
        guard let markdownProjection, markdownProjection.matches(session) else {
            return translationTextHeight(session.translation, width: cardWidth)
        }
        return max(
            minimumTranslationViewportHeight,
            MarkdownResultAttributedDocument.measuredHeight(
                markdownProjection.attributedDocument,
                width: cardWidth - outerHorizontalPadding
            )
        )
    }

    static func sourceViewportHeight(_ text: String, width: CGFloat) -> CGFloat {
        min(
            maximumSourceViewportHeight,
            measuredTextHeight(
                text,
                font: .systemFont(ofSize: 13),
                width: width - outerHorizontalPadding,
                renderedLineHeight: sourceLineHeight,
                minimum: 18
            )
        )
    }

    @MainActor
    static func sourceViewportHeight(
        session: CardSession,
        cardWidth: CGFloat,
        sourceMarkdownProjection: SourceMarkdownProjectionSnapshot?
    ) -> CGFloat {
        guard let sourceMarkdownProjection,
              sourceMarkdownProjection.matches(session)
        else {
            return sourceViewportHeight(session.sourceText, width: cardWidth)
        }
        return min(
            maximumSourceViewportHeight,
            max(
                18,
                MarkdownResultAttributedDocument.measuredHeight(
                    sourceMarkdownProjection.attributedDocument,
                    width: cardWidth - outerHorizontalPadding
                )
            )
        )
    }

    static func fixedChromeHeight(sourceHeight: CGFloat? = nil) -> CGFloat {
        // Outer padding + header + language row + dividers + actions + 12pt
        // inter-section spacing. The source section is included only when
        // comparison is expanded.
        let base: CGFloat = 32 + 28 + 44 + 2 + 28 + (5 * 12)
        guard let sourceHeight else { return base }
        return base + 12 + 15 + 4 + sourceHeight
    }

    @MainActor
    static func translationViewportHeight(
        session: CardSession,
        cardWidth: CGFloat,
        maximumPanelHeight: CGFloat,
        markdownProjection: MarkdownProjectionSnapshot? = nil,
        sourceMarkdownProjection: SourceMarkdownProjectionSnapshot? = nil
    ) -> CGFloat {
        let sourceHeight = session.isComparisonExpanded
            ? sourceViewportHeight(
                session: session,
                cardWidth: cardWidth,
                sourceMarkdownProjection: sourceMarkdownProjection
            )
            : nil
        let chrome = fixedChromeHeight(sourceHeight: sourceHeight)
        let failureSupplement: CGFloat = session.translation.isEmpty || !session.state.isFailure ? 0 : 47
        let maximumViewport = max(minimumTranslationViewportHeight, maximumPanelHeight - chrome - failureSupplement)
        let contentHeight = translationContentHeight(
            session: session,
            cardWidth: cardWidth,
            markdownProjection: markdownProjection
        )
        return min(maximumViewport, contentHeight)
    }

    @MainActor
    static func preferredPanelHeight(
        session: CardSession?,
        cardWidth: CGFloat,
        maximumPanelHeight: CGFloat,
        markdownProjection: MarkdownProjectionSnapshot? = nil,
        sourceMarkdownProjection: SourceMarkdownProjectionSnapshot? = nil
    ) -> CGFloat {
        guard let session else { return defaultPanelHeight }
        let sourceHeight = session.isComparisonExpanded
            ? sourceViewportHeight(
                session: session,
                cardWidth: cardWidth,
                sourceMarkdownProjection: sourceMarkdownProjection
            )
            : nil
        let chrome = fixedChromeHeight(sourceHeight: sourceHeight)
        let failureSupplement: CGFloat = session.translation.isEmpty || !session.state.isFailure ? 0 : 47
        let viewport = translationViewportHeight(
            session: session,
            cardWidth: cardWidth,
            maximumPanelHeight: maximumPanelHeight,
            markdownProjection: markdownProjection,
            sourceMarkdownProjection: sourceMarkdownProjection
        )
        let preferred = chrome + viewport + failureSupplement
        return min(maximumPanelHeight, max(defaultPanelHeight, ceil(preferred)))
    }
}

final class ResultPanelLayoutModel: ObservableObject {
    @Published var width: CGFloat
    @Published var maximumPanelHeight: CGFloat
    @Published var markdownProjection: MarkdownProjectionSnapshot?
    @Published var sourceMarkdownProjection: SourceMarkdownProjectionSnapshot?

    init(
        width: CGFloat = ResultCardLayout.defaultWidth,
        maximumPanelHeight: CGFloat = .greatestFiniteMagnitude
    ) {
        self.width = width
        self.maximumPanelHeight = maximumPanelHeight
        markdownProjection = nil
        sourceMarkdownProjection = nil
    }
}

enum ResultPanelFrameCalculator {
    static func resized(
        current: NSRect,
        height: CGFloat,
        visibleFrame: NSRect,
        anchor: ResultPanelGrowthAnchor
    ) -> NSRect {
        var frame = NSRect(x: current.minX, y: current.minY, width: current.width, height: height)
        switch anchor {
        case .bottom:
            frame.origin.y = current.minY
        case .top:
            frame.origin.y = current.maxY - height
        case .center:
            frame.origin.y = current.midY - height / 2
        }
        frame.origin.x = min(max(frame.origin.x, visibleFrame.minX + 8), visibleFrame.maxX - frame.width - 8)
        frame.origin.y = min(max(frame.origin.y, visibleFrame.minY + 8), visibleFrame.maxY - frame.height - 8)
        return frame
    }
}

enum ResultPanelHorizontalResizeCalculator {
    static let hitWidth: CGFloat = 8

    static func resized(
        startFrame: NSRect,
        currentFrame: NSRect,
        horizontalDelta: CGFloat,
        edge: ResultPanelHorizontalResizeEdge,
        visibleFrame: NSRect
    ) -> NSRect {
        let availableWidth: CGFloat
        let proposedWidth: CGFloat
        switch edge {
        case .left:
            availableWidth = startFrame.maxX - visibleFrame.minX - 8
            proposedWidth = startFrame.width - horizontalDelta
        case .right:
            availableWidth = visibleFrame.maxX - startFrame.minX - 8
            proposedWidth = startFrame.width + horizontalDelta
        }
        let maximumWidth = max(
            ResultCardLayout.minimumWidth,
            min(
                ResultCardLayout.maximumPanelWidth(visibleWidth: visibleFrame.width),
                availableWidth
            )
        )
        let width = min(max(proposedWidth, ResultCardLayout.minimumWidth), maximumWidth)
        let x = edge == .left ? startFrame.maxX - width : startFrame.minX
        return NSRect(
            x: x,
            y: currentFrame.minY,
            width: width,
            height: currentFrame.height
        )
    }
}
