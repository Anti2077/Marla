import AppKit
import Combine
import Foundation
import MarlaCore
import NaturalLanguage
import SwiftUI

enum CardRecoveryAction: Equatable {
    case openSettings
    case openOCRSettings
    case openAccessibilitySettings
    case openScreenRecordingSettings
    case quickInput
    case reselectScreenshot
    case retry

    var title: String {
        switch self {
        case .openSettings: "打开设置"
        case .openOCRSettings: "打开 OCR 设置"
        case .openAccessibilitySettings, .openScreenRecordingSettings: "前往系统设置"
        case .quickInput: "打开快速输入"
        case .reselectScreenshot: "重新框选"
        case .retry: "重试"
        }
    }
}

enum OCRActivity: Equatable {
    case vision
    case glmOCR
    case visionFallback
    case inPlaceTranslation
}

extension TranslationSurface {
    var symbolName: String {
        switch self {
        case .selection: "text.viewfinder"
        case .screenshot: "viewfinder"
        case .quickInput: "keyboard"
        }
    }
}

struct CardSession: Identifiable, Equatable {
    var id: UUID
    let surface: TranslationSurface
    var profileID: UUID?
    var profileName: String
    var sourceContent: TranslationContent
    var translation: String
    var nativeLanguage: TranslationLanguage = .simplifiedChinese
    var secondaryLanguage: TranslationLanguage = .english
    var source: TranslationSource = .automatic
    var detectedSourceLanguage: TranslationLanguage?
    var target: TranslationTarget
    var state: TranslationSessionState
    var errorCode: TranslationErrorCode?
    var errorRetryable = false
    var recoveryAction: CardRecoveryAction?
    var copyConfirmation: TranslationCopyRepresentation?
    var isComparisonExpanded = false
    var isPinned = false
    var anchor: ScreenRect?
    var pointer: CGPoint?
    var isActivating = false
    var ocrActivity: OCRActivity?

    var sourceText: String {
        get { sourceContent.text }
        set { sourceContent = TranslationContent(format: sourceContent.format, text: newValue) }
    }

    var translatedContent: TranslationContent {
        TranslationContent(format: sourceContent.format, text: translation)
    }

    var resolvedSourceLanguage: TranslationLanguage? {
        source.resolved(using: detectedSourceLanguage)
    }

    var resolvedTargetLanguage: TranslationLanguage {
        TranslationLanguageRouter.targetLanguage(
            sourceLanguage: resolvedSourceLanguage,
            target: target,
            nativeLanguage: nativeLanguage,
            secondaryLanguage: secondaryLanguage
        )
    }

    var statusLabel: String {
        switch state {
        case .idle: "准备就绪"
        case .acquiring: "正在读取"
        case .recognizing:
            switch ocrActivity {
            case .glmOCR: "正在解析结构"
            case .visionFallback: "正在改用 Vision"
            case .inPlaceTranslation: "正在生成原位译文"
            case .vision, nil: "正在识别"
            }
        case .awaitingFirstToken:
            ocrActivity == .inPlaceTranslation ? "正在生成原位译文" : "等待译文"
        case .streaming: "翻译中"
        case .completed: "已完成"
        case .failed: "需要处理"
        case .cancelled: "已取消"
        }
    }
}

enum TranslationCopyRepresentation: Equatable {
    case markdown
    case plainText

    var confirmationLabel: String {
        switch self {
        case .markdown: "已复制 Markdown"
        case .plainText: "已复制纯文本"
        }
    }
}

struct RecentTranslation: Identifiable, Equatable {
    let id: UUID
    let surface: TranslationSurface
    let profileID: UUID?
    let profileName: String
    let sourceContent: TranslationContent
    let translation: String
    let nativeLanguage: TranslationLanguage
    let secondaryLanguage: TranslationLanguage
    let source: TranslationSource
    let detectedSourceLanguage: TranslationLanguage?
    let target: TranslationTarget

    var sourceText: String { sourceContent.text }

    var displayTranslation: String {
        Self.plainTextSummary(translation, format: sourceContent.format)
    }

    var displaySourceText: String {
        Self.plainTextSummary(sourceText, format: sourceContent.format)
    }

