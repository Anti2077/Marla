import AppKit
import Carbon
import Combine
import Foundation

enum GlobalShortcutAction: String, CaseIterable, Codable, Sendable {
    case selection
    case screenshot
    case inPlace
    case quickInput

    var title: String {
        switch self {
        case .selection: "划词翻译"
        case .screenshot: "截图翻译"
        case .inPlace: "原位翻译"
        case .quickInput: "快速输入"
        }
    }

    var symbolName: String {
        switch self {
        case .selection: "text.viewfinder"
        case .screenshot: "viewfinder"
        case .inPlace: "rectangle.dashed"
        case .quickInput: "keyboard"
        }
    }

    var hotKeyID: UInt32 {
        switch self {
        case .selection: 1
        case .screenshot: 2
        case .inPlace: 4
        case .quickInput: 3
        }
    }

    init?(hotKeyID: UInt32) {
        switch hotKeyID {
        case 1: self = .selection
        case 2: self = .screenshot
        case 3: self = .quickInput
        case 4: self = .inPlace
        default: return nil
        }
    }
}

struct ShortcutBinding: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt

    var displayName: String {
        let prefix = ShortcutModifier.displayOrder
            .filter(contains)
            .map(\.symbol)
            .joined()
        return prefix + Self.keyDisplayName(for: keyCode)
    }

    var hasSafeGlobalModifier: Bool {
        ShortcutModifier.allCases.contains { $0.isSafePrimaryModifier && contains($0) }
    }

    var normalized: ShortcutBinding {
        let supportedMask = ShortcutModifier.allCases.reduce(into: UInt(0)) { result, modifier in
            result |= modifier.eventFlag.rawValue
        }
        return ShortcutBinding(keyCode: keyCode, modifiers: modifiers & supportedMask)
    }

    var carbonModifiers: UInt32 {
        ShortcutModifier.allCases.reduce(into: UInt32(0)) { result, modifier in
            if contains(modifier) {
                result |= modifier.carbonMask
            }
        }
    }

    func contains(_ modifier: ShortcutModifier) -> Bool {
        modifiers & modifier.eventFlag.rawValue != 0
    }

    func setting(_ modifier: ShortcutModifier, enabled: Bool) -> ShortcutBinding {
        var updated = self
        if enabled {
            updated.modifiers |= modifier.eventFlag.rawValue
        } else {
            updated.modifiers &= ~modifier.eventFlag.rawValue
        }
        return updated
    }

    static func keyDisplayName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: "Space"
        case 36: "Return"
        case 48: "Tab"
        case 51: "Delete"
        case 2: "D"
        case 1: "S"
        case 0: "A"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 31: "O"
        case 32: "U"
        case 34: "I"
        case 35: "P"
        case 37: "L"
        case 38: "J"
        case 40: "K"
        case 45: "N"
        case 46: "M"
        default: "Key \(keyCode)"
        }
    }

    static let defaults: [GlobalShortcutAction: ShortcutBinding] = [
        .selection: ShortcutBinding(keyCode: 2, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.shift.rawValue),
        .screenshot: ShortcutBinding(keyCode: 1, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.shift.rawValue),
        .inPlace: ShortcutBinding(keyCode: 34, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.shift.rawValue),
        .quickInput: ShortcutBinding(keyCode: 49, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.shift.rawValue),
    ]

    static let preInPlaceDefaults: [GlobalShortcutAction: ShortcutBinding] = [
        .selection: ShortcutBinding(keyCode: 2, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.shift.rawValue),
        .screenshot: ShortcutBinding(keyCode: 1, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.shift.rawValue),
        .quickInput: ShortcutBinding(keyCode: 49, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.shift.rawValue),
    ]

    static let legacyDefaults: [GlobalShortcutAction: ShortcutBinding] = [
        .selection: ShortcutBinding(keyCode: 2, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue),
        .screenshot: ShortcutBinding(keyCode: 1, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue),
        .quickInput: ShortcutBinding(keyCode: 49, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue),
    ]

    static func conflictingAction(
        in bindings: [GlobalShortcutAction: ShortcutBinding],
        candidate: ShortcutBinding,
        excluding action: GlobalShortcutAction
    ) -> GlobalShortcutAction? {
        bindings.first(where: {
            $0.key != action
                && $0.value.keyCode == candidate.keyCode
                && $0.value.carbonModifiers == candidate.carbonModifiers
        })?.key
    }
}

