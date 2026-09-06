import SwiftUI

struct ExperimentalSettingsSection: View {
    @ObservedObject var settings: MarlaSettingsStore
    @ObservedObject var appModel: MarlaApplicationModel

    var body: some View {
        SettingsSection(title: "实验性功能", systemImage: "flask") {
            HStack(alignment: .top, spacing: DesignTokens.spaceL) {
                Image(systemName: "rectangle.dashed.badge.record")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignTokens.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                    Toggle(
                        "原位翻译",
                        isOn: Binding(
                            get: { settings.isInPlaceTranslationEnabled },
                            set: { enabled in
                                appModel.setInPlaceTranslationEnabled(enabled)
                            }
                        )
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(AppFont.bodyEmphasis)

                    Text("截图后在原区域覆盖结构化译文。当前强制使用 GLM-OCR，复杂背景、版面或表格可能保留原图。")
                        .font(AppFont.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DesignTokens.spaceM)

                Text(settings.isInPlaceTranslationEnabled ? "已启用" : "默认关闭")
                    .font(AppFont.micro)
                    .foregroundStyle(settings.isInPlaceTranslationEnabled ? DesignTokens.success : DesignTokens.secondaryText)
                    .padding(.horizontal, DesignTokens.spaceS)
                    .padding(.vertical, DesignTokens.spaceXS)
                    .background(DesignTokens.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 52)

            Divider()

            Label(
                "开启后，菜单和快捷键设置中会出现独立的“原位翻译”入口；普通“截图翻译”不受影响。",
                systemImage: "info.circle"
            )
            .font(AppFont.caption)
            .foregroundStyle(DesignTokens.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
