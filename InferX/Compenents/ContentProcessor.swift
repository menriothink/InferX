//
//  ContentProcessor.swift
//  InferX
//
//  Created by mingdw on 2025/6/19.
//

import Foundation
import SwiftUI
import SwiftMath
import SwiftSoup
import WebKit
import MarkdownUI
import SwiftData

// MARK: - Data Structures
struct ProcessedContent {
    let content: String
    let contentCache: [String: CachedContent]
}

enum CachedContent {
    case latexBlock(String)
    case htmlBlock(String)
    case latexInline(String)
    case htmlInline(String)
    case nativeChart(ParsedChart)
}

private let placeHolderStart = "PLACEHOLDER_START_"
private let placeHolderEnd = "_PLACEHOLDER_END"

private let emojiMap: [String: String] = {
    guard let url = Bundle.main.url(forResource: "emoji", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let emojis = try? JSONDecoder().decode([String: String].self, from: data) else {
        print("❌ ERROR: Could not load or decode emoji.json")
        return [:]
    }
    print("✅ SUCCESS: Loaded \(emojis.count) emojis from emoji.json")
    return emojis
}()

// MARK: - ContentProcessor
final class ContentProcessor {

    @MainActor static let shared = ContentProcessor()

    // MARK: - State Management

    private var contentCache: [String: CachedContent] = [:]

    private let blockLevelHTMLTags: Set<String> = [
        "div", "table", "iframe", "video", "canvas", "details"
    ]

    private let inlineLevelHTMLTags: Set<String> = [
        "span", "b", "strong", "i", "em", "u", "font", "mark", "sub", "sup",
        "p", "h2", "h3", "h4", "ul", "abbr", "cite", "dfn", "kbd", "a"
    ]

    func reset() {
        contentCache.removeAll()
    }

    func preprocess(markdown: String) -> ProcessedContent {
        reset() // Start with a clean slate

        var processedText = markdown

        processedText = replaceEmojiShortcodes(in: processedText)
        processedText = replaceMermaidBlocks(in: processedText)

        // --- Stage 1: Protect Code Blocks ---
        // Prevents LaTeX/HTML inside code from being processed.
        var protectedCodeStore: [String: String] = [:]
        let codeProtectionRegex = try! NSRegularExpression(
            pattern: #"""
            # Fenced code blocks
            ^ \s* (?<fence>`{3,}|~{3,}) .*? \n [\s\S]+? \n \s* \k<fence> \s* $
            |
            # Inline code, double backticks
            `` [^`\n]*? ``
            |
            # Inline code, single backtick
            # Key fix: content must not start or end with $
            # This prevents it from matching cases like `$code$` which might be mistaken for LaTeX
            `
            #(?!\$)  # Cannot start with $
            [^`\n]+? # Content
            #(?<!\$) # Cannot end with $
            `
            """#,
            options: [.allowCommentsAndWhitespace, .anchorsMatchLines]
        )

        let codeMatches = codeProtectionRegex.matches(in: processedText, range: NSRange(processedText.startIndex..., in: processedText)).reversed()
        for (index, match) in codeMatches.enumerated() {
            guard let range = Range(match.range, in: processedText) else { continue }
            let placeholder = "__CODE_PLACEHOLDER_\(index)__"
            protectedCodeStore[placeholder] = String(processedText[range])
            processedText.replaceSubrange(range, with: placeholder)
        }

        processedText = replaceFullHtmlDocuments(in: processedText)
        processedText = replaceHtmlTags(in: processedText)
        processedText = replaceLatexMatches(in: processedText)

        var finalCache = self.contentCache
        for (key, content) in self.contentCache {
            if case .htmlInline(var htmlString) = content {
                // Apply code restoration logic to each HTML snippet
                for (placeholder, originalCode) in protectedCodeStore {
                    htmlString = htmlString.replacingOccurrences(of: placeholder, with: originalCode)
                }
                // Update the value in the dictionary
                finalCache[key] = .htmlInline(htmlString)
            }

            if case .htmlBlock(var htmlString) = content {
                // Apply code restoration logic to each HTML snippet
                for (placeholder, originalCode) in protectedCodeStore {
                    htmlString = htmlString.replacingOccurrences(of: placeholder, with: originalCode)
                }
                // Update the value in the dictionary
                finalCache[key] = .htmlBlock(htmlString)
            }
        }
        // Replace the old cache with the restored one
        self.contentCache = finalCache

        // Stage B: Restore code in the main text flow
        for (placeholder, originalCode) in protectedCodeStore {
            processedText = processedText.replacingOccurrences(of: placeholder, with: originalCode)
        }

        // Return the final result; at this point, HTML in contentCache is complete
        return ProcessedContent(content: processedText, contentCache: self.contentCache)
    }

    // MARK: - Preprocessing Helpers
    private func replaceEmojiShortcodes(in text: String) -> String {
        var processedText = text
        let shortcodeRegex = try! NSRegularExpression(pattern: #":([a-zA-Z0-9_+-]+?):"#)

        let matches = shortcodeRegex.matches(in: processedText, range: NSRange(processedText.startIndex..., in: processedText)).reversed()

        for match in matches {
            guard let fullRange = Range(match.range, in: processedText),
                  let keyRange = Range(match.range(at: 1), in: processedText) else { continue }

            let key = String(processedText[keyRange])

            if let emoji = emojiMap[key] {
                processedText.replaceSubrange(fullRange, with: emoji)
            }
        }

        return processedText
    }

    private func replaceMermaidBlocks(in text: String) -> String {
        var processedText = text
        let mermaidRegex = try! NSRegularExpression(
            pattern: #"""
            ^ \s* ```mermaid \s* $  # Match starting fence ```mermaid
            ( [\s\S]+? )            # Capture group 1: Chart content (non-greedy)
            ^ \s* ``` \s* $          # Match ending fence ```
            """#,
            options: [.anchorsMatchLines, .allowCommentsAndWhitespace]
        )

        let matches = mermaidRegex.matches(in: processedText, range: NSRange(processedText.startIndex..., in: processedText)).reversed()

        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: processedText),
                  let contentRange = Range(match.range(at: 1), in: processedText)
            else { continue }

            let mermaidContent = String(processedText[contentRange])

            let placeholder = "\(placeHolderStart)\((UUID().uuidString))\(placeHolderEnd)"

            if let parsedChart = MermaidParser.parse(mermaidCode: mermaidContent) {
                self.contentCache[placeholder] = .nativeChart(parsedChart)
            } else {
                self.contentCache[placeholder] = .htmlBlock(mermaidContent)
            }

            let indentation = getIndentation(of: fullRange.lowerBound, in: processedText)
            let replacementString = "\n\n" + indentation + placeholder + "\n\n"
            processedText.replaceSubrange(fullRange, with: replacementString)

            // print("--- DEBUG: Extracted a MERMAID block. ---")
        }

        return processedText
    }

    private func replaceLatexMatches(in text: String) -> String {
        var processedText = text

        let latexRegex = try! NSRegularExpression(
            pattern: #"""
            # x: Extended/comment mode (enabled by .allowCommentsAndWhitespace)
            # s: '.' matches newline (enabled by .dotMatchesLineSeparators)
            # m: '^' matches line start (enabled by .anchorsMatchLines)

            # Block equations (match $$...$$ or \[...\] on a line by itself)
            (?:(?<=^|\n)\s*)
            (
              \$\$ .+? \$\$ |
              \\\[ .+? \\\]
            ) |
            # Inline equations (match $...$ or \(...\) but avoid matching $$)
            (?<!\$)\$ ([^\$\n]+) \$(?!\$) |
            \\\( .+? \\\)
            """#,
            options: [
                .allowCommentsAndWhitespace, // Correct option to enable comments and free spacing mode
                .anchorsMatchLines,          // Makes ^ and $ match start and end of lines
                .dotMatchesLineSeparators    // Makes '.' match newline characters
            ]
        )

        let matches = latexRegex.matches(in: processedText, range: NSRange(processedText.startIndex..., in: processedText))

        guard !matches.isEmpty else { return processedText }

        for match in matches.reversed() {
            guard let range = Range(match.range, in: processedText) else { continue }

            let originalMatch = String(processedText[range])
            let trimmingMatch = originalMatch.trimmingCharacters(in: .whitespacesAndNewlines)

            let isBlock = trimmingMatch.hasPrefix("$$") || trimmingMatch.hasPrefix("\\[")

            //if !component.type.inline { // Block LaTeX
            if isBlock { // Block LaTeX
                let placeholder = "\(placeHolderStart)\((UUID().uuidString))\(placeHolderEnd)"
                self.contentCache[placeholder] = .latexBlock(trimmingMatch)

                let indentation = getIndentation(of: range.lowerBound, in: processedText)
                let replacementString = "\n\n" + indentation + placeholder + "\n\n"
                processedText.replaceSubrange(range, with: replacementString)
            } else { // Inline LaTeX
                let placeholder = "\(placeHolderStart)\((UUID().uuidString))\(placeHolderEnd)"
                self.contentCache[placeholder] = .latexInline(trimmingMatch)
                processedText.replaceSubrange(range, with: placeholder)
            }
        }
        return processedText
    }

    private func replaceFullHtmlDocuments(in text: String) -> String {
        var processedText = text
        let fullHtmlDocRegex = try! NSRegularExpression(
            pattern: #"""
            (?isx) # i:case-insensitive, s:'.'matches newline, x:extended mode
            # Match the entire block from optional DOCTYPE to </html>
            (
                (?: \s* <!DOCTYPE \s+ html \s* > \s* )?
                <html[^>]*> [\s\S]+? <\/html>
            )
            """#,
            options: []
        )

        // [CRITICAL] Match reversed() to ensure correct ranges
        let matches = fullHtmlDocRegex.matches(in: processedText, range: NSRange(processedText.startIndex..., in: processedText)).reversed()

        for match in matches {
            // [CRITICAL] We are now interested in the entire match (group 0) as it includes DOCTYPE
            guard let fullRange = Range(match.range(at: 0), in: processedText) else { continue }

            // [CRITICAL] Store the complete HTML including DOCTYPE in the cache
            let originalHTML = String(processedText[fullRange])

            let placeholder = "\(placeHolderStart)\(UUID().uuidString)\(placeHolderEnd)"
            self.contentCache[placeholder] = .htmlBlock(originalHTML)

            // Replacement logic remains unchanged
            let indentation = getIndentation(of: fullRange.lowerBound, in: processedText)
            let replacementString = "\n\n" + indentation + placeholder + "\n\n"
            processedText.replaceSubrange(fullRange, with: replacementString)
        }
        return processedText
    }

    /// **New Function 2: Only responsible for extracting whitelisted HTML snippets**
    private func replaceHtmlTags(in text: String) -> String {
        var processedText = text
        // The regex remains unchanged as it effectively finds paired tags
        let snippetRegex = try! NSRegularExpression(
            pattern: """
            <!--[\\s\\S]*?-->| # HTML Comments
            <([a-zA-Z0-9]+)(?:\\s[^>]*)?>[\\s\\S]*?<\\/\\1> # Paired Tags
            """,
            options: [.caseInsensitive, .dotMatchesLineSeparators, .allowCommentsAndWhitespace]
        )

        let snippetMatches = snippetRegex.matches(in: processedText, range: NSRange(processedText.startIndex..., in: processedText)).reversed()

        for match in snippetMatches {
            guard match.numberOfRanges > 1,
                  let tagNameRange = Range(match.range(at: 1), in: processedText)
            else {
                continue // Skip HTML comments
            }

            let tagName = String(processedText[tagNameRange]).lowercased()

            // Check if the tag is block-level or inline
            if blockLevelHTMLTags.contains(tagName) {
                // --- Process block-level tags ---
                guard let fullRange = Range(match.range(at: 0), in: processedText) else { continue }
                let originalHTML = String(processedText[fullRange])

                let placeholder = "\(placeHolderStart)\(UUID().uuidString)\(placeHolderEnd)"
                self.contentCache[placeholder] = .htmlBlock(originalHTML)

                // Block-level tags always add newlines, forcing them to become a standalone block
                let indentation = getIndentation(of: fullRange.lowerBound, in: processedText)
                let replacementString = "\n\n" + indentation + placeholder + "\n\n"
                processedText.replaceSubrange(fullRange, with: replacementString)
            } else if inlineLevelHTMLTags.contains(tagName) {
                // --- Process inline-level tags ---
                guard let fullRange = Range(match.range(at: 0), in: processedText) else { continue }
                let originalHTML = String(processedText[fullRange])

                let placeholder = "\(placeHolderStart)\(UUID().uuidString)\(placeHolderEnd)"
                self.contentCache[placeholder] = .htmlInline(originalHTML)

                // Inline tags are replaced directly without adding newlines, keeping them in the text flow
                processedText.replaceSubrange(fullRange, with: placeholder)
            }
            // If the tag is not in any whitelist, it is not processed and remains as raw text.
        }
        return processedText
    }

    private func getIndentation(of index: String.Index, in text: String) -> String {
        let lineStart = text.lineRange(for: index..<index).lowerBound
        let lineEnd = text[lineStart...].firstIndex(where: { !$0.isWhitespace }) ?? text.lineRange(for: index..<index).upperBound
        return String(text[lineStart..<lineEnd])
    }
}
    // MARK: - 2. Block Rendering

/// Renders a custom view for a block-level placeholder.
@ViewBuilder
func renderBlock(fontSize: CGFloat, fontWeight: FontWeightOption, cachedContent: CachedContent) -> some View {
    //let _ = print("--- DEBUG: placeholderKey:\n \(cachedContent) \n---------------------------------")
    switch cachedContent {
    case .latexBlock(let latexString):
        LatexBlockView(latexString: latexString, fontSize: fontSize, fontWeight: fontWeight)
    case .htmlBlock(let htmlString):
        HTMLBlockView(htmlContent: htmlString, fontSize: fontSize, fontWeight: fontWeight)
    case .nativeChart(let parsedChart):
        NativeChartView(chartInfo: parsedChart)
    default:
        Text("")
    }
}

func matchBlockPlaceholder(plainString: String, contentCache: [String: CachedContent]) -> CachedContent? {
    let trimmingString = plainString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmingString.hasPrefix(placeHolderStart), plainString.hasSuffix(placeHolderEnd) else {
        return nil
    }

    guard let content = contentCache[trimmingString] else {
        return nil
    }

    if case .latexBlock = content {
        return content
    }

    if case .htmlBlock = content {
        return content
    }

    if case .nativeChart = content {
        return content
    }

    return nil
}

func hasPlaceholder(plainString: String) -> Bool {
    let trimmingString = plainString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmingString.contains(placeHolderStart), plainString.contains(placeHolderEnd) else {
        return false
    }

    return true
}

// MARK: - Inline Rendering Helpers
func inlineRewriter(_ text: String, _ container: AttributeContainer) -> AttributedString {
    var newAttributedString: AttributedString = .init(text, attributes: container)

    guard hasPlaceholder(plainString: text) else {
        return newAttributedString
    }

    let placeholderPattern = "\(placeHolderStart)[A-F0-9\\-]+\(placeHolderEnd)"
    guard let regex = try? NSRegularExpression(pattern: placeholderPattern) else {
        return newAttributedString
    }

    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    for match in matches {
        guard let range = Range(match.range, in: newAttributedString) else { continue }
        let placeholderKey = String(newAttributedString[range].characters)
        var newContainer = container
        newContainer.placeholderKey = placeholderKey
        newAttributedString[range].mergeAttributes(newContainer, mergePolicy: .keepNew)
    }

    return newAttributedString
}

private func renderInlineLatex(_ latexString: String, fontSize: CGFloat, fontColor: Color) -> Text {

    let (_, nsImage) = MTMathImage(
        latex: latexString,
        fontSize: fontSize,
        textColor: MTColor(fontColor),
        labelMode: .text
    ).asImage()

    guard let nsImage else { return Text(latexString).foregroundColor(.red) }

    // Align baseline
    let baselineOffset = -((nsImage.size.height / 2) - (fontSize / 2) + 2)
    return Text(Image(nsImage: nsImage)).baselineOffset(baselineOffset)
}

private func restoreInlineHTML(_ htmlString: String, baseAttributes: AttributeContainer) -> AttributedString? {
    do {
        // 1. Parse using SwiftSoup
        let doc: Document = try SwiftSoup.parse(htmlString)
        guard let element = doc.body()?.children().first() else {
            return AttributedString(htmlString.strippingHTML(), attributes: baseAttributes)
        }

        // 2. Extract text and build from baseAttributes
        let plainText = try element.text()
        var attrString = AttributedString(plainText, attributes: baseAttributes)

        // 3. Get the current font from attrString; if it doesn't exist, use a default value
        // This is the base we will modify
        var currentFont = attrString.font ?? .body

        let tagName = element.tagName().lowercased()

        // --- Incrementally modify font ---
        // Check for <b> or <strong> tags
        if tagName == "b" || tagName == "strong" {
            currentFont = currentFont.bold()
        }
        // Check for <i> or <em> tags
        if tagName == "i" || tagName == "em" {
            currentFont = currentFont.italic()
        }
        if tagName == "u" {
            attrString.underlineStyle = .single
        }

        if tagName == "kbd" {
            // Set special style for kbd
            currentFont = .system(.body, design: .monospaced) // Force monospaced font

            // Set background color
            #if os(macOS)
            attrString.backgroundColor = Color(NSColor.windowBackgroundColor)
            // Simulating borders in AttributedString is difficult,
            // but we can approximate it with the inline code's background color
            attrString.backgroundColor = Color(NSColor.textBackgroundColor).opacity(0.5)
            #else
            attrString.backgroundColor = Color(UIColor.secondarySystemBackground)
            #endif

            // Add a little extra letter spacing to simulate padding effect
            attrString.kern = 0.5
        }

        // --- Parse style attribute and incrementally modify ---
        if let style = try? element.attr("style") {
            let styleDict = parseCssStyle(style)

            // Handle font-weight
            if let fontWeight = styleDict["font-weight"], fontWeight.lowercased() == "bold" {
                currentFont = currentFont.bold()
            }

            // Handle font-style
            if let fontStyle = styleDict["font-style"], fontStyle.lowercased() == "italic" {
                currentFont = currentFont.italic()
            }

            // Handle color (modify directly on attrString, not affecting font)
            if let colorHex = styleDict["color"], let color = Color(hex: colorHex) {
                attrString.foregroundColor = color
            }
        }

        // --- Apply the finally calculated font back ---
        attrString.font = currentFont

        // 4. (Optional) Handle other tags, like underline
        if tagName == "u" {
            attrString.underlineStyle = .single
        }

        // 5. [IMPORTANT] Since we have manually merged the fonts, mergeAttributes is no longer needed
        //    We start with baseAttributes and selectively override it, which is safer.
        return attrString

    } catch {
        print("SwiftSoup parsing error: \(error)")
        return AttributedString(htmlString.strippingHTML(), attributes: baseAttributes)
    }
}

// Using a CSS parser version with logging
private func parseCssStyle(_ style: String) -> [String: String] {
    var attributes: [String: String] = [:]
    let declarations = style.split(separator: ";")

    for declaration in declarations {
        let parts = declaration.split(separator: ":", maxSplits: 1)
        if parts.count == 2 {
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            //print("     - Parsed key: '\(key)', value: '\(value)'")
            attributes[key] = value
        }
    }
    return attributes
}

extension String {
    /// Removes all HTML tags from the string, returning plain text.
    /// E.g.: "<p>Hello</p>" will become "Hello".
    func strippingHTML() -> String {
        // Use a regular expression to replace all <...> style tags
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
}

extension Color {
    init?(hex: String) {
        let input = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // --- Step 1: Prioritize matching color names ---
        switch input {
            case "red":   self = .red;   return
            case "green": self = .green; return
            case "blue":  self = .blue;  return
            case "black": self = .black; return
            case "white": self = .white; return
            case "gray":  self = .gray;  return
            case "grey":  self = .gray;  return
            case "purple":self = .purple;return
            case "orange":self = .orange;return
            case "yellow":self = .yellow;return
            case "pink":  self = .pink;  return
            // More CSS color names can be added here
            default:
                // If not a known color name, continue attempting to parse as hex
                break
        }

        // --- Step 2: Attempt to parse as a hexadecimal value ---
        var hexSanitized = input
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r, g, b: Double
        switch hexSanitized.count {
        case 3: // RGB (e.g. "F0C")
            r = Double((rgb & 0xF00) >> 8) / 15.0
            g = Double((rgb & 0x0F0) >> 4) / 15.0
            b = Double(rgb & 0x00F) / 15.0
        case 6: // RRGGBB (e.g. "FF00CC")
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        default:
            // Length mismatch, initialization fails
            return nil
        }

        self.init(red: r, green: g, blue: b)
    }
}

func renderInlineText(
    attributedString: AttributedString,
    with attributes: AttributeContainer,
    fontSize: CGFloat,
    fontColor: Color,
    contentCache: [String: CachedContent],
    searchKey: SearchKey = SearchKey(c: "", d: ""),
    highlightColor: Color = .yellow
) -> Text {
    var finalTextView = Text("")

    for run in attributedString.runs {
        var finalAttributedString = AttributedString(attributedString[run.range])
        
        if let placeholderKey = run.attributes.placeholderKey {
            guard let content = contentCache[placeholderKey] else {
                finalTextView = finalTextView + Text(placeholderKey).foregroundColor(.red)
                continue
            }

            switch content {
            case .latexInline(let latexString):
                finalTextView = finalTextView + renderInlineLatex(latexString, fontSize: fontSize, fontColor: fontColor)
                continue
            case .htmlInline(let htmlString):
                if let restoredHTML = restoreInlineHTML(htmlString, baseAttributes: attributes) {
                    finalAttributedString = restoredHTML
                }
            default: break
            }
        }
        
        if !searchKey.c.isEmpty {
            finalAttributedString = highlightGeneralKeywords(
                finalAttributedString,
                keywords: searchKey.c,
                highlightColor: highlightColor
            )
        }
        
        if !searchKey.d.isEmpty {
            finalAttributedString = highlightGeneralKeywords(
                finalAttributedString,
                keywords: searchKey.d,
                highlightColor: highlightColor
            )
        }
        
        finalTextView = finalTextView + Text(finalAttributedString)
    }

    return finalTextView
}

private func highlightGeneralKeywords(
    _ attributedText: AttributedString,
    keywords: String,
    highlightColor: Color
) -> AttributedString {
    var mutableAttributedText = attributedText
        if let matchingRange = mutableAttributedText.range(of: keywords, options: .caseInsensitive) {
            mutableAttributedText[matchingRange].foregroundColor = highlightColor
            // mutableAttributedText[range].backgroundColor = highlightColor.opacity(0.2)
        }
    return mutableAttributedText
}

func extractNSFont(from run: AttributedString.Runs.Run, in attributedString: AttributedString) -> NSFont? {
    let slice = attributedString[run.range]
    let nsAttr = NSAttributedString(AttributedString(slice))
    return nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
}

// MARK: - Custom Block Views

struct LatexBlockView: View {
    let latexString: String
    let fontSize: CGFloat
    let fontWeight: FontWeightOption
    @State var webViewHeight: CGFloat = 1

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ConversationDetailModel.self) private var detailModel

    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black

        let (_, nsImage) = MTMathImage(
            latex: latexString,
            fontSize: fontSize,
            textColor: MTColor(textColor),
            labelMode: .display,
            textAlignment: .center
        ).asImage()

        HStack {
            Spacer()
            if let image = nsImage {
                Text(Image(nsImage: image))
                    .padding()
            } else {
                MathWebView(latexString: latexString,
                            fontSize: fontSize,
                            cssWeight: fontWeight.rawValue,
                            webViewHeight: $webViewHeight)
                /*Text("Failed to render LaTeX:\n\(latexString)")
                    .foregroundColor(.red)*/
                    .frame(height: webViewHeight)
                    .padding()
            }
            Spacer()
        }
        .padding(.bottom, 10)
    }
}

struct HTMLBlockView: View {
    let htmlContent: String
    let fontSize: CGFloat
    let fontWeight: FontWeightOption // Assuming FontWeightOption is a defined type

    @Environment(\.colorScheme) var colorScheme
    @State private var webViewHeight: CGFloat = 1

    private var htmlColor: String {
        return colorScheme == .dark ? "white" : "dark"
    }

    private var isInteractiveContent: Bool {
        // Use SwiftSoup for more reliable checking
        do {
            let doc: Document = try SwiftSoup.parse(htmlContent)

            // Check for interactive elements
            // a[href] represents an <a> tag with an href attribute
            let interactiveElementsQuery = "button, input, textarea, select, a[href], [onclick]"
            let elements = try doc.select(interactiveElementsQuery)

            if !elements.isEmpty() {
                // If any interactive element is found, return true
                return true
            }

            // Also, check for <script> tags, as they also imply interactivity
            if htmlContent.contains("<script") {
                return true
            }

        } catch {
            // If parsing fails, fall back to simple string check
            print("SwiftSoup parsing error in isInteractiveContent: \(error)")
            return htmlContent.contains("<script") || htmlContent.contains("<button")
        }

        return false
    }

    /// Fixed height defined for interactive content
    private let interactiveContentHeight: CGFloat = 500 // Increased height to accommodate accordions

    var body: some View {
        let finalHTML = isMermaidContent(htmlContent: htmlContent) ?
                            buildMermaidHTML(from: htmlContent, theme: htmlColor) : htmlContent

        WebView(
            htmlString: finalHTML,
            fontSize: fontSize,
            cssWeight: fontWeight.rawValue,
            isInteractive: false,
            webViewHeight: $webViewHeight
        )
        .frame(height: webViewHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

func buildMermaidHTML(from code: String, theme: String) -> String {
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            /* Basic style reset */
            body {
                margin: 0;
                padding: 10px; /* Give the chart some padding */
                background-color: transparent; /* Transparent background to fit SwiftUI view */
            }
            /* Mermaid container style */
            .mermaid {
                text-align: center; /* Chart centering */
            }
        </style>
    </head>
    <body>
        <!-- This div will be used to render the Mermaid chart -->
        <div class="mermaid">
            \(code)
        </div>

        <!-- Include Mermaid.js library -->
        <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
        <script>
            // Initialize Mermaid
            mermaid.initialize({
                startOnLoad: true,
                theme: '\(theme)', // Set 'dark' or 'default' based on system theme
                securityLevel: 'loose', // Set security level as needed
                fontFamily: '-apple-system, "Helvetica Neue", "Arial", sans-serif'
            });

            // (Optional) If startOnLoad is unreliable, you can render manually
            // mermaid.init(undefined, document.querySelectorAll('.mermaid'));

            // (Optional) Dynamically adjust WebView height
            // ... (Your existing height adjustment script can be placed here)
        </script>
    </body>
    </html>
    """
}

private func isMermaidContent(htmlContent: String) -> Bool {
    // In HTMLBlockView.swift
    let content = htmlContent.trimmingCharacters(in: .whitespacesAndNewlines)

    // Extend the keyword list to cover more chart types
    let mermaidKeywords = [
        "graph",          // Flowchart (TD, LR, etc.)
        "flowchart",      // Flowchart (new syntax)
        "sequenceDiagram",// Sequence diagram
        "classDiagram",   // Class diagram
        "stateDiagram",   // State diagram
        "gantt",          // Gantt chart
        "pie",            // Pie chart
        "erDiagram",      // ER diagram
        "journey",        // User journey map
        "mindmap"         // Mind map
        // ... More can be added as needed
    ]

    // Check if the content starts with any of the keywords
    for keyword in mermaidKeywords {
        if content.hasPrefix(keyword) {
            return true
        }
    }

    return false
}

private struct ProcessedContentKey: EnvironmentKey {
    static let defaultValue: ProcessedContent = ProcessedContent(content: "", contentCache: [:])
}

extension EnvironmentValues {
    var processedContent: ProcessedContent {
        get { self[ProcessedContentKey.self] }
        set { self[ProcessedContentKey.self] = newValue }
    }
}

extension View {
    func processedContent(_ content: ProcessedContent) -> some View {
        self.environment(\.processedContent, content)
    }
}

private enum MarkdownAttributeKeys {
    struct Placeholder: AttributedStringKey {
        typealias Value = String
        static let name = "com.yourapp.Markdown.PlaceholderKey"
    }
}

extension AttributeContainer {
    var placeholderKey: String? {
        get { self[MarkdownAttributeKeys.Placeholder.self] }
        set { self[MarkdownAttributeKeys.Placeholder.self] = newValue }
    }
}

private struct MessageIDKey: EnvironmentKey {
    static let defaultValue: PersistentIdentifier? = nil
}

extension EnvironmentValues {
    var messageID: PersistentIdentifier? {
        get { self[MessageIDKey.self] }
        set { self[MessageIDKey.self] = newValue }
    }
}

extension View {
    func messageID(_ id: PersistentIdentifier?) -> some View {
        self.environment(\.messageID, id)
    }
}
