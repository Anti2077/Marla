import SwiftUI

struct SettingsView: View {
    @AppStorage("targetLanguage") private var targetLanguage = "zh-Hans"
    @AppStorage("comparisonMode") private var comparisonMode = false
    @AppStorage("cloudStructuredOCR") private var cloudStructuredOCR = true
    @AppStorage("forceTouchExperimental") private var forceTouchExperimental = false

    var body: some View {
        Form {
            Section("翻译") {
                Picker("目标语言", selection: $targetLanguage) {
                    Text("简体中文").tag("zh-Hans")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                }

                Toggle("默认使用对照模式", isOn: $comparisonMode)
            }

            Section("截图 OCR") {
                Toggle("使用云端结构化 OCR", isOn: $cloudStructuredOCR)

                Text("关闭后将使用 macOS Vision。Vision 只避免上传图片，翻译文本仍可能发送到云端。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("实验功能") {
                Toggle("重按触控板触发原位翻译", isOn: $forceTouchExperimental)

                Text("全局重按支持仍需跨应用验证，键盘快捷键将始终保留。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 390)
        .padding()
    }
}
