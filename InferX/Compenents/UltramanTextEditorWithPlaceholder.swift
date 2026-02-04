import SwiftUI

#if os(macOS)
import AppKit

struct UltramanTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var isEnabled: Bool = true

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = .clear
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isEditable = isEnabled
        textView.isSelectable = isEnabled

        context.coordinator.setupPlaceholder(for: textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        textView.isEditable = isEnabled
        textView.isSelectable = isEnabled
        context.coordinator.updateTextView(to: text, in: textView)
        context.coordinator.updatePlaceholderVisibility(for: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: UltramanTextEditor
        var placeholderView: NSTextView?

        init(_ parent: UltramanTextEditor) {
            self.parent = parent
        }

        func updateTextView(to newText: String, in textView: NSTextView) {
            if textView.string != newText {
                textView.string = newText
            }
        }

        func setupPlaceholder(for textView: NSTextView) {
            let placeholder = NSTextView(frame: textView.bounds)
            placeholder.backgroundColor = .clear
            placeholder.textColor = NSColor.secondaryLabelColor
            placeholder.font = textView.font
            placeholder.string = parent.placeholder
            placeholder.isEditable = false
            placeholder.isSelectable = false
            placeholder.isHorizontallyResizable = false
            placeholder.isVerticallyResizable = true
            placeholder.textContainer?.containerSize = CGSize(
                width: textView.textContainer!.size.width,
                height: .greatestFiniteMagnitude
            )
            placeholder.textContainer?.widthTracksTextView = true
            placeholderView = placeholder

            textView.addSubview(placeholder)
            updatePlaceholderVisibility(for: textView)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            parent.text = textView.string
            updatePlaceholderVisibility(for: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            updatePlaceholderVisibility(for: textView)
        }

        func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                } else {
                    parent.onSubmit()
                    updatePlaceholderVisibility(for: textView)
                    return true
                }
            }
            return false
        }

        func updatePlaceholderVisibility(for textView: NSTextView) {
            placeholderView?.isHidden =
                !textView.string.isEmpty || textView.selectedRange().length > 0
            placeholderView?.frame = textView.bounds
        }
    }
}

#else

struct UltramanTextEditor: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var isEnabled: Bool = true

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
            }

            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .disabled(!isEnabled)
                .submitLabel(.send)
                .onSubmit(onSubmit)
        }
    }
}

#endif
