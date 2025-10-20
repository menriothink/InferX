import SwiftUI
import AppKit

enum TextOrImageFragment: Identifiable, Hashable {
    case text(String)
    case image(NSImage)
    
    var id: String {
        switch self {
        case .text(let s): return s
        case .image(let img): return img.size.width.description + img.size.height.description + String(img.hash)
        }
    }
}

struct CombinedTextAndImageView: View {
    let fragments: [TextOrImageFragment]
    
    @Environment(\.font) private var font

    var body: some View {
        createText()
    }

    private func createText() -> Text {
        let nsFont = resolveFont()

        var resultingText = Text("")

        for fragment in fragments {
            switch fragment {
            case .text(let string):
                do {
                    let markers = hasUnclosedMarkdownDelimiters(string)
                    var tex = string
                    
                    for marker in markers {
                        if tex.trimmingCharacters(in: .whitespacesAndNewlines) == marker.delimiter {
                            tex = ""
                        } else if marker.hasLeading && !marker.hasTrailing {
                            tex = tex.trimmingCharacters(in: .whitespacesAndNewlines) + marker.delimiter
                        } else if !marker.hasLeading && marker.hasTrailing {
                            tex = marker.delimiter + tex.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    
                    tex = tex.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let match = tex.range(of: #"^(\d+)\."#, options: .regularExpression) {
                        tex.replaceSubrange(match, with: tex[match].replacingOccurrences(of: ".", with: "\\."))
                    }
                                            
                    resultingText = resultingText + Text(try AttributedString(
                        markdown: tex,
                        options: AttributedString.MarkdownParsingOptions(
                            allowsExtendedAttributes: true,
                            interpretedSyntax: .full,
                            failurePolicy: .returnPartiallyParsedIfPossible))) + Text(" ")
                } catch {
                    resultingText = resultingText + Text(string) + Text(" ")
                }
                
            case .image(let nsImage):
                let image = Image(nsImage: nsImage)
                
                var imageAsText = Text("\(image)")
                
                let imageHeight = nsImage.size.height
                let fontXHeight = nsFont.xHeight
                let offset = (imageHeight / 2.0) - (fontXHeight / 2.0)
                let baselineOffset = -offset
                
                imageAsText = imageAsText
                    .baselineOffset(baselineOffset)
                
                resultingText = resultingText + imageAsText + Text(" ")
            }
        }
        return resultingText
    }
    
    private func resolveFont() -> NSFont {
        var container = AttributeContainer()
        container.font = self.font
        let attributedString = NSAttributedString(AttributedString(" ", attributes: container))
        
        if let fontFromAttributes = attributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont, fontFromAttributes.pointSize > 0 {
            return fontFromAttributes
        }
        return .systemFont(ofSize: NSFont.systemFontSize)
    }
    
    private func hasUnclosedMarkdownDelimiters(_ text: String) -> [(delimiter: String, hasLeading: Bool, hasTrailing: Bool)] {
        let delimiters = ["**", "*", "__", "_", "~~", "`"]
        var result: [(String, Bool, Bool)] = []

        for delimiter in delimiters {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let count = trimmed.components(separatedBy: delimiter).count - 1

            let hasLeading = trimmed.hasPrefix(delimiter) && count % 2 != 0
            let hasTrailing = trimmed.hasSuffix(delimiter) && count % 2 != 0

            result.append((delimiter, hasLeading, hasTrailing))
        }

        return result
    }
}
