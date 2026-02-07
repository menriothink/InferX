import SwiftUI

#if os(macOS)
import AppKit

@MainActor
struct UltramanTextEditor: NSViewRepresentable {
    @Environment(\.locale) private var locale

    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var isEnabled: Bool = true
    
    private var localizedPlaceholder: String {
        // IMPORTANT (macOS):
        // `String(localized:..., locale:)` does not reliably follow SwiftUI's
        // `.environment(\.locale, ...)` override for choosing the language in all cases.
        // To make the placeholder strictly follow the view hierarchy locale, we resolve the
        // string from the corresponding `.lproj` bundle ourselves.
        Self.localizedString(placeholder, locale: locale)
    }
    
    private static func localizedString(_ key: String, locale: Locale) -> String {
        let sentinel = "\u{0}__MISSING__\u{0}"
        
        func value(in localization: String) -> String? {
            guard let path = Bundle.main.path(forResource: localization, ofType: "lproj"),
                  let bundle = Bundle(path: path)
            else { return nil }
            
            let result = bundle.localizedString(forKey: key, value: sentinel, table: nil)
            return result == sentinel ? nil : result
        }
        
        var candidates: [String] = []
        func addCandidate(_ id: String?) {
            guard let id, !id.isEmpty else { return }
            let normalized = id.replacingOccurrences(of: "_", with: "-")
            if !candidates.contains(normalized) { candidates.append(normalized) }
        }
        
        let normalizedIdentifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        
        // Try the full locale identifier first (e.g. "zh-Hans", "en-GB").
        addCandidate(normalizedIdentifier)
        
        // Then try language-script / language-region / language fallbacks.
        let languageCode = locale.language.languageCode?.identifier
        let scriptCode = locale.language.script?.identifier
        let regionCode = locale.region?.identifier
        
        if let languageCode {
            // Special handling for Chinese:
            // Many system locales come through as "zh-CN"/"zh-TW" without an explicit script.
            // But our app localizations use script-based IDs like "zh-Hans"/"zh-Hant" (and "zh-HK").
            if languageCode == "zh",
               !normalizedIdentifier.localizedCaseInsensitiveContains("Hans"),
               !normalizedIdentifier.localizedCaseInsensitiveContains("Hant"),
               scriptCode == nil {
                let region = regionCode?.uppercased()
                switch region {
                case "HK", "MO":
                    // Prefer zh-HK if present, then fall back to Traditional Chinese.
                    addCandidate("zh-HK")
                    addCandidate("zh-Hant")
                case "TW":
                    addCandidate("zh-Hant")
                default:
                    // CN/SG/MY/… default to Simplified Chinese.
                    addCandidate("zh-Hans")
                }
            }
            
            addCandidate(scriptCode.map { "\(languageCode)-\($0)" })
            addCandidate(regionCode.map { "\(languageCode)-\($0)" })
            addCandidate(languageCode)
        }
        
        for candidate in candidates {
            if let localized = value(in: candidate) {
                return localized
            }
        }
        
        // If we can't find a matching `.lproj`, fall back to the key itself (English source).
        return key
    }

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
        context.coordinator.parent = self
        let textView = nsView.documentView as! NSTextView
        textView.isEditable = isEnabled
        textView.isSelectable = isEnabled
        context.coordinator.updateTextView(to: text, in: textView)
        context.coordinator.updatePlaceholderText()
        context.coordinator.updatePlaceholderVisibility(for: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
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
            placeholder.string = parent.localizedPlaceholder
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
        
        func updatePlaceholderText() {
            placeholderView?.string = parent.localizedPlaceholder
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
                Text(LocalizedStringKey(placeholder))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
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
