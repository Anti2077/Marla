import AppKit
import Foundation
import MarlaCore
import SwiftUI

struct TranslationCardView: View {
    @ObservedObject var store: TranslationSessionStore
    @ObservedObject private var layout: ResultPanelLayoutModel
    let onClose: () -> Void
    let onRecovery: (CardRecoveryAction) -> Void
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.marlaReduceMotionOverride) private var reduceMotionOverride

    init(
        store: TranslationSessionStore,
        onClose: @escaping () -> Void,
        onRecovery: @escaping (CardRecoveryAction) -> Void,
        cardWidth: CGFloat = ResultCardLayout.defaultWidth,
        maximumPanelHeight: CGFloat = .greatestFiniteMagnitude,
        layout: ResultPanelLayoutModel? = nil
    ) {
        self.store = store
        self.onClose = onClose
        self.onRecovery = onRecovery
        self.layout = layout ?? ResultPanelLayoutModel(
            width: cardWidth,
            maximumPanelHeight: maximumPanelHeight
        )
    }

    private var cardWidth: CGFloat { layout.width }
    private var maximumPanelHeight: CGFloat { layout.maximumPanelHeight }

    private var reduceMotion: Bool {
        systemReduceMotion || reduceMotionOverride
    }

    var body: some View {
        Group {
            if let session = store.session {
                VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
                    cardHeader(session)
                    languageControls(session)
                    Divider()
                    translationContent(session)
                    if session.isComparisonExpanded {
                        sourceContent(session)
                    }
                    Divider()
                    cardActions(session)
                }
                .padding(DesignTokens.spaceL)
                .frame(width: cardWidth, alignment: .topLeading)
                .frame(minHeight: 160, maxHeight: .infinity, alignment: .topLeading)
                .marlaGlassSurface()
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: session.isPinned)
                .onExitCommand(perform: onClose)
            }
        }
    }

    @ViewBuilder
    private func cardHeader(_ session: CardSession) -> some View {
        HStack(spacing: DesignTokens.spaceS) {
            Image(systemName: session.surface.symbolName)
                .foregroundStyle(DesignTokens.accent)
            Text(session.surface.displayName)
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
            Spacer()
            Menu {
                ForEach(store.availableProfiles) { profile in
                    Button {
                        store.changeAPIProfile(profile.id)
                    } label: {
                        if profile.id == session.profileID {
                            Label(profile.name, systemImage: "checkmark")
                        } else {
                            Text(profile.name)
                        }
                    }
                    .disabled(!profile.isConfigured || profile.id == session.profileID)
                }
                Divider()
                Button("管理翻译配置…") { onRecovery(.openSettings) }
            } label: {
                Label(session.profileName, systemImage: "server.rack")
                    .font(AppFont.caption)
                    .lineLimit(1)
            }
            .menuStyle(.borderlessButton)
            .help("切换翻译配置")
            Button {
                store.togglePinned()
            } label: {
                Image(systemName: session.isPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .frame(width: 28, height: 28)
            .help(session.isPinned ? "取消固定" : "固定卡片")
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .frame(width: 28, height: 28)
            .help("关闭")
        }
        .accessibilityElement(children: .contain)
    }

    private func languageControls(_ session: CardSession) -> some View {
        HStack(spacing: DesignTokens.spaceS) {
            Menu {
                Button {
                    store.changeSource(.automatic)
                } label: {
                    if session.source.mode == .automatic {
                        Label("自动识别", systemImage: "checkmark")
                    } else {
                        Text("自动识别")
                    }
                }
                .disabled(session.source.mode == .automatic)
                Divider()
                ForEach(TranslationLanguage.allCases) { language in
                    Button {
                        store.changeSource(.explicit(language))
                    } label: {
                        if session.source.mode == .explicit, session.source.language == language {
                            Label(language.label, systemImage: "checkmark")
                        } else {
                            Text(language.label)
                        }
                    }
                    .disabled(session.source.mode == .explicit && session.source.language == language)
                }
            } label: {
                TranslationLanguageMenuLabel(
                    title: "源语言",
                    value: session.source.mode == .automatic
                        ? "自动识别：\(session.resolvedSourceLanguage?.label ?? "未知")"
                        : session.resolvedSourceLanguage?.label ?? "未知",
                    systemImage: "text.magnifyingglass"
                )
            }
            .menuStyle(.borderlessButton)
            .help("覆盖本次源语言")

            Image(systemName: "arrow.right")
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.tertiaryText)
                .accessibilityHidden(true)

            Menu {
                Button {
                    store.changeTarget(.automatic)
                } label: {
                    let title = "自动（\(session.resolvedTargetLanguage.label)）"
                    if session.target.mode == .automatic {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
                .disabled(session.target.mode == .automatic)
                Divider()
                ForEach(TranslationLanguage.allCases) { language in
                    Button {
                        store.changeTarget(.explicit(language))
                    } label: {
                        if session.target.mode == .explicit, session.target.language == language {
                            Label(language.label, systemImage: "checkmark")
                        } else {
                            Text(language.label)
                        }
                    }
                    .disabled(session.target.mode == .explicit && session.target.language == language)
                }
            } label: {
                TranslationLanguageMenuLabel(
                    title: "目标语言",
                    value: session.resolvedTargetLanguage.label,
                    systemImage: "character.book.closed"
                )
            }
            .menuStyle(.borderlessButton)
            .help("覆盖本次目标语言")
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func translationContent(_ session: CardSession) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            if session.translation.isEmpty {
                switch session.state {
                case .recognizing:
                    StateLine(symbol: "viewfinder", title: "正在识别框选文字…", tint: DesignTokens.accent)
                case .awaitingFirstToken:
                    HStack(spacing: DesignTokens.spaceS) {
                        BreathingDot(reduceMotion: reduceMotion)
                        Text("等待译文")
                            .font(AppFont.body)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                case let .failed(message):
                    ErrorStateView(
                        message: message,
                        recoveryAction: session.recoveryAction,
                        onRecovery: onRecovery
                    )
                case .cancelled:
                    StateLine(symbol: "checkmark", title: "已取消", tint: DesignTokens.secondaryText)
                default:
                    ProgressView().controlSize(.small)
                }
            } else {
                ScrollView {
                    translationText(session)
                }
                .frame(
                    height: ResultCardLayout.translationViewportHeight(
                        session: session,
                        cardWidth: cardWidth,
                        maximumPanelHeight: maximumPanelHeight
                    )
                )
                if case let .failed(message) = session.state {
                    PartialFailureView(
                        message: message,
                        recoveryAction: session.recoveryAction,
                        onRecovery: onRecovery
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func translationText(_ session: CardSession) -> some View {
        let cursor = Text("│").foregroundColor(DesignTokens.accent)
        let text: Text
        if case .streaming = session.state {
            text = Text(session.translation) + cursor
        } else {
            text = Text(session.translation)
        }
        return text
            .font(AppFont.translation)
            .foregroundStyle(DesignTokens.primaryText)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.12), value: session.state)
    }

    private func sourceContent(_ session: CardSession) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
            Text("原文")
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
            ScrollView {
                Text(session.sourceText)
                    .font(AppFont.source)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: ResultCardLayout.sourceViewportHeight(session.sourceText, width: cardWidth))
        }
    }

    private func cardActions(_ session: CardSession) -> some View {
        HStack(spacing: DesignTokens.spaceM) {
            Button {
                store.toggleComparison()
            } label: {
                Label(session.isComparisonExpanded ? "收起原文" : "查看原文", systemImage: session.isComparisonExpanded ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
            .help("切换原文对照")
            Spacer()
            Button { store.copyTranslation() } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless)
                .help("复制译文")
                .accessibilityLabel(session.copyConfirmed ? "已复制译文" : "复制译文")
                .symbolVariant(session.copyConfirmed ? .fill : .none)
            Button { store.retry() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("重试")
            Button { speak(session.translation) } label: { Image(systemName: "speaker.wave.2") }
                .buttonStyle(.borderless)
                .help("朗读或停止译文")
            if !session.state.isTerminal {
                Button { store.cancel() } label: { Image(systemName: "stop.circle") }
                    .buttonStyle(.borderless)
                    .help("取消当前翻译")
            }
        }
        .font(AppFont.caption)
        .foregroundStyle(DesignTokens.secondaryText)
    }

    private func speak(_ text: String) {
        SpeechCoordinator.shared.speak(text)
    }
}

struct TranslationLanguageMenuLabel: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: DesignTokens.spaceS) {
            Image(systemName: systemImage)
                .foregroundStyle(DesignTokens.accent)
                .frame(width: 16)
            Text(value)
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: DesignTokens.spaceXS)
        }
        .padding(.horizontal, DesignTokens.spaceM)
        .padding(.vertical, DesignTokens.spaceS)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(DesignTokens.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.radiusS)
                .stroke(DesignTokens.divider.opacity(0.45), lineWidth: 0.5)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(value)")
    }
}

struct StateLine: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: DesignTokens.spaceS) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(title).font(AppFont.body).foregroundStyle(DesignTokens.secondaryText)
        }
    }
}

