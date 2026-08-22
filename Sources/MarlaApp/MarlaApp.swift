import AppKit
import Combine
import Foundation
import MarlaCore
import SwiftUI

import AppKit
import AVFoundation
import MarlaCore
import SwiftUI

private struct MarlaReduceMotionOverrideKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var marlaReduceMotionOverride: Bool {
        get { self[MarlaReduceMotionOverrideKey.self] }
        set { self[MarlaReduceMotionOverrideKey.self] = newValue }
    }
}

private struct MarlaGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let isSnapshotRenderer = ProcessInfo.processInfo.environment["MARLA_UI_TEST_CAPTURE_PATH"] != nil
        if #available(macOS 26.0, *), !isSnapshotRenderer {
            ZStack {
                Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                content
            }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(DesignTokens.divider.opacity(0.55), lineWidth: 0.5)
                }
        } else {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(DesignTokens.divider.opacity(0.65), lineWidth: 0.5)
                }
        }
    }
}

extension View {
    func marlaGlassSurface(cornerRadius: CGFloat = DesignTokens.radiusL) -> some View {
        modifier(MarlaGlassSurfaceModifier(cornerRadius: cornerRadius))
    }
}

enum DesignTokens {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let primaryText = Color(nsColor: .labelColor)
    static let secondarySurface = primaryText.opacity(0.055)
    static let inputSurface = Color(nsColor: .textBackgroundColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    static let divider = Color(nsColor: .separatorColor)
    static let accent = Color.accentColor
    static let success = Color(nsColor: .systemGreen)
    static let warning = Color(nsColor: .systemOrange)
    static let error = Color(nsColor: .systemRed)

    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 16
}

enum AppFont {
    static let title = Font.system(size: 17, weight: .semibold)
    static let translation = Font.system(size: 15, weight: .regular)
    static let body = Font.system(size: 14, weight: .regular)
    static let bodyEmphasis = Font.system(size: 14, weight: .medium)
    static let source = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let micro = Font.system(size: 11, weight: .regular)
}

@MainActor
final class SpeechCoordinator {
    static let shared = SpeechCoordinator()
    private let synthesizer = AVSpeechSynthesizer()
    private var currentText: String?

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            if currentText == text {
                currentText = nil
                return
            }
        }
        currentText = text
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: text.range(
            of: #"\p{Han}"#,
            options: .regularExpression
        ) == nil ? "en-US" : "zh-CN")
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        currentText = nil
    }
}

@main
struct MarlaApplication: App {
    @StateObject private var model = MarlaApplicationModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Image("StatusBarIcon")
                .renderingMode(.template)
                .frame(width: 18, height: 18)
                .accessibilityLabel("Marla")
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    model.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView(settings: model.settings, appModel: model)
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var model: MarlaApplicationModel
    @ObservedObject private var settings: MarlaSettingsStore
    @ObservedObject private var shortcuts: GlobalShortcutManager
    let usesStandaloneGlassSurface: Bool

    init(model: MarlaApplicationModel, usesStandaloneGlassSurface: Bool = false) {
        self.model = model
        settings = model.settings
        shortcuts = model.shortcutManager
        self.usesStandaloneGlassSurface = usesStandaloneGlassSurface
    }

    private var setupReady: Bool {
        settings.hasAPIConfiguration && model.accessibilityTrusted && model.screenRecordingAuthorized
    }

    var body: some View {
        Group {
            if usesStandaloneGlassSurface {
                menuContent
                    .marlaGlassSurface(cornerRadius: 20)
            } else {
                menuContent
            }
        }
        .onAppear { model.refreshPermissions() }
    }

    private var menuContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceL) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Marla")
                        .font(AppFont.title)
                    Text("安静地出现在你正在阅读的地方")
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                .offset(y: -14)
                Spacer()
                Image("PaperLanternMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 33.6, height: 33.6)
                    .offset(y: 2)
                    .accessibilityHidden(true)
            }

            if !settings.onboardingSkipped,
               !(settings.hasAPIConfiguration && model.accessibilityTrusted && model.screenRecordingAuthorized) {
                OnboardingChecklistView(model: model)
            }

            VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
                Text("开始翻译")
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .textCase(.uppercase)
                EntryButton(
                    title: "划词翻译",
                    shortcut: shortcuts.bindings[.selection]?.displayName ?? "⌃⌥D",
                    symbol: "text.viewfinder"
                ) {
                    model.translateSelection()
                }
                EntryButton(
                    title: "截图翻译",
                    shortcut: shortcuts.bindings[.screenshot]?.displayName ?? "⌃⌥S",
                    symbol: TranslationSurface.screenshot.symbolName
                ) {
                    model.translateScreenshot()
                }
                EntryButton(
                    title: "快速输入",
                    shortcut: shortcuts.bindings[.quickInput]?.displayName ?? "⌃⌥Space",
                    symbol: "keyboard"
                ) {
                    model.showQuickInput()
                }
            }

            if setupReady {
                RecentTranslationsSection(store: model.sessionStore) { id in
                    model.showRecentTranslation(id: id)
                }
            } else {
                HStack(spacing: DesignTokens.spaceS) {
                    PermissionChip(title: "API", isReady: settings.hasAPIConfiguration) {
                        model.openSettings()
                    }
                    PermissionChip(title: "辅助功能", isReady: model.accessibilityTrusted) {
                        model.requestAccessibilityAccess()
                    }
                    PermissionChip(title: "屏幕录制", isReady: model.screenRecordingAuthorized) {
                        model.requestScreenRecordingAccess()
                    }
                }
            }

            if let session = model.sessionStore.session, !session.state.isCompleted {
                SessionSummary(session: session)
            }

            Divider()

            HStack(spacing: DesignTokens.spaceS) {
                Button {
                    model.openSettings()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("打开 Marla 设置")
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("退出", systemImage: "power")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(DesignTokens.spaceL)
        .frame(width: 330)
    }
}

