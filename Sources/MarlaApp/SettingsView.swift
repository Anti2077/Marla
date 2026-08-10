import AppKit
import MarlaCore
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case languages
    case api
    case shortcuts
    case ocr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .languages: "翻译语言"
        case .api: "翻译 API"
        case .shortcuts: "快捷键"
        case .ocr: "OCR"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .languages: "character.book.closed"
        case .api: "network"
        case .shortcuts: "command"
        case .ocr: "text.viewfinder"
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
    @State private var draggingProfileID: UUID?

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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 820, minHeight: 560)
        .marlaGlassSurface(cornerRadius: DesignTokens.radiusL)
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
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
                    detail: "划词翻译需要读取当前应用明确选中的文字。",
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

            SettingsSection(title: "兼容性取词", systemImage: "arrow.triangle.2.circlepath") {
                Toggle("AX 失败时模拟 ⌘C", isOn: $settings.selectionCopyFallbackEnabled)
                Text("默认关闭。开启后，Marla 会先备份剪贴板，在 AX 无法读取时模拟一次 ⌘C，读取新文本后恢复原内容；检测到其他应用同时写入时不会覆盖更新内容。")
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
                VStack(spacing: 0) {
                    ForEach(Array(settings.profiles.enumerated()), id: \.element.id) { index, profile in
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
                            onDrop: { settings.moveProfile(id: $0, onto: profile.id) },
                            onDelete: { removeProfile(profile.id) },
                            canMoveUp: index > 0,
                            canMoveDown: index < settings.profiles.count - 1,
                            draggingProfileID: $draggingProfileID
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
                    ShortcutRecorderRow(
                        action: action,
                        binding: appModel.shortcutManager.bindings[action] ?? .defaults[action]!,
                        isEnabled: appModel.shortcutManager.isEnabled(action),
                        onEnabledChange: { appModel.shortcutManager.setEnabled($0, for: action) },
                        onChange: { appModel.shortcutManager.set($0, for: action) }
                    )
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
                    Button("恢复默认") { appModel.shortcutManager.restoreDefaults() }
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
            SettingsSection(title: "本机 Vision", systemImage: "text.viewfinder") {
                StatusLine(icon: "checkmark.circle.fill", tint: DesignTokens.success, title: "当前使用 Vision", detail: "macOS Vision 在本机识别截图中的文字。")
                StatusLine(icon: "lock.fill", tint: DesignTokens.accent, title: "截图不会上传", detail: "截图像素只在内存中处理；只有识别出的纯文本会进入当前翻译 API。")
                StatusLine(icon: "text.alignleft", tint: DesignTokens.secondaryText, title: "识别范围", detail: "0.1.0 保留文字与行顺序，不承诺表格、公式或页面布局恢复。")
            }
            Text("此页面仅展示 0.1.0 的固定 OCR 路径，不提供云端 provider 或额外质量参数。")
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
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
}

private struct SheetWindowCornerConfigurator: NSViewRepresentable {
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

private struct SettingsPageShell<Content: View>: View {
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

private struct SettingsSection<Content: View>: View {
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

private struct LanguagePreferenceRow: View {
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

private struct LanguageRouteSummary: View {
    let nativeLanguage: TranslationLanguage
    let secondaryLanguage: TranslationLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            route(source: nativeLanguage, target: secondaryLanguage, emphasis: true)
            ForEach(TranslationLanguage.allCases.filter { $0 != nativeLanguage }) { language in
                route(source: language, target: nativeLanguage, emphasis: false)
            }
        }
    }

    private func route(
        source: TranslationLanguage,
        target: TranslationLanguage,
        emphasis: Bool
    ) -> some View {
        HStack(spacing: DesignTokens.spaceS) {
            Text(source.label)
                .frame(width: 92, alignment: .trailing)
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

private struct APIProfileSummaryRow: View {
    let profile: TranslationAPIProfile
    let isDefault: Bool
    let onEnabledChange: (Bool) -> Void
    let onOpen: () -> Void
    let onSetDefault: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDrop: (UUID) -> Bool
    let onDelete: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    @Binding var draggingProfileID: UUID?

    private var isDragging: Bool {
        draggingProfileID == profile.id
    }

    var body: some View {
        HStack(spacing: DesignTokens.spaceM) {
                Toggle(
                    "启用配置",
                    isOn: Binding(
                        get: { profile.isEnabled },
                        set: { isEnabled in onEnabledChange(isEnabled) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(profile.isEnabled ? "停用配置" : "启用配置")
                .accessibilityLabel("启用配置")

                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: DesignTokens.spaceS) {
                            Text(profile.name.isEmpty ? "未命名配置" : profile.name)
                                .font(AppFont.bodyEmphasis)
                            if isDefault {
                                Text("默认")
                                    .font(AppFont.micro)
                                    .foregroundStyle(DesignTokens.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(DesignTokens.accent.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(profile.modelName.isEmpty ? "尚未配置模型" : profile.modelName)
                            .font(AppFont.micro)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: DesignTokens.spaceM)
                Label(profile.isConfigured ? "配置完整" : "需要完善", systemImage: profile.isConfigured ? "checkmark.shield" : "exclamationmark.triangle")
                    .font(AppFont.micro)
                    .foregroundStyle(profile.isConfigured ? DesignTokens.success : DesignTokens.warning)
                Menu {
                    Button("设为默认", action: onSetDefault).disabled(isDefault)
                    Divider()
                    Button("删除配置", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                }
                .menuStyle(.borderlessButton)

                ZStack {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DesignTokens.tertiaryText)

                    APIProfileDragSource(
                        profile: profile,
                        isDefault: isDefault,
                        draggingProfileID: $draggingProfileID
                    )
                }
                .frame(
                    width: APIProfileDragGeometry.handleSize.width,
                    height: APIProfileDragGeometry.handleSize.height
                )
                .contentShape(Rectangle())
                .help("拖动以排序")
                .accessibilityLabel("拖动以排序 \(profile.name)")
                .accessibilityAction(named: "上移") {
                    if canMoveUp { onMoveUp() }
                }
                .accessibilityAction(named: "下移") {
                    if canMoveDown { onMoveDown() }
                }
        }
        .opacity(isDragging ? 0 : 1)
        .allowsHitTesting(!isDragging)
        .padding(.vertical, DesignTokens.spaceM)
        .animation(.easeOut(duration: 0.12), value: isDragging)
        .onDrop(
            of: [UTType.plainText.identifier],
            delegate: APIProfileDropDelegate(
                targetProfileID: profile.id,
                draggingProfileID: $draggingProfileID,
                onMove: onDrop
            )
        )
    }
}

enum APIProfileDragGeometry {
    static let rowSize = CGSize(width: 580, height: 76)
    static let handleSize = CGSize(width: 32, height: 44)
    static let systemDraggingImageSize = CGSize(width: 1, height: 1)
    static let previewHorizontalPadding: CGFloat = DesignTokens.spaceM
    static let previewVerticalPadding: CGFloat = DesignTokens.spaceM

    static var previewSize: CGSize {
        rowSize
    }

    static var handleOriginInPreview: CGPoint {
        CGPoint(
            x: rowSize.width - previewHorizontalPadding - handleSize.width,
            y: previewVerticalPadding
        )
    }

    static func previewFrame(
        pointerLocation: CGPoint,
        handleLocation: CGPoint
    ) -> CGRect {
        let anchor = CGPoint(
            x: handleOriginInPreview.x + handleLocation.x,
            y: handleOriginInPreview.y + handleLocation.y
        )
        return CGRect(
            x: pointerLocation.x - anchor.x,
            y: pointerLocation.y - anchor.y,
            width: previewSize.width,
            height: previewSize.height
        )
    }
}

private struct APIProfileDragSource: NSViewRepresentable {
    let profile: TranslationAPIProfile
    let isDefault: Bool
    @Binding var draggingProfileID: UUID?

    func makeNSView(context: Context) -> APIProfileDragSourceView {
        let view = APIProfileDragSourceView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ nsView: APIProfileDragSourceView, context: Context) {
        nsView.profile = profile
        nsView.isDefault = isDefault
        nsView.onDragStarted = {
            withAnimation(.easeOut(duration: 0.12)) {
                draggingProfileID = profile.id
            }
        }
        nsView.onDragEnded = {
            withAnimation(.easeOut(duration: 0.14)) {
                draggingProfileID = nil
            }
        }
    }
}

@MainActor
private final class APIProfileDragSourceView: NSView, NSDraggingSource {
    var profile: TranslationAPIProfile?
    var isDefault = false
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?

    private var mouseDownEvent: NSEvent?
    private var mouseDownLocation = CGPoint.zero
    private var startedDragging = false
    private var dragPreviewPanel: NSPanel?

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        mouseDownLocation = convert(event.locationInWindow, from: nil)
        startedDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !startedDragging,
              mouseDownEvent != nil,
              let profile else { return }

        let pointerLocation = convert(event.locationInWindow, from: nil)

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(profile.id.uuidString, forType: .string)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let systemImageSize = APIProfileDragGeometry.systemDraggingImageSize
        draggingItem.setDraggingFrame(
            CGRect(
                x: pointerLocation.x - (systemImageSize.width / 2),
                y: pointerLocation.y - (systemImageSize.height / 2),
                width: systemImageSize.width,
                height: systemImageSize.height
            ),
            contents: transparentDraggingImage
        )

        dragPreviewPanel = makeDragPreviewPanel(profile: profile)
        onDragStarted?()
        startedDragging = true
        let session = beginDraggingSession(
            with: [draggingItem],
            event: event,
            source: self
        )
        session.draggingFormation = .none
        session.draggingLeaderIndex = 0
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
        startedDragging = false
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    func draggingSession(
        _ session: NSDraggingSession,
        willBeginAt screenPoint: NSPoint
    ) {
        showDragPreview(at: screenPoint)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        movedTo screenPoint: NSPoint
    ) {
        moveDragPreview(to: screenPoint)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownEvent = nil
        startedDragging = false
        hideDragPreview()
        onDragEnded?()
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    private var transparentDraggingImage: NSImage {
        NSImage(size: APIProfileDragGeometry.systemDraggingImageSize, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            return true
        }
    }

    private func makeDragPreviewPanel(profile: TranslationAPIProfile) -> NSPanel {
        let colorScheme: ColorScheme = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .dark
            : .light

        let hostingView = NSHostingView(
            rootView: APIProfileDragPreview(profile: profile, isDefault: isDefault)
                .environment(\.colorScheme, colorScheme)
        )
        hostingView.frame = CGRect(origin: .zero, size: APIProfileDragGeometry.previewSize)
        hostingView.autoresizingMask = [.width, .height]

        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: APIProfileDragGeometry.previewSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.transient, .ignoresCycle]
        return panel
    }

    private func showDragPreview(at screenPoint: NSPoint) {
        guard let dragPreviewPanel else { return }
        moveDragPreview(to: screenPoint)
        if let window {
            window.addChildWindow(dragPreviewPanel, ordered: .above)
        }
        dragPreviewPanel.orderFront(nil)
    }

    private func moveDragPreview(to screenPoint: NSPoint) {
        dragPreviewPanel?.setFrame(
            APIProfileDragGeometry.previewFrame(
                pointerLocation: screenPoint,
                handleLocation: mouseDownLocation
            ),
            display: true
        )
    }

    private func hideDragPreview() {
        guard let dragPreviewPanel else { return }
        dragPreviewPanel.parent?.removeChildWindow(dragPreviewPanel)
        dragPreviewPanel.orderOut(nil)
        self.dragPreviewPanel = nil
    }
}

private struct APIProfileDragPreview: View {
    let profile: TranslationAPIProfile
    let isDefault: Bool

    var body: some View {
        HStack(spacing: DesignTokens.spaceM) {
            Toggle("启用配置", isOn: .constant(profile.isEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                HStack(spacing: DesignTokens.spaceS) {
                    Text(profile.name.isEmpty ? "未命名配置" : profile.name)
                        .font(AppFont.bodyEmphasis)
                    if isDefault {
                        Text("默认")
                            .font(AppFont.micro)
                            .foregroundStyle(DesignTokens.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DesignTokens.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(profile.modelName.isEmpty ? "尚未配置模型" : profile.modelName)
                    .font(AppFont.micro)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            Spacer(minLength: DesignTokens.spaceM)

            Label(
                profile.isConfigured ? "配置完整" : "需要完善",
                systemImage: profile.isConfigured ? "checkmark.shield" : "exclamationmark.triangle"
            )
            .font(AppFont.micro)
            .foregroundStyle(profile.isConfigured ? DesignTokens.success : DesignTokens.warning)

            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17))
                .foregroundStyle(DesignTokens.secondaryText)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DesignTokens.tertiaryText)
                .frame(width: 32, height: 44)
        }
        .padding(.horizontal, APIProfileDragGeometry.previewHorizontalPadding)
        .padding(.vertical, APIProfileDragGeometry.previewVerticalPadding)
        .frame(
            width: APIProfileDragGeometry.rowSize.width,
            height: APIProfileDragGeometry.rowSize.height,
            alignment: .leading
        )
        .background(DesignTokens.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous)
                .stroke(DesignTokens.divider.opacity(0.65), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        .frame(
            width: APIProfileDragGeometry.previewSize.width,
            height: APIProfileDragGeometry.previewSize.height
        )
    }
}

private struct APIProfileDropDelegate: DropDelegate {
    let targetProfileID: UUID
    @Binding var draggingProfileID: UUID?
    let onMove: (UUID) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        draggingProfileID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggingProfileID,
              draggingProfileID != targetProfileID else { return }
        withAnimation(.snappy(duration: 0.22)) {
            _ = onMove(draggingProfileID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        return true
    }
}

private struct APIProfileEditorView: View {
    private enum FocusedField: Hashable {
        case profileName
    }

    @ObservedObject var settings: MarlaSettingsStore
    let profile: TranslationAPIProfile
    let isNew: Bool
    let onCancel: () -> Void
    let onClose: () -> Void
    @State private var name: String
    @State private var baseURL: String
    @State private var urlMode: TranslationEndpointURLMode
    @State private var modelName: String
    @State private var apiKeyDraft = ""
    @State private var saveErrorMessage: String?
    @State private var isModelListExpanded = false
    @FocusState private var focusedField: FocusedField?
    @StateObject private var connectionTester = TranslationConnectionTester()
    @StateObject private var modelListFetcher = TranslationModelListFetcher()

    init(
        settings: MarlaSettingsStore,
        profile: TranslationAPIProfile,
        isNew: Bool,
        onCancel: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.settings = settings
        self.profile = profile
        self.isNew = isNew
        self.onCancel = onCancel
        self.onClose = onClose
        let usesCompleteURLFixture = ProcessInfo.processInfo.environment["MARLA_UI_TEST_API_COMPLETE_URL"] == "1"
        let usesModelListFixture = ProcessInfo.processInfo.environment["MARLA_UI_TEST_API_MODELS"] == "1"
        _name = State(initialValue: profile.name)
        _baseURL = State(
            initialValue: usesCompleteURLFixture
                ? "https://api.example.com/v1/chat/completions"
                : profile.baseURL
        )
        _urlMode = State(initialValue: usesCompleteURLFixture ? .completeURL : profile.urlMode)
        _modelName = State(initialValue: profile.modelName)
        _isModelListExpanded = State(initialValue: usesModelListFixture)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceL) {
            VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                Text(isNew ? "新配置" : (profile.name.isEmpty ? "编辑翻译配置" : profile.name))
                    .font(AppFont.title)
                Text("详细信息只在此编辑窗口中展示，API Key 不会回显。")
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
                    fixedField("配置名称", placeholder: "例如：Qwen 快速", text: $name)
                        .focused($focusedField, equals: .profileName)
                    urlField
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spaceM) {
                        Text("请求地址")
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(width: 120, alignment: .trailing)
                        Text(requestURLPreview)
                            .font(AppFont.micro.monospaced())
                            .foregroundStyle(DesignTokens.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(width: 360, alignment: .leading)
                            .help(requestURLPreview)
                    }
                    HStack(alignment: .center, spacing: DesignTokens.spaceM) {
                        Text("API Key")
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(width: 120, alignment: .trailing)
                        SecureField(settings.hasCredential(for: profile.id) ? "输入新 Key 以替换已保存内容" : "可选", text: $apiKeyDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 360)
                    }
                    if settings.hasCredential(for: profile.id) {
                        Label("API Key 已安全保存在 macOS Keychain", systemImage: "checkmark.shield")
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .padding(.leading, 136)
                    }
                    if let saveErrorMessage {
                        Label(saveErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.warning)
                            .padding(.leading, 136)
                    }
                    modelField
                    if modelListFetcher.isLoading {
                        HStack(spacing: DesignTokens.spaceS) {
                            ProgressView().controlSize(.small)
                            Text("正在通过 Rust 核心获取可用模型…")
                        }
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .padding(.leading, 136)
                    } else if let modelListMessage = modelListFetcher.message {
                        Label(modelListMessage, systemImage: "exclamationmark.triangle")
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.warning)
                            .padding(.leading, 136)
                    }
                    if !modelListFetcher.models.isEmpty {
                        modelListDisclosure
                    }
                    connectionTestRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentMargins(.top, DesignTokens.spaceS, for: .scrollContent)
            .scrollIndicators(.never)

            HStack(spacing: DesignTokens.spaceS) {
                Spacer()
                Button("取消", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("保存") { saveAndClose() }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.accent)
            }
        }
        .padding(DesignTokens.spaceXL)
        .marlaGlassSurface(cornerRadius: DesignTokens.radiusL)
        .onChange(of: modelListFetcher.models) { _, models in
            isModelListExpanded = !models.isEmpty
        }
        .onChange(of: baseURL) { _, _ in resetEndpointResults(resetModels: true) }
        .onChange(of: urlMode) { _, _ in resetEndpointResults(resetModels: true) }
        .onChange(of: modelName) { _, _ in resetEndpointResults(resetModels: false) }
        .onChange(of: apiKeyDraft) { _, _ in resetEndpointResults(resetModels: true) }
        .onAppear {
            guard ProcessInfo.processInfo.environment["MARLA_UI_TEST_FOCUS_PROFILE_NAME"] == "1" else {
                return
            }
            DispatchQueue.main.async {
                focusedField = .profileName
            }
        }
        .onDisappear {
            connectionTester.cancel()
            modelListFetcher.cancel()
        }
    }

    private func fixedField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.spaceM) {
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 120, alignment: .trailing)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)
        }
    }

    private var urlField: some View {
        HStack(alignment: .center, spacing: DesignTokens.spaceM) {
            HStack(spacing: DesignTokens.spaceXS) {
                Text("Base")
                Toggle("URL 模式", isOn: completeURLModeBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help(urlModeHelp)
                    .accessibilityLabel("URL 模式")
                    .accessibilityValue(urlMode == .baseURL ? "Base URL" : "完整 URL")
                Text("完整")
            }
            .font(AppFont.caption)
            .foregroundStyle(DesignTokens.secondaryText)
            .frame(width: 120, alignment: .trailing)

            TextField(urlPlaceholder, text: $baseURL)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)
                .accessibilityLabel(urlMode == .baseURL ? "Base URL" : "完整 URL")
        }
    }

    private var completeURLModeBinding: Binding<Bool> {
        Binding(
            get: { urlMode == .completeURL },
            set: { urlMode = $0 ? .completeURL : .baseURL }
        )
    }

    private var modelField: some View {
        HStack(alignment: .center, spacing: DesignTokens.spaceM) {
            Text("模型名称")
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 120, alignment: .trailing)
            HStack(spacing: DesignTokens.spaceS) {
                TextField("例如：qwen-mt-turbo", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 316)
                Button(action: fetchModels) {
                    if modelListFetcher.isLoading {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 36)
                .disabled(modelListFetcher.isLoading)
                .help(modelListFetcher.models.isEmpty ? "获取可用模型" : "重新获取可用模型")
                .accessibilityLabel(modelListFetcher.models.isEmpty ? "获取可用模型" : "重新获取可用模型")
            }
            .frame(width: 360, alignment: .leading)
        }
    }

    private var modelListDisclosure: some View {
        HStack(alignment: .top, spacing: DesignTokens.spaceM) {
            Color.clear.frame(width: 120, height: 1)
            DisclosureGroup(isExpanded: $isModelListExpanded) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(modelListFetcher.models, id: \.self) { model in
                            Button {
                                modelName = model
                                isModelListExpanded = false
                            } label: {
                                HStack(spacing: DesignTokens.spaceS) {
                                    Text(model)
                                        .font(AppFont.micro.monospaced())
                                        .lineLimit(1)
                                    Spacer()
                                    if modelName == model {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(DesignTokens.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, DesignTokens.spaceS)
                            .padding(.vertical, DesignTokens.spaceXS)
                        }
                    }
                }
                .frame(maxHeight: 132)
                .padding(.top, DesignTokens.spaceXS)
            } label: {
                Text("可用模型（\(modelListFetcher.models.count)）")
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            .frame(width: 360, alignment: .leading)
        }
    }

    private var connectionTestRow: some View {
        HStack(alignment: .center, spacing: DesignTokens.spaceM) {
            Text("连接测试")
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 120, alignment: .trailing)
            HStack(alignment: .center, spacing: DesignTokens.spaceS) {
                Button("测试连接", action: testConnection)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(connectionTester.isTesting)
                if connectionTester.isTesting {
                    ProgressView().controlSize(.small)
                    Text("测试中…")
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                } else if let connectionMessage = connectionTester.message {
                    Image(systemName: connectionTester.didSucceed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(connectionTester.didSucceed ? DesignTokens.success : DesignTokens.warning)
                    Text(connectionMessage)
                        .font(AppFont.caption)
                        .foregroundStyle(connectionTester.didSucceed ? DesignTokens.success : DesignTokens.secondaryText)
                        .lineLimit(2)
                        .help(connectionMessage)
                }
            }
            .frame(width: 360, alignment: .leading)
        }
    }

    private var urlPlaceholder: String {
        switch urlMode {
        case .baseURL: "https://api.example.com/v1"
        case .completeURL: "https://api.example.com/v1/chat/completions"
        }
    }

    private var urlModeHelp: String {
        switch urlMode {
        case .baseURL: "自动在地址后追加 /chat/completions"
        case .completeURL: "严格使用填写的完整请求地址"
        }
    }

    private var requestURLPreview: String {
        let value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "—" }
        switch urlMode {
        case .baseURL:
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        case .completeURL:
            return value
        }
    }

    private func saveAndClose() {
        saveErrorMessage = nil
        settings.updateProfile(
            id: profile.id,
            name: name,
            baseURL: baseURL,
            urlMode: urlMode,
            modelName: modelName
        )
        guard saveKeyIfPresent() else { return }
        onClose()
    }

    @discardableResult
    private func saveKeyIfPresent() -> Bool {
        guard !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        do {
            try settings.updateAPIKey(apiKeyDraft, for: profile.id)
            apiKeyDraft = ""
            return true
        } catch {
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    private func testConnection() {
        saveErrorMessage = nil
        connectionTester.test(endpoint: TranslationEndpointConfiguration(
            baseURL: baseURL,
            urlMode: urlMode,
            model: modelName,
            apiKey: resolvedAPIKey
        ))
    }

    private func fetchModels() {
        saveErrorMessage = nil
        isModelListExpanded = false
        modelListFetcher.fetch(endpoint: TranslationEndpointConfiguration(
            baseURL: baseURL,
            urlMode: urlMode,
            model: modelName,
            apiKey: resolvedAPIKey
        ))
    }

    private var resolvedAPIKey: String? {
        APIKeyDraftResolver.resolve(apiKeyDraft) {
            settings.apiKey(for: profile.id)
        }
    }

    private func resetEndpointResults(resetModels: Bool) {
        connectionTester.reset()
        if resetModels { modelListFetcher.reset() }
    }
}

@MainActor
final class TranslationModelListFetcher: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var models: [String]
    @Published private(set) var message: String?

    private let client = RustModelListClient()
    private var handle: RustModelListClient.Handle?
    private var requestID: UUID?

    init() {
        if ProcessInfo.processInfo.environment["MARLA_UI_TEST_API_MODELS"] == "1" {
            models = ["gpt-5.4", "gpt-5.4-mini", "gpt-5.6-luna", "qwen-mt-turbo"]
        } else {
            models = []
        }
    }

    func fetch(endpoint: TranslationEndpointConfiguration) {
        cancel()
        let endpointURL = endpoint.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TranslationAPIProfile.isValidEndpointURL(endpointURL) else {
            message = "请先填写有效的 URL。"
            return
        }
        let id = UUID()
        requestID = id
        isLoading = true
        message = nil
        let request = ModelListFFIRequest(requestID: id, endpoint: endpoint)
        do {
            handle = try client.start(request: request) { [weak self] event in
                Task { @MainActor [weak self] in self?.apply(event) }
            }
        } catch {
            finish(message: error.localizedDescription)
        }
    }

    func reset() {
        cancel()
        models = []
        message = nil
    }

    func cancel() {
        handle?.cancel()
        handle?.release()
        handle = nil
        requestID = nil
        isLoading = false
    }

    private func apply(_ event: ModelListFFIEvent) {
        guard event.schemaVersion == 1, event.requestID == requestID else { return }
        switch event.type {
        case "completed":
            models = event.models ?? []
            finish(message: models.isEmpty ? "端点没有返回可用模型。" : nil)
        case "failed": finish(message: event.message ?? "获取模型列表失败。")
        case "cancelled": finish(message: nil)
        default: break
        }
    }

    private func finish(message: String?) {
        handle?.release()
        handle = nil
        requestID = nil
        isLoading = false
        self.message = message
    }
}

@MainActor
final class TranslationConnectionTester: ObservableObject {
    @Published private(set) var isTesting = false
    @Published private(set) var message: String?
    @Published private(set) var didSucceed = false

    private let client = RustTranslationClient()
    private var handle: RustTranslationClient.Handle?
    private var requestID: UUID?

    init() {
        switch ProcessInfo.processInfo.environment["MARLA_UI_TEST_API_CONNECTION_RESULT"] {
        case "success":
            message = "连接成功，端点已返回有效的流式译文。"
            didSucceed = true
        case "failure":
            message = "认证失败，请检查当前 API Key。"
            didSucceed = false
        default:
            break
        }
    }

    func test(endpoint: TranslationEndpointConfiguration) {
        cancel()
        let endpointURL = endpoint.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = endpoint.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TranslationAPIProfile.isValidEndpointURL(endpointURL),
              !model.isEmpty else {
            message = "请填写有效的 URL 和模型名称。"
            didSucceed = false
            return
        }

        let id = UUID()
        requestID = id
        isTesting = true
        didSucceed = false
        message = nil
        let request = TranslationFFIRequest(
            requestID: id,
            sourceText: "Hello",
            sourceLanguage: .english,
            target: .simplifiedChinese,
            endpoint: endpoint,
            timeouts: TranslationTimeouts(connectSeconds: 10, firstTokenSeconds: 20, overallSeconds: 30)
        )
        do {
            handle = try client.start(request: request) { [weak self] event in
                Task { @MainActor [weak self] in self?.apply(event) }
            }
        } catch {
            finish(message: error.localizedDescription, succeeded: false)
        }
    }

    func cancel() {
        handle?.cancel()
        handle?.release()
        handle = nil
        requestID = nil
        isTesting = false
    }

    func reset() {
        cancel()
        message = nil
        didSucceed = false
    }

    private func apply(_ event: TranslationFFIEvent) {
        guard event.schemaVersion == 1, event.requestID == requestID else { return }
        switch event.type {
        case "completed": finish(message: "连接成功，端点已返回有效的流式译文。", succeeded: true)
        case "failed": finish(message: event.message ?? "连接测试失败。", succeeded: false)
        case "cancelled": finish(message: "连接测试已取消。", succeeded: false)
        default: break
        }
    }

    private func finish(message: String, succeeded: Bool) {
        handle?.release()
        handle = nil
        requestID = nil
        isTesting = false
        didSucceed = succeeded
        self.message = message
    }
}

private struct StatusLine: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.spaceM) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(AppFont.bodyEmphasis)
                Text(detail).font(AppFont.caption).foregroundStyle(DesignTokens.secondaryText)
            }
            Spacer()
        }
    }
}

struct PermissionSettingRow: View {
    let title: String
    let detail: String
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.spaceM) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(isReady ? DesignTokens.success : DesignTokens.warning)
                .font(.system(size: 17))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(AppFont.bodyEmphasis)
                Text(detail).font(AppFont.caption).foregroundStyle(DesignTokens.secondaryText)
            }
            Spacer()
            if !isReady {
                Button("授权") { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

struct ShortcutRecorderRow: View {
    let action: GlobalShortcutAction
    let binding: ShortcutBinding
    let isEnabled: Bool
    let onEnabledChange: (Bool) -> Void
    let onChange: (ShortcutBinding) -> Void
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Image(systemName: action.symbolName).foregroundStyle(DesignTokens.accent)
            Text(action.title).font(AppFont.body)
            Spacer()
            if recording {
                Text("按下组合键…").font(AppFont.caption).foregroundStyle(DesignTokens.accent)
            } else {
                Text(binding.displayName)
                    .font(AppFont.micro.monospacedDigit())
                    .foregroundStyle(isEnabled ? DesignTokens.secondaryText : DesignTokens.tertiaryText)
                Button("录制") { recording = true }
                    .buttonStyle(.borderless)
                    .disabled(!isEnabled)
            }
            Toggle(
                "启用\(action.title)快捷键",
                isOn: Binding(get: { isEnabled }, set: { onEnabledChange($0) })
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .frame(minHeight: 32)
        .onChange(of: recording) { _, isRecording in
            if isRecording { installRecorder() } else { removeRecorder() }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { recording = false }
        }
        .onDisappear { removeRecorder() }
    }

    private func installRecorder() {
        removeRecorder()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            onChange(ShortcutBinding(keyCode: event.keyCode, modifiers: modifiers))
            recording = false
            return nil
        }
    }

    private func removeRecorder() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
