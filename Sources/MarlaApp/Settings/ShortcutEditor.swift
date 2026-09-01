import AppKit
import SwiftUI

struct ShortcutEditorRow: View {
    let action: GlobalShortcutAction
    @ObservedObject var shortcuts: GlobalShortcutManager
    @Binding var editingAction: GlobalShortcutAction?
    @State private var draft: ShortcutBinding
    @AccessibilityFocusState private var isTriggerAccessibilityFocused: Bool
    @FocusState private var isTriggerKeyboardFocused: Bool
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.marlaReduceMotionOverride) private var reduceMotionOverride

    init(
        action: GlobalShortcutAction,
        shortcuts: GlobalShortcutManager,
        editingAction: Binding<GlobalShortcutAction?>
    ) {
        self.action = action
        self.shortcuts = shortcuts
        _editingAction = editingAction
        _draft = State(initialValue: shortcuts.bindings[action] ?? ShortcutBinding.defaults[action]!)
    }

    private var binding: ShortcutBinding {
        shortcuts.bindings[action] ?? ShortcutBinding.defaults[action]!
    }

    private var isEnabled: Bool {
        shortcuts.isEnabled(action)
    }

    private var isEditing: Bool {
        editingAction == action
    }

    var body: some View {
        HStack(spacing: DesignTokens.spaceM) {
            Image(systemName: action.symbolName)
                .foregroundStyle(DesignTokens.accent)
                .accessibilityHidden(true)
            Text(action.title)
                .font(AppFont.body)
                .frame(width: 84, alignment: .leading)
            Spacer(minLength: DesignTokens.spaceS)
            editorLane
                .frame(width: 332, height: 32, alignment: .trailing)
            Toggle(
                "启用\(action.title)快捷键",
                isOn: Binding(
                    get: { isEnabled },
                    set: { shortcuts.setEnabled($0, for: action) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .frame(minHeight: 32)
        .onChange(of: binding) { _, updatedBinding in
            if !isEditing {
                draft = updatedBinding.normalized
            }
        }
        .onChange(of: isEditing) { wasEditing, editing in
            guard wasEditing, !editing else { return }
            draft = binding.normalized
            Task { @MainActor in
                if !reducesMotion {
                    try? await Task.sleep(for: .milliseconds(340))
                }
                guard editingAction == nil else { return }
                isTriggerAccessibilityFocused = true
                isTriggerKeyboardFocused = true
            }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled, isEditing {
                dismissEditor()
            }
        }
        .onAppear {
            guard ProcessInfo.processInfo.environment["MARLA_UI_TEST_SHORTCUT_EDITOR_ACTION"] == action.rawValue else {
                return
            }
            draft = binding.normalized
            editingAction = action
        }
    }

    private func dismissEditor() {
        guard isEditing else { return }
        setEditingAction(nil)
    }

    private var reducesMotion: Bool {
        accessibilityReduceMotion || reduceMotionOverride
    }

    @ViewBuilder
    private var editorLane: some View {
        let isSnapshotRenderer = ProcessInfo.processInfo.environment["MARLA_UI_TEST_CAPTURE_PATH"] != nil
        if #available(macOS 26.0, *), !isSnapshotRenderer {
            GlassEffectContainer(spacing: DesignTokens.spaceS) {
                if isEditing {
                    inlineEditor(usesGlassChrome: true)
                        .padding(.horizontal, DesignTokens.spaceS)
                        .padding(.vertical, DesignTokens.spaceXS)
                        .glassEffect(.regular, in: .capsule)
                        .glassEffectID(action.rawValue, in: glassNamespace)
                        .glassEffectTransition(reducesMotion ? .identity : .matchedGeometry)
                } else {
                    glassTriggerButton
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID(action.rawValue, in: glassNamespace)
                        .glassEffectTransition(reducesMotion ? .identity : .matchedGeometry)
                }
            }
        } else {
            ZStack(alignment: .trailing) {
                if isEditing {
                    inlineEditor(usesGlassChrome: false)
                        .transition(fallbackTransition)
                } else {
                    triggerButton
                        .transition(fallbackTransition)
                }
            }
        }
    }

    private var triggerButton: some View {
        Button {
            beginEditing()
        } label: {
            triggerLabel
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!isEnabled)
        .help("编辑\(action.title)快捷键")
        .accessibilityLabel("编辑\(action.title)快捷键")
        .accessibilityValue(binding.displayName)
        .accessibilityFocused($isTriggerAccessibilityFocused)
        .focusable()
        .focused($isTriggerKeyboardFocused)
    }

    private var glassTriggerButton: some View {
        Button(action: beginEditing) {
            triggerLabel
                .padding(.horizontal, DesignTokens.spaceM)
                .frame(height: 28)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help("编辑\(action.title)快捷键")
        .accessibilityLabel("编辑\(action.title)快捷键")
        .accessibilityValue(binding.displayName)
        .accessibilityFocused($isTriggerAccessibilityFocused)
        .focusable()
        .focused($isTriggerKeyboardFocused)
    }

    private var triggerLabel: some View {
        Text(binding.displayName)
            .font(AppFont.micro.monospacedDigit())
            .frame(minWidth: 72)
    }

    private func inlineEditor(usesGlassChrome: Bool) -> some View {
        ShortcutInlineEditor(
            action: action,
            draft: $draft,
            errorMessage: shortcuts.conflictMessage,
            usesGlassChrome: usesGlassChrome,
            reducesMotion: reducesMotion,
            onCancel: dismissEditor,
            onCommit: {
                guard shortcuts.set($0, for: action) else { return false }
                dismissEditor()
                return true
            }
        )
    }

    private var fallbackTransition: AnyTransition {
        guard !reducesMotion else { return .opacity }
        return .opacity.combined(with: .scale(scale: 0.96, anchor: .trailing))
    }

    private func setEditingAction(_ action: GlobalShortcutAction?) {
        if reducesMotion {
            editingAction = action
        } else {
            withAnimation(MarlaMotion.shortcutMorph) {
                editingAction = action
            }
        }
    }

    private func beginEditing() {
        draft = binding.normalized
        isTriggerKeyboardFocused = false
        setEditingAction(action)
    }
}

private struct ShortcutInlineEditor: View {
    let action: GlobalShortcutAction
    @Binding var draft: ShortcutBinding
    let errorMessage: String?
    let usesGlassChrome: Bool
    let reducesMotion: Bool
    let onCancel: () -> Void
    let onCommit: (ShortcutBinding) -> Bool
    @State private var showsCommitError = false
    @State private var isHoveringCommitMessage = false
    @State private var escapeMonitor: Any?

    var body: some View {
        HStack(spacing: DesignTokens.spaceXS) {
            ForEach(ShortcutModifier.allCases) { modifier in
                modifierToggle(modifier)
            }

            Divider()
                .frame(height: 24)
                .padding(.horizontal, DesignTokens.spaceXS)

            ShortcutPrimaryKeyButton(
                keyCode: $draft.keyCode,
                usesGlassChrome: usesGlassChrome,
                reducesMotion: reducesMotion,
                onCancel: onCancel
            )

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("取消")
            .accessibilityLabel("取消\(action.title)快捷键编辑")

            commitButton
        }
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: draft) { _, _ in
            showsCommitError = false
        }
        .onAppear(perform: installEscapeMonitor)
        .onDisappear(perform: removeEscapeMonitor)
        .accessibilityAction(.escape, onCancel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("编辑\(action.title)快捷键")
        .accessibilityValue(draft.displayName)
    }

    private var validationMessage: String? {
        if !draft.hasSafeGlobalModifier {
            return "请选择 fn、Control、Option 或 Command；Shift 不能单独使用。"
        }
        if showsCommitError {
            return errorMessage ?? "无法注册这个组合键，请保留当前设置或选择其他组合。"
        }
        return nil
    }

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard event.keyCode == 53 else { return event }
            onCancel()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }

    @ViewBuilder
    private func modifierToggle(_ modifier: ShortcutModifier) -> some View {
        let isSelected = draft.contains(modifier)
        if usesGlassChrome {
            modifierToggleBase(modifier, isSelected: isSelected)
                .buttonStyle(.plain)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? DesignTokens.accent.opacity(0.2) : DesignTokens.secondarySurface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isSelected ? DesignTokens.accent.opacity(0.7) : .clear, lineWidth: 1)
                }
                .animation(
                    MarlaMotion.animation(MarlaMotion.feedback, reducesMotion: reducesMotion),
                    value: isSelected
                )
        } else {
            modifierToggleBase(modifier, isSelected: isSelected)
                .buttonStyle(.bordered)
        }
    }

    private func modifierToggleBase(
        _ modifier: ShortcutModifier,
        isSelected: Bool
    ) -> some View {
        Toggle(
            isOn: Binding(
                get: { draft.contains(modifier) },
                set: { draft = draft.setting(modifier, enabled: $0) }
            )
        ) {
            Text(modifier.symbol)
                .font(AppFont.bodyEmphasis)
                .frame(width: usesGlassChrome ? 32 : 24, height: 20)
        }
        .toggleStyle(.button)
        .controlSize(.small)
        .tint(isSelected ? DesignTokens.accent : nil)
        .help(modifier.accessibilityName)
        .accessibilityLabel(modifier.accessibilityName)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var commitButton: some View {
        if usesGlassChrome {
            Button {
                showsCommitError = !onCommit(draft)
            } label: {
                Image(systemName: validationMessage == nil ? "checkmark" : "exclamationmark")
                    .font(AppFont.caption)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.white)
                    .background(validationMessage == nil ? DesignTokens.accent : DesignTokens.warning, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!draft.hasSafeGlobalModifier)
            .opacity(draft.hasSafeGlobalModifier ? 1 : 0.45)
            .animation(
                MarlaMotion.animation(MarlaMotion.feedback, reducesMotion: reducesMotion),
                value: validationMessage
            )
            .help(validationMessage ?? "应用")
            .accessibilityLabel("应用\(action.title)快捷键")
            .accessibilityValue(validationMessage ?? "可应用")
            .onHover { hovering in
                guard draft.hasSafeGlobalModifier else { return }
                isHoveringCommitMessage = hovering && validationMessage != nil
            }
            .overlay {
                invalidCommitHelpTarget(shape: Circle())
            }
            .overlay(alignment: .topTrailing) {
                commitReasonTooltip
            }
        } else {
            Button {
                showsCommitError = !onCommit(draft)
            } label: {
                Image(systemName: validationMessage == nil ? "checkmark" : "exclamationmark")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!draft.hasSafeGlobalModifier)
            .help(validationMessage ?? "应用")
            .accessibilityLabel("应用\(action.title)快捷键")
            .accessibilityValue(validationMessage ?? "可应用")
            .onHover { hovering in
                guard draft.hasSafeGlobalModifier else { return }
                isHoveringCommitMessage = hovering && validationMessage != nil
            }
            .overlay {
                invalidCommitHelpTarget(shape: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .overlay(alignment: .topTrailing) {
                commitReasonTooltip
            }
        }
    }

    @ViewBuilder
    private func invalidCommitHelpTarget<S: Shape>(shape: S) -> some View {
        if !draft.hasSafeGlobalModifier, let validationMessage {
            Color.clear
                .contentShape(shape)
                .onTapGesture { }
                .onHover { hovering in
                    isHoveringCommitMessage = hovering
                }
                .help(validationMessage)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var commitReasonTooltip: some View {
        if isHoveringCommitMessage, let validationMessage {
            Text(validationMessage)
                .font(AppFont.micro)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, DesignTokens.spaceS)
                .padding(.vertical, DesignTokens.spaceXS)
                .fixedSize()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                .offset(y: -32)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct ShortcutPrimaryKeyButton: View {
    @Binding var keyCode: UInt16
    let usesGlassChrome: Bool
    let reducesMotion: Bool
    let onCancel: () -> Void
    @State private var isCapturing = false
    @State private var monitor: Any?

    @ViewBuilder
    var body: some View {
        if usesGlassChrome {
            captureButton(width: 32)
                .buttonStyle(.plain)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isCapturing ? DesignTokens.accent.opacity(0.16) : DesignTokens.secondarySurface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isCapturing ? DesignTokens.accent.opacity(0.8) : .clear, lineWidth: 1)
                }
                .animation(
                    MarlaMotion.animation(MarlaMotion.feedback, reducesMotion: reducesMotion),
                    value: isCapturing
                )
        } else {
            captureButton(width: 54)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func captureButton(width: CGFloat) -> some View {
        Button {
            isCapturing.toggle()
        } label: {
            Group {
                if isCapturing, usesGlassChrome {
                    Image(systemName: "ellipsis")
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(DesignTokens.accent)
                } else {
                    Text(isCapturing ? "按键…" : ShortcutBinding.keyDisplayName(for: keyCode))
                        .font(AppFont.micro.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
            .frame(width: width, height: 20)
            .contentTransition(.opacity)
        }
        .animation(
            MarlaMotion.animation(MarlaMotion.feedback, reducesMotion: reducesMotion),
            value: isCapturing
        )
        .help("输入主键")
        .accessibilityLabel("主键")
        .accessibilityValue(isCapturing ? "等待按键" : ShortcutBinding.keyDisplayName(for: keyCode))
        .onChange(of: isCapturing) { _, capturing in
            if capturing {
                installMonitor()
            } else {
                removeMonitor()
            }
        }
        .onDisappear {
            removeMonitor()
        }
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 {
                isCapturing = false
                onCancel()
                return nil
            }
            keyCode = event.keyCode
            isCapturing = false
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