struct EntryButton: View {
    let title: String
    let shortcut: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spaceM) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(DesignTokens.accent)
                Text(title)
                    .font(AppFont.bodyEmphasis)
                    .foregroundStyle(DesignTokens.primaryText)
                Spacer()
                Text(shortcut)
                    .font(AppFont.micro.monospacedDigit())
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            .padding(.horizontal, DesignTokens.spaceM)
            .frame(height: 44)
            .background(DesignTokens.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("\(title)，快捷键 \(shortcut)")
    }
}

struct RecentTranslationsSection: View {
    @ObservedObject var store: TranslationSessionStore
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近翻译")
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                Spacer()
                Text("退出即清空")
                    .font(AppFont.micro)
                    .foregroundStyle(DesignTokens.tertiaryText)
            }

            if store.recentTranslations.isEmpty {
                HStack(spacing: DesignTokens.spaceS) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(DesignTokens.secondaryText)
                    Text("完成翻译后会显示在这里")
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.spaceM)
                .frame(minHeight: 44)
                .background(DesignTokens.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
            } else {
                ForEach(store.recentTranslations) { recent in
                    Button {
                        onSelect(recent.id)
                    } label: {
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
                        .padding(.horizontal, DesignTokens.spaceM)
                        .frame(minHeight: 44)
                        .background(DesignTokens.secondarySurface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("重新打开这条译文")
                    .accessibilityLabel("最近翻译：\(recent.displayTranslation)")
                }
            }
        }
    }
}

struct PermissionChip: View {
    let title: String
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spaceXS) {
                Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isReady ? DesignTokens.success : DesignTokens.warning)
                Text(title)
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.primaryText)
            }
            .frame(minWidth: 88, minHeight: 44)
            .background(DesignTokens.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
        }
        .buttonStyle(.plain)
        .help(isReady ? "已授权" : "点击请求权限")
    }
}

struct SessionSummary: View {
    let session: CardSession

    var body: some View {
        HStack(spacing: DesignTokens.spaceS) {
            Circle()
                .fill(session.state.isFailure ? DesignTokens.error : DesignTokens.accent)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.surface.displayName)
                    .font(AppFont.caption)
                Text(session.statusLabel)
                    .font(AppFont.micro)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            Spacer()
        }
        .padding(DesignTokens.spaceS)
        .background(DesignTokens.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
    }
}

struct OnboardingChecklistView: View {
    @ObservedObject var model: MarlaApplicationModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            Text("完成三项准备")
                .font(AppFont.bodyEmphasis)
            ChecklistRow(title: "配置翻译 API", detail: "快速输入可用后，三个入口都会使用真实流式翻译。", isReady: model.settings.hasAPIConfiguration) {
                model.openSettings()
            }
            ChecklistRow(title: "辅助功能", detail: "允许 Marla 读取当前应用明确选中的文字。", isReady: model.accessibilityTrusted) {
                model.requestAccessibilityAccess()
            }
            ChecklistRow(title: "屏幕录制", detail: "允许截图翻译捕获你明确框选的区域。", isReady: model.screenRecordingAuthorized) {
                model.requestScreenRecordingAccess()
            }
            Button("稍后完成") {
                model.settings.skipOnboarding()
            }
            .buttonStyle(.borderless)
            .font(AppFont.caption)
            .foregroundStyle(DesignTokens.secondaryText)
        }
        .padding(DesignTokens.spaceM)
        .background(DesignTokens.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusL))
    }
}

struct ChecklistRow: View {
    let title: String
    let detail: String
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DesignTokens.spaceS) {
                Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isReady ? DesignTokens.success : DesignTokens.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AppFont.bodyEmphasis)
                    Text(detail)
                        .font(AppFont.micro)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
