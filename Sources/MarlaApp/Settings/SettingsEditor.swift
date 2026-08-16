import AppKit
import MarlaCore
import SwiftUI
import UniformTypeIdentifiers

struct APIProfileEditorView: View {
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
                Button("保存并测试", action: testConnection)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(connectionTester.isTesting)
                    .help("先保存当前配置与非空 API Key，再使用同一份已保存配置测试连接")
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
        do {
            let endpoint = try APIProfileEditorPersistence.saveAndResolveEndpoint(
                settings: settings,
                profileID: profile.id,
                name: name,
                baseURL: baseURL,
                urlMode: urlMode,
                modelName: modelName,
                apiKeyDraft: apiKeyDraft
            )
            connectionTester.test(endpoint: endpoint)
        } catch {
            saveErrorMessage = error.localizedDescription
        }
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
enum APIProfileEditorPersistence {
    static func saveAndResolveEndpoint(
        settings: MarlaSettingsStore,
        profileID: UUID,
        name: String,
        baseURL: String,
        urlMode: TranslationEndpointURLMode,
        modelName: String,
        apiKeyDraft: String
    ) throws -> TranslationEndpointConfiguration {
        settings.updateProfile(
            id: profileID,
            name: name,
            baseURL: baseURL,
            urlMode: urlMode,
            modelName: modelName
        )
        if !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try settings.updateAPIKey(apiKeyDraft, for: profileID)
        }
        let savedProfile = settings.profile(id: profileID)
        return TranslationEndpointConfiguration(
            baseURL: savedProfile?.baseURL ?? "",
            urlMode: savedProfile?.urlMode ?? .baseURL,
            model: savedProfile?.modelName ?? "",
            apiKey: settings.apiKey(for: profileID)
        )
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
            sourceContent: .plainText("Hello"),
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
