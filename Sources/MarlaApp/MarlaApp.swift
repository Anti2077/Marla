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
            Image(systemName: "character.bubble")
                .accessibilityLabel("Marla")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: model.settings, appModel: model)
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var model: MarlaApplicationModel
    @ObservedObject private var settings: MarlaSettingsStore
    @ObservedObject private var shortcuts: GlobalShortcutManager

    init(model: MarlaApplicationModel) {
        self.model = model
        settings = model.settings
        shortcuts = model.shortcutManager
    }

    private var setupReady: Bool {
        settings.hasAPIConfiguration && model.accessibilityTrusted && model.screenRecordingAuthorized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceL) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Marla")
                        .font(AppFont.title)
                    Text("安静地出现在你正在阅读的地方")
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                Spacer()
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(DesignTokens.accent)
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
        .marlaGlassSurface(cornerRadius: 20)
        .onAppear { model.refreshPermissions() }
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
                                Text(recent.translation)
                                    .font(AppFont.caption)
                                    .foregroundStyle(DesignTokens.primaryText)
                                    .lineLimit(1)
                                Text(recent.sourceText)
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
                    .accessibilityLabel("最近翻译：\(recent.translation)")
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

    static func fixedChromeHeight(sourceHeight: CGFloat? = nil) -> CGFloat {
        // Outer padding + header + language row + dividers + actions + 12pt
        // inter-section spacing. The source section is included only when
        // comparison is expanded.
        let base: CGFloat = 32 + 28 + 44 + 2 + 28 + (5 * 12)
        guard let sourceHeight else { return base }
        return base + 12 + 15 + 4 + sourceHeight
    }

    static func translationViewportHeight(
        session: CardSession,
        cardWidth: CGFloat,
        maximumPanelHeight: CGFloat
    ) -> CGFloat {
        let sourceHeight = session.isComparisonExpanded
            ? sourceViewportHeight(session.sourceText, width: cardWidth)
            : nil
        let chrome = fixedChromeHeight(sourceHeight: sourceHeight)
        let failureSupplement: CGFloat = session.translation.isEmpty || !session.state.isFailure ? 0 : 47
        let maximumViewport = max(minimumTranslationViewportHeight, maximumPanelHeight - chrome - failureSupplement)
        let contentHeight = translationTextHeight(session.translation, width: cardWidth)
        return min(maximumViewport, contentHeight)
    }

    static func preferredPanelHeight(
        session: CardSession?,
        cardWidth: CGFloat,
        maximumPanelHeight: CGFloat
    ) -> CGFloat {
        guard let session else { return defaultPanelHeight }
        let sourceHeight = session.isComparisonExpanded
            ? sourceViewportHeight(session.sourceText, width: cardWidth)
            : nil
        let chrome = fixedChromeHeight(sourceHeight: sourceHeight)
        let failureSupplement: CGFloat = session.translation.isEmpty || !session.state.isFailure ? 0 : 47
        let viewport = translationViewportHeight(
            session: session,
            cardWidth: cardWidth,
            maximumPanelHeight: maximumPanelHeight
        )
        let preferred = chrome + viewport + failureSupplement
        return min(maximumPanelHeight, max(defaultPanelHeight, ceil(preferred)))
    }
}

final class ResultPanelLayoutModel: ObservableObject {
    @Published var width: CGFloat
    @Published var maximumPanelHeight: CGFloat

    init(
        width: CGFloat = ResultCardLayout.defaultWidth,
        maximumPanelHeight: CGFloat = .greatestFiniteMagnitude
    ) {
        self.width = width
        self.maximumPanelHeight = maximumPanelHeight
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

private struct TranslationLanguageMenuLabel: View {
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
