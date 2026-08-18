import AppKit
import Carbon
import Combine
import Foundation

enum GlobalShortcutAction: String, CaseIterable, Codable, Sendable {
    case selection
    case screenshot
    case quickInput

    var title: String {
        switch self {
        case .selection: "划词翻译"
        case .screenshot: "截图翻译"
        case .quickInput: "快速输入"
        }
    }

    var symbolName: String {
        switch self {
        case .selection: "text.viewfinder"
        case .screenshot: "viewfinder"
        case .quickInput: "keyboard"
        }
    }

    var hotKeyID: UInt32 {
        switch self {
        case .selection: 1
        case .screenshot: 2
        case .quickInput: 3
        }
    }

    init?(hotKeyID: UInt32) {
        switch hotKeyID {
        case 1: self = .selection
        case 2: self = .screenshot
        case 3: self = .quickInput
        default: return nil
        }
    }
}

struct ShortcutBinding: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt

    var displayName: String {
        var result = ""
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { result += "⌃" }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { result += "⌥" }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { result += "⇧" }
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { result += "⌘" }
        switch keyCode {
        case 49: result += "Space"
        case 36: result += "Return"
        case 48: result += "Tab"
        case 51: result += "Delete"
        case 2: result += "D"
        case 1: result += "S"
        case 0: result += "A"
        case 3: result += "F"
        case 4: result += "H"
        case 5: result += "G"
        case 6: result += "Z"
        case 7: result += "X"
        case 8: result += "C"
        case 9: result += "V"
        case 11: result += "B"
        case 12: result += "Q"
        case 13: result += "W"
        case 14: result += "E"
        case 15: result += "R"
        case 16: result += "Y"
        case 17: result += "T"
        case 31: result += "O"
        case 32: result += "U"
        case 34: result += "I"
        case 35: result += "P"
        case 37: result += "L"
        case 38: result += "J"
        case 40: result += "K"
        case 45: result += "N"
        case 46: result += "M"
        default: result += "Key \(keyCode)"
        }
        return result
    }

    var hasCommandModifier: Bool {
        let supported = NSEvent.ModifierFlags.command.rawValue
            | NSEvent.ModifierFlags.control.rawValue
            | NSEvent.ModifierFlags.option.rawValue
            | NSEvent.ModifierFlags.shift.rawValue
        return modifiers & supported != 0
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { value |= UInt32(cmdKey) }
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { value |= UInt32(controlKey) }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { value |= UInt32(optionKey) }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { value |= UInt32(shiftKey) }
        return value
    }

    static let defaults: [GlobalShortcutAction: ShortcutBinding] = [
        .selection: ShortcutBinding(keyCode: 2, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue),
        .screenshot: ShortcutBinding(keyCode: 1, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue),
        .quickInput: ShortcutBinding(keyCode: 49, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue)
    ]

    static func conflictingAction(
        in bindings: [GlobalShortcutAction: ShortcutBinding],
        candidate: ShortcutBinding,
        excluding action: GlobalShortcutAction
    ) -> GlobalShortcutAction? {
        bindings.first(where: { $0.key != action && $0.value == candidate })?.key
    }
}

@MainActor
protocol GlobalShortcutManaging: AnyObject {
    var bindings: [GlobalShortcutAction: ShortcutBinding] { get }
    var enabledActions: Set<GlobalShortcutAction> { get }
    var conflictMessage: String? { get }
    func isEnabled(_ action: GlobalShortcutAction) -> Bool
    func setEnabled(_ enabled: Bool, for action: GlobalShortcutAction)
    func set(_ binding: ShortcutBinding, for action: GlobalShortcutAction)
    func restoreDefaults()
    func conflict(for binding: ShortcutBinding, excluding action: GlobalShortcutAction) -> GlobalShortcutAction?
}

private let marlaHotKeySignature: OSType = 0x4D52_4C41 // MRLA

enum MarlaRuntime {
    static var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    static var isUIAutomationSnapshot: Bool {
        ProcessInfo.processInfo.environment["MARLA_UI_TEST_CAPTURE_PATH"] != nil
            || ProcessInfo.processInfo.environment["MARLA_PERFORMANCE_REPORT_PATH"] != nil
    }
}

private func handleMarlaHotKeyEvent(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in manager.handleHotKey(id: hotKeyID.id) }
    return noErr
}

@MainActor
final class GlobalShortcutManager: ObservableObject, GlobalShortcutManaging {
    @Published private(set) var bindings = ShortcutBinding.defaults
    @Published private(set) var enabledActions = Set(GlobalShortcutAction.allCases)
    @Published private(set) var conflictMessage: String?
    var onAction: ((GlobalShortcutAction) -> Void)?
    private var eventHandler: EventHandlerRef?
    private var registeredHotKeys: [GlobalShortcutAction: EventHotKeyRef] = [:]
    private let defaults: UserDefaults
    private let shouldRegisterHotKeys: Bool

