import AppKit
import Carbon

enum ShortcutModifier: String, CaseIterable, Identifiable, Sendable {
    case function
    case shift
    case control
    case option
    case command

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .function: "fn"
        case .shift: "⇧"
        case .control: "⌃"
        case .option: "⌥"
        case .command: "⌘"
        }
    }

    var accessibilityName: String {
        switch self {
        case .function: "Fn 或地球键"
        case .shift: "Shift"
        case .control: "Control"
        case .option: "Option"
        case .command: "Command"
        }
    }

    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .function: .function
        case .shift: .shift
        case .control: .control
        case .option: .option
        case .command: .command
        }
    }

    var carbonMask: UInt32 {
        switch self {
        case .function: UInt32(kEventKeyModifierFnMask)
        case .shift: UInt32(shiftKey)
        case .control: UInt32(controlKey)
        case .option: UInt32(optionKey)
        case .command: UInt32(cmdKey)
        }
    }

    var isSafePrimaryModifier: Bool {
        self != .shift
    }

    static let displayOrder: [ShortcutModifier] = [
        .function,
        .control,
        .option,
        .shift,
        .command,
    ]
}
