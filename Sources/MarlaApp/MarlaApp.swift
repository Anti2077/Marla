import AppKit
import MarlaCore
import SwiftUI

@main
struct MarlaApplication: App {
    @StateObject private var model = MarlaApplicationModel()

    var body: some Scene {
        MenuBarExtra("Marla", systemImage: "translate") {
            VStack(alignment: .leading, spacing: 8) {
                Text("瞬时翻译层")
                    .font(.headline)

                Text("M1 · 技术可行性验证")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Image(systemName: model.accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.accessibilityTrusted ? .green : .orange)

                    Text(model.accessibilityTrusted ? "辅助功能权限已就绪" : "需要辅助功能权限")
                        .font(.caption)
                }

                if model.accessibilityTrusted {
                    Button("检测当前选区") {
                        model.probeCurrentSelection()
                    }
                } else {
                    Button("授予辅助功能权限…") {
                        model.requestAccessibilityAccess()
                    }
                }

                selectionProbeSummary

                Divider()

                Button("原位翻译") {}
                    .disabled(true)

                Button("截图翻译") {}
                    .disabled(true)

                Button("快速输入") {}
                    .disabled(true)

                Divider()

                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                }

                Button("退出 Marla") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(8)
            .onAppear {
                model.refreshAccessibilityStatus()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    @ViewBuilder
    private var selectionProbeSummary: some View {
        switch model.selectionProbeResult {
        case .idle:
            EmptyView()
        case let .success(text, hasBounds, applicationName, surface):
            VStack(alignment: .leading, spacing: 3) {
                Text("已从\(applicationName ?? "当前应用")读取选区")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(text)
                    .font(.caption)
                    .lineLimit(2)

                Text(hasBounds ? "已取得选区位置" : "未取得位置，将需要附近浮窗降级")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Rust 语境分类：\(surfaceDescription(surface))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 260, alignment: .leading)
        case let .failure(message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 260, alignment: .leading)
        }
    }

    private func surfaceDescription(_ surface: SurfaceType) -> String {
        switch surface {
        case .terminal:
            "终端"
        case .codeEditor:
            "代码编辑器"
        case .browser:
            "浏览器"
        case .document:
            "文档"
        case .email:
            "邮件"
        case .chat:
            "聊天"
        case .fileManager:
            "文件管理器"
        case .image:
            "图片"
        case .unknown:
            "未知"
        }
    }
}
