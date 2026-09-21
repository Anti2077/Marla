import SwiftUI

struct RecentTranslationRow: View {
    let recent: RecentTranslation
    let onSelect: () -> Void
    let onCopy: (RecentTranslationCopyContent) -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.marlaReduceMotionOverride) private var reduceMotionOverride
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var focusedControl: Control?
    @State private var isHovered = false
    @State private var isMenuTracking = false
    @State private var isMenuFocused = false
    @State private var confirmation: RecentTranslationCopyContent?
    @State private var confirmationToken: UUID?

    private enum Control: Hashable { case open, copy }

    private var showsControls: Bool {
        isHovered || focusedControl != nil || isMenuTracking || isMenuFocused
    }

    private var reducesMotion: Bool { reduceMotion || reduceMotionOverride }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: DesignTokens.spaceS) {
                    Image(systemName: recent.surface.symbolName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignTokens.accent)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recent.displayTranslation)
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.primaryText)
                            .lineLimit(1)
                        Text(recent.displaySourceText)
                            .font(AppFont.micro)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: DesignTokens.spaceS)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DesignTokens.tertiaryText)
                }
                .padding(.leading, DesignTokens.spaceM)
                .padding(.trailing, DesignTokens.spaceS)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($focusedControl, equals: .open)
            .help("重新打开这条译文")
            .accessibilityLabel("最近翻译：\(recent.displayTranslation)")
            .accessibilityAction(named: "复制译文") { copy(.translation) }
            .accessibilityAction(named: "复制原文") { copy(.source) }

            copyControls
                .frame(width: 49, height: 28)
                .offset(x: showsControls || reducesMotion ? 0 : 12)
                .opacity(showsControls ? 1 : 0)
                .frame(width: showsControls ? 49 : 0, alignment: .trailing)
                .clipped()
                .allowsHitTesting(showsControls)
                .accessibilityHidden(!showsControls)
        }
        .padding(.trailing, DesignTokens.spaceS)
        .background(DesignTokens.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(reducesMotion ? nil : MarlaMotion.content, value: showsControls)
        .task(id: confirmationToken) {
            guard confirmationToken != nil else { return }
            do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
            confirmation = nil
        }
    }

    private var copyControls: some View {
        HStack(spacing: 0) {
            Button { copy(.translation) } label: {
                Image(systemName: confirmation == .translation ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($focusedControl, equals: .copy)
            .disabled(!showsControls || RecentTranslationCopyContent.translation.text(in: recent).isEmpty)
            .help(confirmation == .translation ? "已复制译文" : "复制译文")
            .accessibilityLabel(confirmation == .translation ? "已复制译文" : "复制译文")
            .accessibilityIdentifier("recent-copy-translation-\(recent.id)")

            Rectangle()
                .fill(DesignTokens.secondaryText.opacity(contrast == .increased ? 0.8 : 0.3))
                .frame(width: 1)
                .accessibilityHidden(true)
            RecentTranslationCopyMenu(
                isEnabled: showsControls && !RecentTranslationCopyContent.source.text(in: recent).isEmpty,
                isConfirmed: confirmation == .source,
                identifier: "recent-copy-menu-\(recent.id)",
                onCopySource: { copy(.source) },
                onTrackingChange: { isMenuTracking = $0 },
                onFocusChange: { isMenuFocused = $0 }
            )
            .frame(width: 20, height: 28)
        }
        .background(DesignTokens.surface.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(DesignTokens.secondaryText.opacity(contrast == .increased ? 0.8 : 0.3), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func copy(_ content: RecentTranslationCopyContent) {
        guard onCopy(content) else { return }
        confirmation = content
        confirmationToken = UUID()
    }
}
