import SwiftUI

struct UltramanTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 6, height: 6)

        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude+6)

        textView.allowsUndo = true
        
        context.coordinator.setupPlaceholder(for: textView)

        scrollView.scrollerStyle = .overlay
        scrollView.contentInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        scrollView.hasVerticalScroller = true
        textView.maxSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude+6)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self

        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            context.coordinator.updateTextView(to: text, in: textView)
        }
        
        context.coordinator.updatePlaceholderText()

        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: UltramanTextEditor
        var placeholderView: NSTextView?
        private var isUpdatingFromSwiftUI = false

        init(_ parent: UltramanTextEditor) {
            self.parent = parent
            super.init()
        }

        func updateTextView(to newText: String, in textView: NSTextView) {
            isUpdatingFromSwiftUI = true
            
            textView.string = newText
            
            isUpdatingFromSwiftUI = false
        }
        
        func setupPlaceholder(for textView: NSTextView) {
            let placeholder = NSTextView(frame: textView.bounds)
            placeholder.isSelectable = false

            placeholder.font = textView.font
            placeholder.string = parent.placeholder
            placeholder.alignment = .left
            placeholder.textContainerInset = NSSize(width: 6, height: 0)

            textView.addSubview(placeholder)
            placeholderView = placeholder

            updatePlaceholderVisibility(for: textView)
        }
        
        func updatePlaceholderText() {
            if let placeholderView, placeholderView.string != parent.placeholder {
                placeholderView.string = parent.placeholder
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI else {
                return
            }
            
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
            _ textView: NSTextView, doCommandBy commandSelector: Selector
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
        }
    }
}