    init(
        registerHotKeys: Bool = !MarlaRuntime.isXcodePreview,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        shouldRegisterHotKeys = registerHotKeys
        load()
        guard registerHotKeys else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handleMarlaHotKeyEvent,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        if status != noErr {
            conflictMessage = "无法初始化全局快捷键服务（错误 \(status)）。"
        } else if let action = register(bindings, enabledActions: enabledActions) {
            conflictMessage = "\(action.title)的快捷键已被系统或其他应用占用，请重新录制。"
        }
    }

    func isEnabled(_ action: GlobalShortcutAction) -> Bool {
        enabledActions.contains(action)
    }

    func setEnabled(_ enabled: Bool, for action: GlobalShortcutAction) {
        let previous = enabledActions
        var candidate = enabledActions
        if enabled {
            candidate.insert(action)
        } else {
            candidate.remove(action)
        }
        if let unavailable = register(bindings, enabledActions: candidate) {
            _ = register(bindings, enabledActions: previous)
            conflictMessage = "\(unavailable.title)的快捷键已被系统或其他应用占用，请重新录制。"
            return
        }
        enabledActions = candidate
        conflictMessage = nil
        save()
    }

    func set(_ binding: ShortcutBinding, for action: GlobalShortcutAction) {
        guard binding.hasCommandModifier else {
            conflictMessage = "快捷键至少需要包含 ⌘、⌃、⌥ 或 ⇧ 中的一个修饰键。"
            return
        }
        if let conflict = conflict(for: binding, excluding: action) {
            conflictMessage = "\(binding.displayName) 已用于\(conflict.title)，请使用其他组合键。"
            return
        }
        let previous = bindings
        var candidate = bindings
        candidate[action] = binding
        if let unavailable = register(candidate, enabledActions: enabledActions) {
            _ = register(previous, enabledActions: enabledActions)
            conflictMessage = "\(unavailable.title)的 \(binding.displayName) 已被占用，请使用其他组合键。"
            return
        }
        bindings = candidate
        conflictMessage = nil
        save()
    }

    func restoreDefaults() {
        let previous = bindings
        let previousEnabled = enabledActions
        let allEnabled = Set(GlobalShortcutAction.allCases)
        if let unavailable = register(ShortcutBinding.defaults, enabledActions: allEnabled) {
            _ = register(previous, enabledActions: previousEnabled)
            conflictMessage = "默认快捷键 \(unavailable.title) 已被占用，请保留当前设置或重新录制。"
            return
        }
        bindings = ShortcutBinding.defaults
        enabledActions = allEnabled
        conflictMessage = nil
        save()
    }

    func conflict(for binding: ShortcutBinding, excluding action: GlobalShortcutAction) -> GlobalShortcutAction? {
        ShortcutBinding.conflictingAction(in: bindings, candidate: binding, excluding: action)
    }

    func handleHotKey(id: UInt32) {
        guard let action = GlobalShortcutAction(hotKeyID: id), isEnabled(action) else { return }
        onAction?(action)
    }

    private func register(
        _ candidate: [GlobalShortcutAction: ShortcutBinding],
        enabledActions: Set<GlobalShortcutAction>
    ) -> GlobalShortcutAction? {
        unregisterAll()
        guard shouldRegisterHotKeys else { return nil }
        for action in GlobalShortcutAction.allCases {
            guard enabledActions.contains(action) else { continue }
            guard let binding = candidate[action] else { continue }
            var reference: EventHotKeyRef?
            let identifier = EventHotKeyID(signature: marlaHotKeySignature, id: action.hotKeyID)
            let status = RegisterEventHotKey(
                UInt32(binding.keyCode),
                binding.carbonModifiers,
                identifier,
                GetApplicationEventTarget(),
                0,
                &reference
            )
            guard status == noErr, let reference else {
                unregisterAll()
                return action
            }
            registeredHotKeys[action] = reference
        }
        return nil
    }

    private func unregisterAll() {
        registeredHotKeys.values.forEach { UnregisterEventHotKey($0) }
        registeredHotKeys.removeAll()
    }

    private func load() {
        if let data = defaults.data(forKey: "shortcutBindings"),
           let decoded = try? JSONDecoder().decode([GlobalShortcutAction: ShortcutBinding].self, from: data) {
            bindings = decoded
        }
        if let data = defaults.data(forKey: "shortcutEnabledActions.v1"),
           let decoded = try? JSONDecoder().decode(Set<GlobalShortcutAction>.self, from: data) {
            enabledActions = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: "shortcutBindings")
        }
        if let data = try? JSONEncoder().encode(enabledActions) {
            defaults.set(data, forKey: "shortcutEnabledActions.v1")
        }
    }

}

