import CoreGraphics
import Foundation

enum TranslationWindowWidthPreset: String, CaseIterable, Identifiable {
    case narrow
    case medium
    case wide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .narrow: "窄"
        case .medium: "中"
        case .wide: "宽"
        }
    }

    var width: CGFloat {
        switch self {
        case .narrow: 380
        case .medium: 520
        case .wide: 680
        }
    }
}
