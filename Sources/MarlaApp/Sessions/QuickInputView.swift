import AppKit
import Foundation
import MarlaCore
import SwiftUI

struct QuickInputContainerView: View {
    @ObservedObject var store: TranslationSessionStore
    @ObservedObject private var layout: ResultPanelLayoutModel
    let onClose: () -> Void
    let onRecovery: (CardRecoveryAction) -> Void

    init(
        store: TranslationSessionStore,
        onClose: @escaping () -> Void,
        onRecovery: @escaping (CardRecoveryAction) -> Void,
        cardWidth: CGFloat = 420,
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

    var body: some View {
        if store.session?.surface == .quickInput {
            TranslationCardView(
                store: store,
                onClose: onClose,
                onRecovery: onRecovery,
                layout: layout
            )
                .transition(.opacity)
        } else {
            QuickInputView(store: store, onClose: onClose, cardWidth: layout.width)
                .transition(.opacity)
        }
    }
}

enum QuickInputValidation {
    static func isSubmittable(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct QuickInputView: View {
    @ObservedObject var store: TranslationSessionStore
    let onClose: () -> Void
    let cardWidth: CGFloat
    @State private var draft = ""
    @State private var source = TranslationSource.automatic
    @State private var target = TranslationTarget.automatic
    @FocusState private var isFocused: Bool

    init(
        store: TranslationSessionStore,
        onClose: @escaping () -> Void,
        cardWidth: CGFloat = 420
    ) {
        self.store = store
        self.onClose = onClose
        self.cardWidth = cardWidth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
            HStack {
                Image(systemName: "keyboard").foregroundStyle(DesignTokens.accent)
                Text("快速输入").font(AppFont.title)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .help("关闭")
            }
            HStack(spacing: DesignTokens.spaceS) {
                Menu {
                    Button("自动识别") { source = .automatic }
                        .disabled(source.mode == .automatic)
                    Divider()
                    ForEach(TranslationLanguage.allCases) { language in
                        Button(language.label) { source = .explicit(language) }
                            .disabled(source.mode == .explicit && source.language == language)
                    }
                } label: {
                    TranslationLanguageMenuLabel(
                        title: "源语言",
                        value: source.mode == .automatic ? "自动识别" : source.language?.label ?? "自动识别",
                        systemImage: "text.magnifyingglass"
                    )
                }
                .menuStyle(.borderlessButton)
                Image(systemName: "arrow.right")
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.tertiaryText)
                Menu {
                    Button("自动（\(quickInputTargetLanguage.label)）") { target = .automatic }
                        .disabled(target.mode == .automatic)
                    Divider()
                    ForEach(TranslationLanguage.allCases) { language in
                        Button(language.label) { target = .explicit(language) }
                            .disabled(target.mode == .explicit && target.language == language)
                    }
                } label: {
                    TranslationLanguageMenuLabel(
                        title: "目标语言",
                        value: quickInputTargetLanguage.label,
                        systemImage: "character.book.closed"
                    )
                }
                .menuStyle(.borderlessButton)
            }
            TextEditor(text: $draft)
                .font(AppFont.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 104, maxHeight: 128)
                .overlay(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("输入或粘贴要翻译的文字")
                            .font(AppFont.body)
                            .foregroundStyle(DesignTokens.tertiaryText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .allowsHitTesting(false)
                    }
                }
                .padding(DesignTokens.spaceM)
                .background(DesignTokens.inputSurface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                        .stroke(DesignTokens.divider.opacity(0.65), lineWidth: 0.5)
                }
                .focused($isFocused)
            HStack {
                Text("⌘Return 提交 · Esc 关闭")
                    .font(AppFont.micro)
                    .foregroundStyle(DesignTokens.secondaryText)
                Spacer()
                Button("翻译") { submit() }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.accent)
                    .controlSize(.small)
                    .disabled(!QuickInputValidation.isSubmittable(draft))
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(DesignTokens.spaceL)
        .frame(width: cardWidth)
        .marlaGlassSurface()
        .onAppear { isFocused = true }
        .onExitCommand(perform: onClose)
    }

    private func submit() {
        guard QuickInputValidation.isSubmittable(draft) else { return }
        store.startText(
            draft,
            surface: .quickInput,
            anchor: nil,
            pointer: NSEvent.mouseLocation,
            activate: true,
            source: source,
            target: target
        )
    }

    private var quickInputTargetLanguage: TranslationLanguage {
        TranslationLanguageRouter.targetLanguage(
            sourceLanguage: source.language,
            target: target,
            nativeLanguage: store.nativeLanguage,
            secondaryLanguage: store.secondaryLanguage
        )
    }
}

