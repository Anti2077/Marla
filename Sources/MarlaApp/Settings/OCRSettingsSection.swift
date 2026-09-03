import MarlaCore
import SwiftUI

struct OCRSettingsSection: View {
    @ObservedObject var settings: MarlaSettingsStore
    @State private var apiKeyDraft = ""
    @State private var saveMessage: String?
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.marlaReduceMotionOverride) private var reduceMotionOverride

    private var reducesMotion: Bool {
        accessibilityReduceMotion || reduceMotionOverride
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
            SettingsSection(title: "OCR Provider", systemImage: "arrow.triangle.2.circlepath") {
                HStack(spacing: DesignTokens.spaceM) {
                    VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                        Text("截图文字识别服务")
                            .font(AppFont.bodyEmphasis)
                        Text("选择本次截图默认使用的服务；每个服务在独立卡片中配置。")
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    Spacer(minLength: DesignTokens.spaceL)
                    Picker("OCR Provider", selection: providerBinding) {
                        ForEach(OCRProviderKind.allCases) { provider in
                            Text(provider.label).tag(provider)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 168)
                }
            }

            SettingsSection(title: "本机 Vision", systemImage: "text.viewfinder") {
                visionDetails
            }

            SettingsSection(title: "云端 GLM-OCR", systemImage: "doc.richtext") {
                glmDetails
            }
        }
        .animation(
            MarlaMotion.animation(
                MarlaMotion.feedback,
                reducesMotion: reducesMotion,
                reducedMotionAnimation: MarlaMotion.reducedOpacity
            ),
            value: displayedProvider
        )
    }

    private var providerBinding: Binding<OCRProviderKind> {
        Binding(
            get: { displayedProvider },
            set: {
                settings.setOCRProvider($0)
                saveMessage = nil
            }
        )
    }

    private var displayedProvider: OCRProviderKind {
        if MarlaRuntime.isUIAutomationSnapshot,
           ProcessInfo.processInfo.environment["MARLA_UI_TEST_OCR_PROVIDER"] == "glm" {
            return .glmOCR
        }
        return settings.ocrProvider
    }

    private var visionDetails: some View {
        Group {
            StatusLine(
                icon: displayedProvider == .vision ? "checkmark.circle.fill" : "circle",
                tint: displayedProvider == .vision ? DesignTokens.success : DesignTokens.secondaryText,
                title: displayedProvider == .vision ? "当前使用 Vision" : "本机备用识别",
                detail: "macOS Vision 在本机识别截图中的文字。"
            )
            StatusLine(
                icon: "lock.fill",
                tint: DesignTokens.accent,
                title: "截图不会上传",
                detail: "截图像素只在内存中处理；只有识别出的纯文本会进入当前翻译 API。"
            )
            StatusLine(
                icon: "text.alignleft",
                tint: DesignTokens.secondaryText,
                title: "纯文本识别",
                detail: "保留文字与行顺序，不承诺表格、公式或页面布局恢复。"
            )
        }
    }

    private var glmDetails: some View {
        Group {
            StatusLine(
                icon: displayedProvider == .glmOCR ? "checkmark.circle.fill" : "circle",
                tint: displayedProvider == .glmOCR ? DesignTokens.success : DesignTokens.secondaryText,
                title: displayedProvider == .glmOCR ? "当前使用 GLM-OCR" : "可选云端服务",
                detail: "GLM-OCR 使用固定官方接口和模型；无需填写 URL 或质量参数。"
            )
            StatusLine(
                icon: "viewfinder",
                tint: settings.hasGLMOCRAPIKey ? DesignTokens.success : DesignTokens.warning,
                title: settings.hasGLMOCRAPIKey ? "原位翻译可用" : "原位翻译需要 API Key",
                detail: "菜单中的独立“原位翻译”始终使用 GLM-OCR 的结构和坐标；普通“截图翻译”仍显示附近结果卡。"
            )
            StatusLine(
                icon: "icloud.and.arrow.up",
                tint: DesignTokens.warning,
                title: "所选截图会上传",
                detail: "截图只在本次识别的内存会话中发送到智谱 GLM-OCR；完成或取消后不由 Marla 保存。"
            )
            StatusLine(
                icon: "doc.richtext",
                tint: DesignTokens.accent,
                title: "结构化识别",
                detail: "识别表格、公式、代码与版面，为原位覆盖提供结构和坐标。云端失败会提示并改用 Vision。"
            )

            VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
                Text("GLM-OCR API Key")
                    .font(AppFont.bodyEmphasis)
                SecureField(
                    settings.hasGLMOCRAPIKey ? "留空不会覆盖已保存的 Key" : "输入 API Key",
                    text: $apiKeyDraft
                )
                .textFieldStyle(.roundedBorder)

                HStack(spacing: DesignTokens.spaceS) {
                    Label(
                        settings.hasGLMOCRAPIKey ? "已安全保存" : "尚未保存",
                        systemImage: settings.hasGLMOCRAPIKey ? "checkmark.shield.fill" : "key.slash"
                    )
                    .font(AppFont.caption)
                    .foregroundStyle(settings.hasGLMOCRAPIKey ? DesignTokens.success : DesignTokens.secondaryText)

                    if let saveMessage {
                        Text(saveMessage)
                            .font(AppFont.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .contentTransition(.opacity)
                            .transition(MarlaMotion.contentTransition(reducesMotion: reducesMotion))
                    }

                    Spacer()

                    Button("移除 Key", role: .destructive) {
                        settings.removeGLMOCRAPIKey()
                        apiKeyDraft = ""
                        saveMessage = "已移除"
                    }
                    .disabled(!settings.hasGLMOCRAPIKey)

                    Button("保存") { saveKey() }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignTokens.accent)
                        .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.top, DesignTokens.spaceXS)
        }
    }

    private func saveKey() {
        do {
            try settings.saveGLMOCRAPIKey(apiKeyDraft)
            apiKeyDraft = ""
            saveMessage = "已保存"
        } catch {
            saveMessage = "保存失败"
        }
    }
}
