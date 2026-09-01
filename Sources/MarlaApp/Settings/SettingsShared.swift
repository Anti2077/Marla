import AppKit
import MarlaCore
import SwiftUI

struct SheetWindowCornerConfigurator: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.alphaValue = 0
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(for: nsView)
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = cornerRadius
        window.contentView?.layer?.cornerCurve = .continuous
        window.contentView?.layer?.masksToBounds = true
    }
}

struct SettingsPageShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spaceL) {
                VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                    Text(title).font(AppFont.title)
                    Text(subtitle).font(AppFont.body).foregroundStyle(DesignTokens.secondaryText)
                }
                content()
            }
            .frame(maxWidth: 650, alignment: .leading)
            .padding(.horizontal, DesignTokens.spaceL)
            .padding(.top, 36)
            .padding(.bottom, DesignTokens.spaceM)
        }
        .scrollIndicators(.never)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
            Label(title, systemImage: systemImage)
                .font(AppFont.bodyEmphasis)
                .foregroundStyle(DesignTokens.primaryText)
            content()
        }
        .padding(DesignTokens.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .marlaGlassSurface(cornerRadius: DesignTokens.radiusM)
    }
}

struct LanguagePreferenceRow: View {
    let title: String
    let detail: String
    let selection: TranslationLanguage
    let disabledLanguage: TranslationLanguage
    let onSelect: (TranslationLanguage) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spaceL) {
            VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                Text(title)
                    .font(AppFont.bodyEmphasis)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            Spacer(minLength: DesignTokens.spaceL)
            Menu {
                ForEach(TranslationLanguage.allCases) { language in
                    Button {
                        onSelect(language)
                    } label: {
                        if language == selection {
                            Label(language.label, systemImage: "checkmark")
                        } else {
                            Text(language.label)
                        }
                    }
                    .disabled(language == disabledLanguage || language == selection)
                }
            } label: {
                Text(selection.label)
                    .font(AppFont.body)
                .frame(minWidth: 112, alignment: .trailing)
                .padding(.horizontal, DesignTokens.spaceM)
                .padding(.vertical, DesignTokens.spaceS)
                .background(DesignTokens.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("\(title)：\(selection.label)")
        }
        .frame(minHeight: 44)
    }
}

struct LanguageRouteSummary: View {
    let nativeLanguage: TranslationLanguage
    let secondaryLanguage: TranslationLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            route(sourceLabel: nativeLanguage.label, target: secondaryLanguage, emphasis: true)
            route(sourceLabel: secondaryLanguage.label, target: nativeLanguage, emphasis: false)
            route(sourceLabel: "其它语言 / 未知", target: nativeLanguage, emphasis: false)
        }
    }

    private func route(
        sourceLabel: String,
        target: TranslationLanguage,
        emphasis: Bool
    ) -> some View {
        HStack(spacing: DesignTokens.spaceS) {
            Text(sourceLabel)
                .frame(width: 120, alignment: .trailing)
            Image(systemName: "arrow.right")
                .foregroundStyle(DesignTokens.accent)
            Text(target.label)
                .frame(width: 92, alignment: .leading)
            if emphasis {
                Text("原文是母语")
                    .font(AppFont.micro)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .font(AppFont.body)
        .accessibilityElement(children: .combine)
    }
}
