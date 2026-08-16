import AppKit
import MarlaCore
import SwiftUI

final class MarkdownPasteTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var richPasteContent: () -> TranslationContent? = {
        NativeFormattedContentNormalizer.content(from: .general)
    }

    override func paste(_ sender: Any?) {
        guard let content = richPasteContent() else {
            super.paste(sender)
            return
        }
        insertText(content.text, replacementRange: selectedRange())
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if [36, 76].contains(event.keyCode), modifiers.contains(.command) {
            onSubmit?()
            return
        }
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
}

struct QuickInputMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let editor = MarkdownPasteTextView(frame: .zero)
        editor.delegate = context.coordinator
        editor.string = text
        editor.font = .systemFont(ofSize: 14)
        editor.textColor = .labelColor
        editor.insertionPointColor = .labelColor
        editor.drawsBackground = false
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainerInset = .zero
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        editor.onSubmit = onSubmit
        editor.onCancel = onCancel
        editor.setAccessibilityLabel("要翻译的文字")
        scrollView.documentView = editor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let editor = scrollView.documentView as? MarkdownPasteTextView else { return }
        context.coordinator.parent = self
        editor.onSubmit = onSubmit
        editor.onCancel = onCancel
        if editor.string != text {
            let selection = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(NSIntersectionRange(selection, NSRange(location: 0, length: editor.string.utf16.count)))
        }
        guard isFocused, editor.window?.firstResponder !== editor else { return }
        DispatchQueue.main.async { [weak editor] in
            guard let editor, self.isFocused else { return }
            editor.window?.makeFirstResponder(editor)
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        guard let editor = scrollView.documentView as? MarkdownPasteTextView else { return }
        editor.delegate = nil
        editor.onSubmit = nil
        editor.onCancel = nil
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QuickInputMarkdownEditor

        init(parent: QuickInputMarkdownEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }
    }
}