    private static func plainTextSummary(_ text: String, format: TranslationContentFormat) -> String {
        guard format == .semanticMarkdown else { return text }
        if let document = MarkdownResultDocument.parse(text) {
            return document.plainText
        }
        if let attributed = try? AttributedString(markdown: text) {
            return String(attributed.characters).removingTrailingLineBreaks()
        }
        return text
    }
}

enum SystemSourceLanguageDetector {
    static func detect(_ text: String) -> TranslationLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        return TranslationLanguage(normalizing: recognizer.dominantLanguage?.rawValue)
    }
}

@MainActor
final class TranslationSessionStore: ObservableObject {
    @Published private(set) var session: CardSession?
    @Published private(set) var recentTranslations: [RecentTranslation] = []

    static let recentTranslationLimit = 3

    private let settings: MarlaSettingsStore
    private let client = RustTranslationClient()
    private let sourceLanguageDetector: (String) -> TranslationLanguage?
    private var handle: RustTranslationClient.Handle?
    private var ocrTask: Task<Void, Never>?
    private var copyConfirmationResetTask: Task<Void, Never>?

    init(
        settings: MarlaSettingsStore,
        sourceLanguageDetector: @escaping (String) -> TranslationLanguage? = SystemSourceLanguageDetector.detect
    ) {
        self.settings = settings
        self.sourceLanguageDetector = sourceLanguageDetector
    }

    var availableProfiles: [TranslationAPIProfile] { settings.enabledProfiles }
    var nativeLanguage: TranslationLanguage { settings.nativeLanguage }
    var secondaryLanguage: TranslationLanguage { settings.secondaryLanguage }

    func beginRecognizing(
        anchor: ScreenRect?,
        pointer: CGPoint?,
        provider: OCRProviderKind = .vision
    ) -> UUID {
        cancelCurrentRequest()
        let id = UUID()
        session = CardSession(
            id: id,
            surface: .screenshot,
            profileID: settings.defaultProfile?.id,
            profileName: settings.defaultProfile?.name ?? "未配置",
            sourceContent: .plainText(""),
            translation: "",
            nativeLanguage: settings.nativeLanguage,
            secondaryLanguage: settings.secondaryLanguage,
            target: settings.defaultTarget,
            state: .recognizing,
            anchor: anchor,
            pointer: pointer,
            isActivating: false,
            ocrActivity: provider == .glmOCR ? .glmOCR : .vision
        )
        return id
    }

    func attachOCRTask(_ task: Task<Void, Never>, for id: UUID) {
        guard session?.id == id else {
            task.cancel()
            return
        }
        ocrTask?.cancel()
        ocrTask = task
    }

    func beginVisionFallback(for id: UUID) {
        guard session?.id == id else { return }
        session?.state = .recognizing
        session?.ocrActivity = .visionFallback
    }

