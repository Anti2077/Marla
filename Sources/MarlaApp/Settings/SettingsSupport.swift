import AppKit
import MarlaCore
import SwiftUI
import UniformTypeIdentifiers

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
