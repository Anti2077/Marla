import CoreGraphics
import Foundation

enum TranslationWindowPlacement: String, CaseIterable, Identifiable {
    case automatic
    case centered
    case followMouse
    case fixedXCentered
    case rememberLastPosition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "自动避让来源"
        case .centered: "固定居中"
        case .followMouse: "跟随鼠标"
        case .fixedXCentered: "固定横坐标（垂直居中）"
        case .rememberLastPosition: "记住上次位置"
        }
    }

    var detail: String {
        switch self {
        case .automatic: "划词时靠近选区并避开原文；截图时优先显示在框选区域右侧。"
        case .centered: "窗口始终出现在当前屏幕中央。"
        case .followMouse: "窗口靠近触发时的鼠标位置出现。"
        case .fixedXCentered: "使用固定的屏幕 X 坐标，窗口垂直居中。"
        case .rememberLastPosition: "记住你上次移动窗口后的位置；首次使用时从当前屏幕中央开始。"
        }
    }

    static let defaultFixedX: CGFloat = 120
}