@MainActor
protocol GlobalShortcutManaging: AnyObject {
    var bindings: [GlobalShortcutAction: ShortcutBinding] { get }
    var enabledActions: Set<GlobalShortcutAction> { get }
    var conflictMessage: String? { get }
    func isEnabled(_ action: GlobalShortcutAction) -> Bool
    func setEnabled(_ enabled: Bool, for action: GlobalShortcutAction)
    @discardableResult
    func set(_ binding: ShortcutBinding, for action: GlobalShortcutAction) -> Bool
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
    private var suppressedActions = Set<GlobalShortcutAction>()
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
        } else if let action = register(bindings, enabledActions: registrationActions(enabledActions)) {
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
        if let unavailable = register(bindings, enabledActions: registrationActions(candidate)) {
            _ = register(bindings, enabledActions: registrationActions(previous))
            conflictMessage = "\(unavailable.title)的快捷键已被系统或其他应用占用，请重新录制。"
            return
        }
        enabledActions = candidate
        conflictMessage = nil
        save()
    }

    func setFeatureEnabled(_ enabled: Bool, for action: GlobalShortcutAction) {
        let wasSuppressed = suppressedActions.contains(action)
        if enabled {
            suppressedActions.remove(action)
        } else {
            suppressedActions.insert(action)
        }
        guard wasSuppressed != !enabled else { return }

        let effectiveActions = registrationActions(enabledActions)
        if let unavailable = register(bindings, enabledActions: effectiveActions) {
            if enabled {
                suppressedActions.insert(action)
            } else {
                suppressedActions.remove(action)
            }
            _ = register(bindings, enabledActions: registrationActions(enabledActions))
            conflictMessage = "\(unavailable.title)的快捷键已被系统或其他应用占用，请重新录制。"
        } else {
            conflictMessage = nil
        }
    }

    @discardableResult
    func set(_ binding: ShortcutBinding, for action: GlobalShortcutAction) -> Bool {
        let binding = binding.normalized
        guard binding.hasSafeGlobalModifier else {
            conflictMessage = "快捷键至少需要包含 fn、⌘、⌃ 或 ⌥ 中的一个；⇧ 不能单独作为全局修饰键。"
            return false
        }
        if let conflict = conflict(for: binding, excluding: action) {
            conflictMessage = "\(binding.displayName) 已用于\(conflict.title)，请使用其他组合键。"
            return false
        }
        let previous = bindings
        var candidate = bindings
        candidate[action] = binding
        if let unavailable = register(candidate, enabledActions: registrationActions(enabledActions)) {
            _ = register(previous, enabledActions: registrationActions(enabledActions))
            conflictMessage = "\(unavailable.title)的 \(binding.displayName) 已被占用，请使用其他组合键。"
            return false
        }
        bindings = candidate
        conflictMessage = nil
        save()
        return true
    }

    func restoreDefaults() {
        let previous = bindings
        let previousEnabled = enabledActions
        let allEnabled = Set(GlobalShortcutAction.allCases)
        if let unavailable = register(ShortcutBinding.defaults, enabledActions: registrationActions(allEnabled)) {
            _ = register(previous, enabledActions: registrationActions(previousEnabled))
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
        guard let action = GlobalShortcutAction(hotKeyID: id),
              isEnabled(action),
              !suppressedActions.contains(action)
        else { return }
        onAction?(action)
    }

    private func registrationActions(_ actions: Set<GlobalShortcutAction>) -> Set<GlobalShortcutAction> {
        actions.subtracting(suppressedActions)
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
        var migratedCompleteDefaults = false
        if let data = defaults.data(forKey: "shortcutBindings"),
           let decoded = try? JSONDecoder().decode([GlobalShortcutAction: ShortcutBinding].self, from: data) {
            if decoded == ShortcutBinding.legacyDefaults || decoded == ShortcutBinding.preInPlaceDefaults {
                bindings = ShortcutBinding.defaults
                migratedCompleteDefaults = true
            } else {
                bindings = decoded
            }
        }
        if let data = defaults.data(forKey: "shortcutEnabledActions.v1"),
           let decoded = try? JSONDecoder().decode(Set<GlobalShortcutAction>.self, from: data) {
            enabledActions = decoded == Set(ShortcutBinding.preInPlaceDefaults.keys)
                ? Set(GlobalShortcutAction.allCases)
                : decoded
        }
        if migratedCompleteDefaults {
            save()
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