struct BreathingDot: View {
    let reduceMotion: Bool
    @State private var active = false

    var body: some View {
        Circle()
            .fill(DesignTokens.accent.opacity(0.75))
            .frame(width: 7, height: 7)
            .scaleEffect(reduceMotion ? 1 : (active ? 1.25 : 0.72))
            .opacity(active ? 0.9 : 0.45)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { active = true }
            }
    }
}

struct ErrorStateView: View {
    let message: String
    let recoveryAction: CardRecoveryAction?
    let onRecovery: (CardRecoveryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            Text("翻译没有完成")
                .font(AppFont.bodyEmphasis)
                .foregroundStyle(DesignTokens.primaryText)
            Text(message)
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
            if let recoveryAction {
                Button(recoveryAction.title) { onRecovery(recoveryAction) }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.accent)
                    .controlSize(.small)
            }
        }
    }
}

struct PartialFailureView: View {
    let message: String
    let recoveryAction: CardRecoveryAction?
    let onRecovery: (CardRecoveryAction) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spaceS) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(DesignTokens.warning)
            Text(message)
                .font(AppFont.micro)
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(2)
            Spacer(minLength: DesignTokens.spaceS)
            if let recoveryAction {
                Button(recoveryAction.title) { onRecovery(recoveryAction) }
                    .buttonStyle(.borderless)
                    .font(AppFont.caption)
            }
        }
        .padding(DesignTokens.spaceS)
        .background(DesignTokens.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
    }
}

