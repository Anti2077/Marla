import AppKit
import MarlaCore
import SwiftUI
import UniformTypeIdentifiers

enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case languages
    case api
    case shortcuts
    case ocr
    case lab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .languages: "翻译语言"
        case .api: "翻译 API"
        case .shortcuts: "快捷键"
        case .ocr: "OCR"
        case .lab: "实验室"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .languages: "character.book.closed"
        case .api: "network"
        case .shortcuts: "command"
        case .ocr: "text.viewfinder"
        case .lab: "flask"
        }
    }
}
struct APIProfileEditorPresentation: Identifiable, Equatable {
    let profileID: UUID
    let isNew: Bool

    var id: UUID { profileID }
}

struct SettingsView: View {
    @ObservedObject var settings: MarlaSettingsStore
    @ObservedObject var appModel: MarlaApplicationModel
    @State private var selectedPage: SettingsPage = .general
    @State private var editorPresentation: APIProfileEditorPresentation?
    @State private var pendingNewProfileID: UUID?
    @State private var apiProfileReorder = APIProfileReorderState()
    @State private var editingShortcutAction: GlobalShortcutAction?
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.marlaReduceMotionOverride) private var reduceMotionOverride

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
            Divider()
                .padding(.vertical, DesignTokens.radiusM)
            Group {
                switch selectedPage {
                case .general: generalPage
                case .languages: languagesPage
                case .api: apiPage
                case .shortcuts: shortcutsPage
                case .ocr: ocrPage
                case .lab: labPage
                }
            }
            .id(selectedPage)
            .transition(MarlaMotion.contentTransition(reducesMotion: reducesMotion))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .animation(
            MarlaMotion.animation(
                MarlaMotion.content,
                reducesMotion: reducesMotion,
                reducedMotionAnimation: MarlaMotion.reducedOpacity
            ),
            value: selectedPage
        )
        .frame(minWidth: 820, minHeight: 560)
        .environment(
            \.marlaReduceMotionOverride,
            ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
        )
        .marlaGlassSurface(cornerRadius: DesignTokens.radiusL)
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            applyPendingNavigation()
            if let rawPage = ProcessInfo.processInfo.environment["MARLA_UI_TEST_SETTINGS_PAGE"],
               let page = SettingsPage(rawValue: rawPage) {
                selectedPage = page
                if ProcessInfo.processInfo.environment["MARLA_UI_TEST_SETTINGS_EDITOR"] == "1" {
                    DispatchQueue.main.async {
                        editorPresentation = settings.profiles.first.map {
                            APIProfileEditorPresentation(profileID: $0.id, isNew: false)
                        }
                    }
                }
            }
        }
        .onChange(of: settings.settingsNavigationDestination) { _, _ in
            applyPendingNavigation()
        }
        .onChange(of: selectedPage) { _, page in
            if page != .shortcuts {
                editingShortcutAction = nil
            }
        }
        .sheet(item: $editorPresentation, onDismiss: discardAbandonedNewProfile) { presentation in
            if let profile = settings.profile(id: presentation.profileID) {
                APIProfileEditorView(
                    settings: settings,
                    profile: profile,
                    isNew: presentation.isNew,
                    onCancel: { cancelEditor(presentation) },
                    onClose: completeEditor
                )
                .frame(width: 660, height: 500)
                // SwiftUI's sheet host can keep a rectangular AppKit backing
                // surface behind the rounded content. Configure that host as
                // transparent and clipped so all four corners (including the
                // right edge) follow the editor surface.
                .background {
                    SheetWindowCornerConfigurator(cornerRadius: DesignTokens.radiusL)
                        .frame(width: 1, height: 1)
                }
            } else {
                ContentUnavailableView("配置已删除", systemImage: "network.slash")
                    .frame(width: 420, height: 220)
            }
        }
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
            Text("设置")
                .font(AppFont.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.secondaryText)
                .padding(.horizontal, DesignTokens.spaceM)
                .padding(.top, 36)
                .padding(.bottom, DesignTokens.spaceXS)
            ForEach(SettingsPage.allCases) { page in
                Button {
                    selectedPage = page
                } label: {
                    Label(page.title, systemImage: page.symbolName)
                        .font(AppFont.body)
                        .foregroundStyle(selectedPage == page ? DesignTokens.primaryText : DesignTokens.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignTokens.spaceM)
                        .padding(.vertical, DesignTokens.spaceS)
                        .background(selectedPage == page ? DesignTokens.accent.opacity(0.16) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
                }
                .buttonStyle(.plain)
                .animation(
                    MarlaMotion.animation(MarlaMotion.feedback, reducesMotion: reducesMotion),
                    value: selectedPage
                )
                .accessibilityAddTraits(selectedPage == page ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spaceS)
        .frame(width: 180, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(DesignTokens.secondarySurface.opacity(0.7))
    }

    private var generalPage: some View {
        SettingsPageShell(
            title: "通用",
            subtitle: "权限与 Marla 的基础行为"
        ) {
            SettingsSection(title: "权限", systemImage: "lock.shield") {
                PermissionSettingRow(
                    title: "辅助功能",
                    detail: "划词翻译需要向当前应用发送一次受保护的 Copy。",
                    isReady: appModel.accessibilityTrusted
                ) { appModel.requestAccessibilityAccess() }
                PermissionSettingRow(
                    title: "屏幕录制",
                    detail: "截图翻译只捕获你拖动框选的区域。",
                    isReady: appModel.screenRecordingAuthorized
                ) { appModel.requestScreenRecordingAccess() }
                HStack {
                    Spacer()
                    Button("打开系统设置") { openPrivacySettings() }
                        .buttonStyle(.bordered)
                }
            }

            SettingsSection(title: "翻译窗口位置", systemImage: "macwindow") {
                Picker("出现位置", selection: $settings.translationWindowPlacement) {
                    ForEach(TranslationWindowPlacement.allCases) { placement in
                        Text(placement.title).tag(placement)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(settings.translationWindowPlacement.detail)
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if settings.translationWindowPlacement == .rememberLastPosition {
                    Label("拖动翻译窗口后，下次会从这个位置打开。", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .transition(MarlaMotion.contentTransition(reducesMotion: reducesMotion))
                }

                if settings.translationWindowPlacement == .fixedXCentered {
                    HStack(spacing: DesignTokens.spaceM) {
                        Text("固定 X 坐标")
                            .font(AppFont.body)
                        Spacer()
                        TextField(
                            "X",
                            value: Binding(
                                get: { Double(settings.translationWindowFixedX) },
                                set: { settings.translationWindowFixedX = CGFloat($0.isFinite ? $0 : 0) }
                            ),
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                        .accessibilityLabel("固定 X 坐标")
                        Text("pt")
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    .frame(minHeight: 32)
                    .transition(MarlaMotion.contentTransition(reducesMotion: reducesMotion))
                }
            }
            .animation(
                MarlaMotion.animation(
                    MarlaMotion.content,
                    reducesMotion: reducesMotion,
                    reducedMotionAnimation: MarlaMotion.reducedOpacity
                ),
                value: settings.translationWindowPlacement
            )

            SettingsSection(title: "受保护取词", systemImage: "doc.on.clipboard") {
                Label("模拟 Copy 获取完整选区格式", systemImage: "checkmark.shield")
                    .font(AppFont.body)
                Text("每次划词都会先备份剪贴板，再模拟一次 ⌘C；读取本次新增的文本与格式后恢复原内容。检测到其他应用同时写入时，不会覆盖更新内容。")
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsSection(title: "隐私边界", systemImage: "hand.raised") {
                Text("截图只在本机通过 Vision 识别。只有识别出的文字会发送到当前翻译 API，截图像素不会上传；最近三条译文只保留在本次运行内存中，退出即清空。")
                    .font(AppFont.body)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var apiPage: some View {
        SettingsPageShell(
            title: "翻译 API",
            subtitle: "选择一个配置开始新的翻译会话"
        ) {
            HStack(alignment: .firstTextBaseline) {
                Text("已保存配置")
                    .font(AppFont.bodyEmphasis)
                Spacer()
                Button {
                    beginAddingProfile()
                } label: {
                    Label("添加配置", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.accent)
            }

            if settings.profiles.isEmpty || ProcessInfo.processInfo.environment["MARLA_UI_TEST_SETTINGS_EMPTY"] == "1" {
                ContentUnavailableView(
                    "还没有翻译配置",
                    systemImage: "network.slash",
                    description: Text("添加一个 OpenAI-compatible 端点开始使用 Marla。")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                let displayedProfiles = apiProfileReorder.orderedProfiles(settings.profiles)
                VStack(spacing: 0) {
                    ForEach(Array(displayedProfiles.enumerated()), id: \.element.id) { index, profile in
                        APIProfileSummaryRow(
                            profile: profile,
                            isDefault: settings.defaultProfileID == profile.id,
                            onEnabledChange: { settings.setProfileEnabled($0, for: profile.id) },
                            onOpen: {
                                editorPresentation = APIProfileEditorPresentation(
                                    profileID: profile.id,
                                    isNew: false
                                )
                            },
                            onSetDefault: { settings.setDefaultProfile(profile.id) },
                            onMoveUp: { settings.moveProfile(id: profile.id, by: -1) },
                            onMoveDown: { settings.moveProfile(id: profile.id, by: 1) },
                            onDelete: { removeProfile(profile.id) },
                            canMoveUp: index > 0,
                            canMoveDown: index < displayedProfiles.count - 1,
                            activeProfileID: apiProfileReorder.activeProfileID,
                            sourceIsHidden: apiProfileReorder.sourceIsHidden
                                && apiProfileReorder.activeProfileID == profile.id,
                            onDragStarted: {
                                withAnimation(
                                    MarlaMotion.animation(
                                        MarlaMotion.feedback,
                                        reducesMotion: reducesMotion,
                                        reducedMotionAnimation: MarlaMotion.reducedOpacity
                                    )
                                ) {
                                    apiProfileReorder.begin(
                                        profileID: profile.id,
                                        order: settings.profiles.map(\.id)
                                    )
                                }
                            },
                            onDragMoved: { screenY, startingFrame in
                                withAnimation(
                                    MarlaMotion.animation(
                                        MarlaMotion.reorder,
                                        reducesMotion: reducesMotion
                                    )
                                ) {
                                    _ = apiProfileReorder.moveInsertion(
                                        screenY: screenY,
                                        startingFrame: startingFrame
                                    )
                                }
                            },
                            onDropEntered: { targetProfileID, pointerYFraction in
                                _ = apiProfileReorder.moveInsertion(
                                    relativeTo: targetProfileID,
                                    pointerYFraction: pointerYFraction
                                )
                            },
                            onDropResolved: { succeeded in
                                let indexDelta = succeeded ? apiProfileReorder.activeIndexDelta : 0
                                let committedOrder = withAnimation(
                                    MarlaMotion.animation(MarlaMotion.reorder, reducesMotion: reducesMotion)
                                ) {
                                    apiProfileReorder.resolve(success: succeeded)
                                }
                                if let committedOrder {
                                    _ = settings.setProfileOrder(committedOrder)
                                }
                                return indexDelta
                            },
                            onSourceReveal: {
                                withAnimation(
                                    MarlaMotion.animation(
                                        MarlaMotion.feedback,
                                        reducesMotion: reducesMotion,
                                        reducedMotionAnimation: MarlaMotion.reducedOpacity
                                    )
                                ) {
                                    apiProfileReorder.revealSource()
                                }
                            },
                            onDragFinished: {
                                apiProfileReorder.finish()
                            }
                        )
                        if index < settings.profiles.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, DesignTokens.spaceM)
                .marlaGlassSurface(cornerRadius: DesignTokens.radiusM)
            }

            Text("列表只显示摘要。点击配置后，在编辑窗口中管理 Base URL、模型、Key 和连接测试。")
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .onDrop(
            of: [UTType.plainText.identifier],
            delegate: APIProfileExtendedDropDelegate(
                activeProfileID: apiProfileReorder.activeProfileID
            )
        )
    }

    private var languagesPage: some View {
        SettingsPageShell(
            title: "翻译语言",
            subtitle: "一次设置，自动决定每次翻译的方向"
        ) {
            SettingsSection(title: "自动语言路由", systemImage: "arrow.left.arrow.right") {
                LanguagePreferenceRow(
                    title: "母语",
                    detail: "阅读其它语言时，默认翻译成母语。",
                    selection: settings.nativeLanguage,
                    disabledLanguage: settings.secondaryLanguage,
                    onSelect: settings.setNativeLanguage
                )
                Divider()
                LanguagePreferenceRow(
                    title: "第二语言",
                    detail: "原文就是母语时，默认翻译成第二语言。",
                    selection: settings.secondaryLanguage,
                    disabledLanguage: settings.nativeLanguage,
                    onSelect: settings.setSecondaryLanguage
                )
            }

            SettingsSection(title: "当前规则", systemImage: "point.3.connected.trianglepath.dotted") {
                LanguageRouteSummary(
                    nativeLanguage: settings.nativeLanguage,
                    secondaryLanguage: settings.secondaryLanguage
                )
                Text("语言识别只在本机处理当前原文。识别不确定时，Marla 会把目标设为母语，并允许你在结果卡中覆盖源语言或目标语言。")
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var shortcutsPage: some View {
        SettingsPageShell(
            title: "快捷键",
            subtitle: "把翻译入口绑定到顺手的组合键"
        ) {
            SettingsSection(title: "全局入口", systemImage: "command") {
                ForEach(GlobalShortcutAction.allCases, id: \.self) { action in
                    if action != .inPlace || settings.isInPlaceTranslationEnabled {
                        ShortcutEditorRow(
                            action: action,
                            shortcuts: appModel.shortcutManager,
                            editingAction: $editingShortcutAction
                        )
                    }
                }
                if !settings.isInPlaceTranslationEnabled {
                    Label("原位翻译快捷键在实验室中启用后显示。", systemImage: "flask")
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                HStack(spacing: DesignTokens.spaceM) {
                    Image(systemName: "escape")
                        .foregroundStyle(DesignTokens.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("取消截图框选")
                            .font(AppFont.body)
                        Text("截图界面始终保留此安全退出方式。")
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    Spacer()
                    Text("Esc")
                        .font(AppFont.micro.monospacedDigit())
                        .foregroundStyle(DesignTokens.secondaryText)
                    Text("系统固定")
                        .font(AppFont.micro)
                        .foregroundStyle(DesignTokens.tertiaryText)
                }
                .frame(minHeight: 32)
                HStack {
                    Text("应用内冲突与已占用的系统组合键都会立即提示。")
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                    Spacer()
                    Button("恢复默认") {
                        editingShortcutAction = nil
                        appModel.shortcutManager.restoreDefaults()
                    }
                        .buttonStyle(.borderless)
                }
                if let conflictMessage = appModel.shortcutManager.conflictMessage {
                    Text(conflictMessage)
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.warning)
                }
            }
        }
    }

    private var ocrPage: some View {
        SettingsPageShell(
            title: "OCR",
            subtitle: "截图文字识别的当前状态"
        ) {
            OCRSettingsSection(settings: settings)
            Text("云端 GLM-OCR 与本机 Ollama GLM-OCR 均由 Marla 固定管理接口；本机模式不需要 API Key。")
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    private var labPage: some View {
        SettingsPageShell(
            title: "实验室",
            subtitle: "试验中的能力，默认关闭，随时可以撤回"
        ) {
            ExperimentalSettingsSection(
                settings: settings,
                appModel: appModel
            )
        }
    }

    private func applyPendingNavigation() {
        switch settings.settingsNavigationDestination {
        case .ocr:
            selectedPage = .ocr
            settings.consumeSettingsNavigation(.ocr)
        case .lab:
            selectedPage = .lab
            settings.consumeSettingsNavigation(.lab)
        case nil:
            break
        }
    }

    private func removeProfile(_ id: UUID) {
        settings.removeProfile(id: id)
        if editorPresentation?.profileID == id { completeEditor() }
    }

    private func beginAddingProfile() {
        let id = settings.addProfile()
        pendingNewProfileID = id
        editorPresentation = APIProfileEditorPresentation(profileID: id, isNew: true)
    }

    private func cancelEditor(_ presentation: APIProfileEditorPresentation) {
        if presentation.isNew {
            settings.removeProfile(id: presentation.profileID)
        }
        pendingNewProfileID = nil
        editorPresentation = nil
    }

    private func completeEditor() {
        pendingNewProfileID = nil
        editorPresentation = nil
    }

    private func discardAbandonedNewProfile() {
        guard let pendingNewProfileID else { return }
        settings.removeProfile(id: pendingNewProfileID)
        self.pendingNewProfileID = nil
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private var reducesMotion: Bool {
        accessibilityReduceMotion
            || reduceMotionOverride
            || ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
    }
}
