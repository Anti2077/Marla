import AppKit
import MarlaCore

@MainActor
final class MarlaApplicationModel: ObservableObject {
    enum SelectionProbeResult: Equatable {
        case idle
        case success(
            text: String,
            hasBounds: Bool,
            applicationName: String?,
            surface: SurfaceType
        )
        case failure(message: String)
    }

    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var selectionProbeResult: SelectionProbeResult = .idle

    private let selectionReader: AccessibilitySelectionReader

    init(selectionReader: AccessibilitySelectionReader = AccessibilitySelectionReader()) {
        self.selectionReader = selectionReader
        refreshAccessibilityStatus()
    }

    func refreshAccessibilityStatus() {
        accessibilityTrusted = selectionReader.isTrusted
    }

    func requestAccessibilityAccess() {
        accessibilityTrusted = selectionReader.requestAccess()
    }

    func probeCurrentSelection() {
        do {
            let selection = try selectionReader.readSelection()
            selectionProbeResult = .success(
                text: selection.text,
                hasBounds: selection.bounds != nil,
                applicationName: selection.applicationName,
                surface: selection.applicationBundleID.map {
                    RustCoreBridge.classifySurface(applicationBundleID: $0)
                } ?? .unknown
            )
        } catch let error as SelectionReadingError {
            selectionProbeResult = .failure(message: message(for: error))
        } catch {
            selectionProbeResult = .failure(message: "读取选区时发生未知错误。")
        }

        refreshAccessibilityStatus()
    }

    private func message(for error: SelectionReadingError) -> String {
        switch error {
        case .accessibilityPermissionRequired:
            "请先授予辅助功能权限。"
        case .focusedElementUnavailable:
            "无法读取当前聚焦的界面元素。"
        case .selectedTextUnavailable:
            "当前应用没有提供可读取的选中文本。"
        case .emptySelection:
            "当前没有选中文字。"
        }
    }
}
