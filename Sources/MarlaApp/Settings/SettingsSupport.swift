import SwiftUI

struct StatusLine: View {
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
