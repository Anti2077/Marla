import SwiftUI

struct RecentTranslationRow: View {
    let recent: RecentTranslation
    let onSelect: () -> Void
    let onCopy: (RecentTranslationCopyContent) -> Bool
    @State private var confirmation: RecentTranslationCopyContent?
    @State private var confirmationToken: UUID?

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
            .help("重新打开这条译文")
            .accessibilityLabel("最近翻译：\(recent.displayTranslation)")

            Button { copy(.translation) } label: {
                Image(systemName: confirmation == .translation ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(width: 28, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(RecentTranslationCopyContent.translation.text(in: recent).isEmpty)
            .help(confirmation == .translation ? "已复制译文" : "复制译文")
            .accessibilityLabel(confirmation == .translation ? "已复制译文" : "复制译文")
            .accessibilityIdentifier("recent-copy-translation-\(recent.id)")

            Menu {
                Button("复制原文", systemImage: "doc.on.doc") { copy(.source) }
                    .disabled(RecentTranslationCopyContent.source.text(in: recent).isEmpty)
            } label: {
                Image(systemName: confirmation == .source ? "checkmark" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(width: 24, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(confirmation == .source ? "已复制原文" : "更多复制选项")
            .accessibilityLabel(confirmation == .source ? "已复制原文，更多复制选项" : "更多复制选项")
            .accessibilityIdentifier("recent-copy-menu-\(recent.id)")
        }
        .padding(.trailing, DesignTokens.spaceS)
        .background(DesignTokens.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
        .task(id: confirmationToken) {
            guard confirmationToken != nil else { return }
            do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
            confirmation = nil
        }
    }

    private func copy(_ content: RecentTranslationCopyContent) {
        guard onCopy(content) else { return }
        confirmation = content
        confirmationToken = UUID()
    }
}
