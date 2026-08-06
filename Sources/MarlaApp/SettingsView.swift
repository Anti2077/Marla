import AppKit
import MarlaCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: MarlaSettingsStore
    @ObservedObject var appModel: MarlaApplicationModel
    @State private var apiKeyDraft = ""
    @State private var connectionMessage: String?
    @StateObject private var connectionTester = TranslationConnectionTester()

    var body: some View {
        Form {
            apiSection
            shortcutSection
            permissionSection
            experimentSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: 620, height: 560)
        .padding(DesignTokens.spaceM)
        .marlaGlassSurface(cornerRadius: 0)
        .onAppear {
            apiKeyDraft = ""
        }
        .onDisappear { connectionTester.cancel() }
    }

    private var apiSection: some View {
        Section {
            TextField("Base URL", text: $settings.baseURL)
                .textFieldStyle(.roundedBorder)
            TextField("模型名称", text: $settings.modelName)
                .textFieldStyle(.roundedBorder)
            SecureField(settings.keychain.hasCredential ? "输入新 Key 以替换已保存内容" : "API Key（可选）", text: $apiKeyDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { saveKey() }
            if settings.keychain.hasCredential {
                Label("API Key 已安全保存在 macOS Keychain", systemImage: "checkmark.shield")
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            HStack {
                Button("保存 Key") { saveKey() }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.accent)
                Button("删除 Key") {
                    settings.removeAPIKey()
                    apiKeyDraft = ""
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("测试连接") { testConnection() }
                    .buttonStyle(.bordered)
                    .disabled(connectionTester.isTesting)
            }
            if connectionTester.isTesting {
                HStack(spacing: DesignTokens.spaceS) {
                    ProgressView().controlSize(.small)
                    Text("正在通过 Rust 核心发起真实流式请求…")
                }
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
            } else if let message = connectionTester.message ?? connectionMessage {
                Text(message)
                    .font(AppFont.caption)
                    .foregroundStyle(connectionTester.didSucceed ? DesignTokens.success : DesignTokens.secondaryText)
            }
            Text("Vision 在本机识别截图；只有识别出的文字会发送到你配置的翻译 API。最近三条译文只在本次运行的内存中保留，退出即清空，不写入磁盘。")
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
        } header: {
            Label("翻译 API", systemImage: "network")
        } footer: {
            Text("支持 OpenAI-compatible Chat Completions 流式端点。Base URL 不要包含 /chat/completions。")
        }
    }

    private var shortcutSection: some View {
        Section {
            ForEach(GlobalShortcutAction.allCases, id: \.self) { action in
                ShortcutRecorderRow(action: action, binding: appModel.shortcutManager.bindings[action] ?? .defaults[action]!) { binding in
                    appModel.shortcutManager.set(binding, for: action)
                }
            }
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
        } header: {
            Label("快捷键", systemImage: "command")
        }
    }

    private var permissionSection: some View {
        Section {
            PermissionSettingRow(title: "辅助功能", detail: "划词翻译需要读取当前应用明确选中的文字。", isReady: appModel.accessibilityTrusted) {
                appModel.requestAccessibilityAccess()
            }
            PermissionSettingRow(title: "屏幕录制", detail: "截图翻译只捕获你拖动框选的区域。", isReady: appModel.screenRecordingAuthorized) {
                appModel.requestScreenRecordingAccess()
            }
            HStack {
                Spacer()
                Button("打开系统设置") { openPrivacySettings() }
                    .buttonStyle(.bordered)
            }
        } header: {
            Label("权限", systemImage: "lock.shield")
        }
    }

    private var experimentSection: some View {
        Section {
            Toggle("重按触控板触发划词翻译", isOn: $settings.forceTouchExperimental)
            Text("实验功能默认关闭，只使用公开 API；键盘快捷键始终保留。")
                .font(AppFont.caption)
                .foregroundStyle(DesignTokens.secondaryText)
        } header: {
            Label("实验功能", systemImage: "flask")
        }
    }

    private func saveKey() {
        guard !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            connectionMessage = settings.keychain.hasCredential
                ? "未输入新 Key，已保存的 Key 保持不变。"
                : "当前端点将不携带 Authorization Header。"
            return
        }
        do {
            try settings.updateAPIKey(apiKeyDraft)
            apiKeyDraft = ""
            connectionMessage = "Key 已保存到 macOS Keychain。"
        } catch {
            connectionMessage = error.localizedDescription
        }
    }

    private func testConnection() {
        connectionMessage = nil
        connectionTester.test(
            endpoint: TranslationEndpointConfiguration(
                baseURL: settings.baseURL,
                model: settings.modelName,
                apiKey: settings.apiKey
            )
        )
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
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

    func test(endpoint: TranslationEndpointConfiguration) {
        cancel()
        let baseURL = endpoint.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = endpoint.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: baseURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil,
              !model.isEmpty else {
            message = "请填写有效的 Base URL 和模型名称。"
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

    private func apply(_ event: TranslationFFIEvent) {
        guard event.schemaVersion == 1, event.requestID == requestID else { return }
        switch event.type {
        case "completed":
            finish(message: "连接成功，端点已返回有效的流式译文。", succeeded: true)
        case "failed":
            finish(message: event.message ?? "连接测试失败。", succeeded: false)
        case "cancelled":
            finish(message: "连接测试已取消。", succeeded: false)
        default:
            break
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
        .padding(.vertical, 3)
    }
}

struct ShortcutRecorderRow: View {
    let action: GlobalShortcutAction
    let binding: ShortcutBinding
    let onChange: (ShortcutBinding) -> Void
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Image(systemName: action.symbolName)
                .foregroundStyle(DesignTokens.accent)
            Text(action.title)
                .font(AppFont.body)
            Spacer()
            if recording {
                Text("按下组合键…")
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.accent)
            } else {
                Text(binding.displayName)
                    .font(AppFont.micro.monospacedDigit())
                    .foregroundStyle(DesignTokens.secondaryText)
                Button("录制") { recording = true }
                    .buttonStyle(.borderless)
            }
        }
        .frame(minHeight: 32)
        .onChange(of: recording) { _, isRecording in
            if isRecording { installRecorder() } else { removeRecorder() }
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