    func submitOCRResult(_ result: OCRResult, for id: UUID) {
        guard session?.id == id else { return }
        let text = result.content.text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fail(
                "没有识别到文字，请重新框选更清晰的区域。",
                code: .invalidResponse,
                for: id,
                recovery: .reselectScreenshot
            )
            return
        }
        ocrTask = nil
        session?.sourceContent = result.content
        session?.detectedSourceLanguage = sourceLanguageDetector(text)
        startRequest(for: id)
    }

    func prepareInPlaceTranslation(
        _ result: OCRResult,
        for id: UUID
    ) -> InPlaceTranslationConfiguration? {
        guard var current = session, current.id == id else { return nil }
        let text = result.content.text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fail(
                "没有识别到文字，请重新框选更清晰的区域。",
                code: .invalidResponse,
                for: id,
                recovery: .reselectScreenshot
            )
            return nil
        }
        guard let profile = settings.profile(id: current.profileID),
              let endpoint = settings.endpoint(for: profile.id) else {
            fail(
                "请先在设置中配置翻译 API。",
                code: .invalidConfiguration,
                for: id,
                recovery: .openSettings
            )
            return nil
        }
        current.sourceContent = result.content
        current.detectedSourceLanguage = sourceLanguageDetector(text)
        current.state = .awaitingFirstToken
        current.ocrActivity = .inPlaceTranslation
        current.profileID = profile.id
        current.profileName = profile.name
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
        session = current
        return InPlaceTranslationConfiguration(
            sourceContent: current.sourceContent,
            sourceLanguage: current.resolvedSourceLanguage,
            target: .explicit(current.resolvedTargetLanguage),
            endpoint: endpoint
        )
    }

    func completeInPlaceTranslation(for id: UUID) {
        guard var current = session, current.id == id else { return }
        ocrTask = nil
        current.state = .completed
        current.ocrActivity = nil
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
        session = current
    }

    func installUIAutomationFixture(
        surface: TranslationSurface,
        sourceText: String,
        translation: String,
        state: TranslationSessionState,
        comparisonExpanded: Bool = false,
        pinned: Bool = false,
        recovery: CardRecoveryAction? = nil,
        contentFormat: TranslationContentFormat = .plainText,
        ocrActivity: OCRActivity? = nil
    ) {
        cancelCurrentRequest()
        let id = UUID()
        session = CardSession(
            id: id,
            surface: surface,
            profileID: settings.defaultProfile?.id,
            profileName: settings.defaultProfile?.name ?? "未配置",
            sourceContent: TranslationContent(format: contentFormat, text: sourceText),
            translation: translation,
            nativeLanguage: settings.nativeLanguage,
            secondaryLanguage: settings.secondaryLanguage,
            source: .automatic,
            detectedSourceLanguage: sourceLanguageDetector(sourceText),
            target: settings.defaultTarget,
            state: state,
            errorCode: state.isFailure ? .network : nil,
            errorRetryable: recovery == .retry,
            recoveryAction: recovery,
            isComparisonExpanded: comparisonExpanded,
            isPinned: pinned,
            anchor: nil,
            pointer: NSEvent.mouseLocation,
            isActivating: true,
            ocrActivity: ocrActivity
        )
        recordRecentTranslationIfEligible(session)
    }

    func updateUIAutomationFixture(
        translation: String,
        state: TranslationSessionState
    ) {
        guard MarlaRuntime.isUIAutomationSnapshot, var current = session else { return }
        current.translation = translation
        current.state = state
        session = current
        recordRecentTranslationIfEligible(current)
    }

    func submitRecognizedText(_ text: String, for id: UUID) {
        guard session?.id == id else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            session?.state = .failed(message: "没有识别到文字，请重新框选更清晰的区域。")
            session?.errorCode = .invalidResponse
            session?.errorRetryable = false
            session?.recoveryAction = .reselectScreenshot
            return
        }
        session?.sourceText = text
        session?.detectedSourceLanguage = sourceLanguageDetector(text)
        startRequest(for: id)
    }

    func startText(
        _ text: String,
        surface: TranslationSurface,
        anchor: ScreenRect?,
        pointer: CGPoint?,
        activate: Bool = false,
        source: TranslationSource = .automatic,
        target: TranslationTarget? = nil,
        profileID: UUID? = nil,
        contentFormat: TranslationContentFormat? = nil
    ) {
        cancelCurrentRequest()
        let id = UUID()
        session = CardSession(
            id: id,
            surface: surface,
            profileID: profileID ?? settings.defaultProfile?.id,
            profileName: settings.profile(id: profileID ?? settings.defaultProfile?.id)?.name ?? "未配置",
            sourceContent: TranslationContent(format: contentFormat ?? surface.defaultContentFormat, text: text),
            translation: "",
            nativeLanguage: settings.nativeLanguage,
            secondaryLanguage: settings.secondaryLanguage,
            source: source,
            detectedSourceLanguage: sourceLanguageDetector(text),
            target: target ?? settings.defaultTarget,
            state: .acquiring,
            anchor: anchor,
            pointer: pointer,
            isActivating: activate
        )
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            session?.state = .failed(message: "没有可翻译的文字。")
            session?.errorCode = .invalidConfiguration
            return
        }
        startRequest(for: id)
    }

    func startContent(
        _ content: TranslationContent,
        surface: TranslationSurface,
        anchor: ScreenRect?,
        pointer: CGPoint?,
        activate: Bool = false,
        source: TranslationSource = .automatic,
        target: TranslationTarget? = nil,
        profileID: UUID? = nil
    ) {
        startText(
            content.text,
            surface: surface,
            anchor: anchor,
            pointer: pointer,
            activate: activate,
            source: source,
            target: target,
            profileID: profileID,
            contentFormat: content.format
        )
    }

    func startRequest(for id: UUID) {
        guard var current = session, current.id == id else { return }
        guard let profile = settings.profile(id: current.profileID),
              let endpoint = settings.endpoint(for: profile.id) else {
            current.state = .failed(message: "请先在设置中配置翻译 API。")
            current.errorCode = .invalidConfiguration
            current.errorRetryable = false
            current.recoveryAction = .openSettings
            session = current
            return
        }
        current.state = .awaitingFirstToken
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
        current.profileID = profile.id
        current.profileName = profile.name
        session = current
        let request = TranslationFFIRequest(
            requestID: current.id,
            sourceContent: current.sourceContent,
            sourceLanguage: current.resolvedSourceLanguage,
            target: .explicit(current.resolvedTargetLanguage),
            endpoint: endpoint
        )
        do {
            handle = try client.start(request: request) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.apply(event)
                }
            }
        } catch {
            current.state = .failed(message: error.localizedDescription)
            current.errorCode = .internalError
            current.errorRetryable = true
            session = current
        }
    }

    func apply(_ event: TranslationFFIEvent) {
        guard var current = session else { return }
        guard TranslationSessionReducer.apply(
            event,
            requestID: current.id,
            state: &current.state,
            translation: &current.translation
        ) else { return }
        if event.type == "failed" {
            current.errorCode = event.code
            current.errorRetryable = event.retryable ?? false
            current.recoveryAction = recoveryAction(for: event.code, retryable: current.errorRetryable)
            if event.code == .unauthorized,
               let profileID = current.profileID,
               !settings.hasCredential(for: profileID) {
                current.state = .failed(message: Self.missingCredentialMessage(profileName: current.profileName))
            }
        }
        if current.state.isTerminal {
            handle?.release()
            handle = nil
        }
        if event.type == "delta" || event.type == "completed" {
            current.ocrActivity = nil
        }
        session = current
        recordRecentTranslationIfEligible(current)
    }

    func retry() {
        guard var current = session, !current.sourceText.isEmpty else { return }
        cancelCurrentRequest()
        current.translation = ""
        current.state = .acquiring
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
        current.id = UUID()
        session = current
        startRequest(for: current.id)
    }

    func changeAPIProfile(_ profileID: UUID) {
        guard var current = session,
              !current.sourceText.isEmpty,
              let profile = settings.profile(id: profileID),
              profile.isEnabled,
              profile.isConfigured else { return }
        cancelCurrentRequest()
        current.profileID = profile.id
        current.profileName = profile.name
        current.translation = ""
        current.state = .acquiring
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
        current.id = UUID()
        session = current
        startRequest(for: current.id)
    }

    func changeTarget(_ target: TranslationTarget) {
        guard var current = session, !current.sourceText.isEmpty else { return }
        cancelCurrentRequest()
        current.target = target
        current.translation = ""
        current.state = .acquiring
        current.id = UUID()
        session = current
        startRequest(for: current.id)
    }

    func changeSource(_ source: TranslationSource) {
        guard var current = session, !current.sourceText.isEmpty else { return }
        cancelCurrentRequest()
        current.source = source
        current.translation = ""
        current.state = .acquiring
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
        current.id = UUID()
        session = current
        startRequest(for: current.id)
    }

    func toggleComparison() {
        session?.isComparisonExpanded.toggle()
    }

    func togglePinned() {
        session?.isPinned.toggle()
    }

    func copyTranslation(as requestedRepresentation: TranslationCopyRepresentation? = nil) {
        guard let current = session, !current.translation.isEmpty else { return }
        let representation = requestedRepresentation
            ?? (current.sourceContent.format == .semanticMarkdown ? .markdown : .plainText)
        let copiedText: String
        switch representation {
        case .markdown:
            copiedText = current.translation.removingTrailingLineBreaks()
        case .plainText:
            if current.sourceContent.format == .semanticMarkdown {
                guard case .completed = current.state,
                      let document = MarkdownResultDocument.parse(current.translation)
                else { return }
                copiedText = document.plainText
            } else {
                copiedText = current.translation.removingTrailingLineBreaks()
            }
        }
        guard !copiedText.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copiedText, forType: .string)
        session?.copyConfirmation = representation
        copyConfirmationResetTask?.cancel()
        let sessionID = current.id
        copyConfirmationResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled,
                  self?.session?.id == sessionID,
                  self?.session?.copyConfirmation == representation
            else { return }
            self?.session?.copyConfirmation = nil
        }
    }

    func cancel() {
        guard session != nil else { return }
        cancelCurrentRequest()
        session?.state = .cancelled
    }

    func cancelCurrentRequest() {
        ocrTask?.cancel()
        ocrTask = nil
        handle?.cancel()
        handle?.release()
        handle = nil
    }

    func close() {
        cancelCurrentRequest()
        session = nil
    }

    @discardableResult
    func restoreRecentTranslation(id: UUID) -> CardSession? {
        guard let index = recentTranslations.firstIndex(where: { $0.id == id }) else { return nil }
        let recent = recentTranslations.remove(at: index)
        recentTranslations.insert(recent, at: 0)
        cancelCurrentRequest()
        let restored = CardSession(
            id: UUID(),
            surface: recent.surface,
            profileID: recent.profileID,
            profileName: recent.profileName,
            sourceContent: recent.sourceContent,
            translation: recent.translation,
            nativeLanguage: recent.nativeLanguage,
            secondaryLanguage: recent.secondaryLanguage,
            source: recent.source,
            detectedSourceLanguage: recent.detectedSourceLanguage,
            target: recent.target,
            state: .completed,
            anchor: nil,
            pointer: NSEvent.mouseLocation,
            isActivating: true
        )
        session = restored
        return restored
    }

    func fail(
        _ message: String,
        code: TranslationErrorCode,
        for id: UUID? = nil,
        retryable: Bool = false,
        recovery: CardRecoveryAction? = nil
    ) {
        guard id == nil || session?.id == id else { return }
        session?.state = .failed(message: message)
        session?.errorCode = code
        session?.errorRetryable = retryable
        session?.recoveryAction = recovery ?? (retryable ? .retry : nil)
    }

    private func recoveryAction(for code: TranslationErrorCode?, retryable: Bool) -> CardRecoveryAction? {
        switch code {
        case .invalidConfiguration, .unauthorized:
            .openSettings
        case .rateLimited, .network, .timeout, .provider, .invalidResponse, .internalError:
            retryable ? .retry : nil
        case nil:
            retryable ? .retry : nil
        }
    }

    static func missingCredentialMessage(profileName: String) -> String {
        "配置“\(profileName)”没有已保存的 API Key。请打开设置，使用“保存并测试”后重试。"
    }

    private func recordRecentTranslationIfEligible(_ candidate: CardSession?) {
        guard let candidate,
              case .completed = candidate.state,
              !candidate.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !candidate.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        recentTranslations.removeAll {
            $0.sourceContent == candidate.sourceContent &&
                $0.translation == candidate.translation &&
                $0.nativeLanguage == candidate.nativeLanguage &&
                $0.secondaryLanguage == candidate.secondaryLanguage &&
                $0.source == candidate.source &&
                $0.detectedSourceLanguage == candidate.detectedSourceLanguage &&
                $0.target == candidate.target
        }
        recentTranslations.insert(
            RecentTranslation(
                id: UUID(),
                surface: candidate.surface,
                profileID: candidate.profileID,
                profileName: candidate.profileName,
                sourceContent: candidate.sourceContent,
                translation: candidate.translation,
                nativeLanguage: candidate.nativeLanguage,
                secondaryLanguage: candidate.secondaryLanguage,
                source: candidate.source,
                detectedSourceLanguage: candidate.detectedSourceLanguage,
                target: candidate.target
            ),
            at: 0
        )
        if recentTranslations.count > Self.recentTranslationLimit {
            recentTranslations.removeLast(recentTranslations.count - Self.recentTranslationLimit)
        }
    }
}
