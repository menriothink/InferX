//
//  MessageWithMarkdown.swift
//  InferX
//
//  Created by mingdw on 2025/4/6.
//

import SwiftUI
import MarkdownUI
import SwiftUIX
import Defaults
import RegexBuilder
import Splash

struct MessageWithMarkdown: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(ConversationDetailModel.self) private var detailModel
    @Environment(ModelManagerModel.self) var modelManager

    private var controlTextColor: SwiftUI.Color {
        #if os(macOS)
        SwiftUI.Color(NSColor.controlTextColor)
        #else
        SwiftUI.Color.primary
        #endif
    }
    
    let messageData: MessageData
    let isBottomMessage: Bool
        
    @State private var showThink = false
    @State private var showToast = false
    @State private var showMardDown = false
    @State private var displayedContent = ""
    @State private var displayedSegments: [String] = []
    @State private var numOfVisable = 1
    @State private var isFold = true
    private let limitChar = 500
    
    @State private var isVisible = true
    @State private var messageIsEmpty = true
    @State private var lastContent = ""
    @State private var messageMinHeight: CGFloat = 0
    @State private var remainedHeight: CGFloat = 0
    
    @State private var processedContent = ProcessedContent(content: "", contentCache: [:])
    @State var mdView: (any View)?
    @State private var parser = IncrementalMarkdownParser()
        
    @Default(.fontWeightBlack) var fontWeightBlack
    @Default(.fontWeightWhite) var fontWeightWhite
    @Default(.fontSizeBlack) var fontSizeBlack
    @Default(.fontSizeWhite) var fontSizeWhite
    @Default(.fontNameWhite) var fontNameWhite
    @Default(.fontNameBlack) var fontNameBlack
    @Default(.backgroundContentLightRadius) var backgroundContentLightRadius
    @Default(.backgroundContentDarkRadius) var backgroundContentDarkRadius
        
    var fontName: String {
        get {
            colorScheme == .dark ? fontNameBlack : fontNameWhite
        }
    }
    
    var fontSize: CGFloat {
        get {
            colorScheme == .dark ? fontSizeBlack : fontSizeWhite
        }
    }
    
    var fontWeight: FontWeightOption {
        get {
            colorScheme == .dark ? fontWeightBlack : fontWeightWhite
        }
    }

    var backGroundRadius: CGFloat {
        get {
            colorScheme == .dark ? backgroundContentDarkRadius : backgroundContentLightRadius
        }
    }
    
    private func chunk(from content: String, start: String.Index, step: Int) -> (chunk: String, nextIndex: String.Index) {
        let end = content.index(start, offsetBy: step, limitedBy: content.endIndex) ?? content.endIndex
        let part = String(content[start..<end])
        return (part, end)
    }
    
    private var codeHighlightColorScheme: Splash.Theme {
        switch colorScheme {
        case .dark:
            return .darkTheme
        default:
            return .sundellsColors
        }
    }
    
    var body: some View {
        let thinkContent = messageData.think
        let realContent = messageData.realContent
        
        VStack(alignment: .leading, spacing: 0) {
            
            if !isFold || !detailModel.foldEnable {
                markDownView(thinkContent: thinkContent, realContent: realContent, showMenu: !detailModel.inferring || !isBottomMessage)
            } else {
                let prefixContent = realContent.prefix(limitChar)
                markDownView(thinkContent: thinkContent, realContent: String(prefixContent), showMenu: !detailModel.inferring || !isBottomMessage)
            }
                
            Spacer()
        }
        .frame(minHeight: self.messageMinHeight)
        .task(id: detailModel.inferring) {
            if isBottomMessage, detailModel.inferring {
                self.messageMinHeight = max((detailModel.currentVisableHeight ?? 50) - 50, 0)
                isFold = false
                showThink = true
            }
        }
        .onChange(of: detailModel.foldEnable) { oldValue, newValue in
            if !oldValue, newValue {
                isFold = true
            }
        }
        .animation(.easeIn(duration: 0.5), value: isFold)
        #if os(iOS)
        .padding(.leading, 0)
        #else
        .padding(.leading, 5)
        #endif
    }
 
    private var iconSpacing: CGFloat {
        #if os(iOS)
        return 6
        #else
        return 8
        #endif
    }

    @ViewBuilder
    private var modelIconView: some View {
        #if os(iOS)
        if let tab = matchedTab(modelProvider: messageData.modelProvider) {
            tab.icon
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.15), radius: 3, x: -1, y: 3)
        } else {
            Image("AppIconSidebar")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.15), radius: 3, x: -1, y: 3)
        }
        #else
        matchedTab(
            modelProvider: messageData.modelProvider
        )?.iconView() ?? Image("AppIconSidebar")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 25, height: 25)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.25), radius: 5, x: -1, y: 5)
        #endif
    }

    @ViewBuilder
    func markDownView(thinkContent: String, realContent: String, showMenu: Bool = false) -> some View {
        HStack(alignment: .top, spacing: iconSpacing) {
            modelIconView
            
            VStack(alignment: .leading, spacing: 10) {
                TimeEscapeView(
                    messageData: messageData,
                    isBottomMessage: isBottomMessage,
                    realContent: !realContent.isEmpty
                )
                .font(.footnote)
                .foregroundColor(.secondary)
                
                if !thinkContent.isEmpty {
                    let thinkComplete = !realContent.isEmpty ||
                                        !detailModel.inferring ||
                                        !isBottomMessage
                    
                    ThinkingView(
                        showThink: $showThink,
                        thinkContent: thinkContent,
                        thinkComplete: thinkComplete,
                        colorScheme: colorScheme
                    )
                }
                
                if !realContent.isEmpty {
                    if detailModel.mardDownEnable {
                        if isBottomMessage, detailModel.inferring {
                            VStack(alignment: .leading) {
                                markDownContent(parser.completedContent)
                                
                                if let attrStr = try? AttributedString(
                                    markdown: parser.streamingContent,
                                    options: AttributedString.MarkdownParsingOptions(
                                      allowsExtendedAttributes: true)) {
                                    TextView(attrStr)
                                        .animation(nil, value: parser.completedContent)
                                } else {
                                    TextView(parser.streamingContent)
                                        .animation(nil, value: parser.completedContent)
                                }
                                
                            }
                            .task(id: processedContent.content, priority: .background) {
                                parser.process(newContent: processedContent.content)
                            }
                        } else {
                            markDownContent(
                                (lastContent == realContent && !processedContent.content.isEmpty)
                                    ? processedContent.content
                                    : realContent
                            )
                        }
                    } else {
                        plainTextContent(realContent)
                    }
                }
                
                // Fold button + Menu inside the same VStack as content
                if showMenu {
                    if detailModel.foldEnable && messageData.realContent.count > limitChar {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isFold.toggle()
                            }
                        }) {
                            HStack {
                                Spacer()
                                Label(
                                    !isFold ? "Collapse" : "Expand All",
                                    systemImage: !isFold ? "arrow.up.right.and.arrow.down.left" : "arrow.down.right.and.arrow.up.left"
                                )
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.vertical, 6)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    
                    MenuView(messageData: messageData)
                }
            }
            .task(id: realContent, priority: .background) {
                guard !realContent.isEmpty else { return }

                #if os(macOS)
                // Avoid heavy preprocessing while the user is actively scrolling.
                if !(isBottomMessage && detailModel.inferring) {
                    // Wait until scrolling is idle for a short debounce window.
                    while true {
                        while detailModel.isScrolling {
                            if Task.isCancelled { return }
                            try? await Task.sleep(nanoseconds: 80_000_000)
                        }
                        if Task.isCancelled { return }
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        if !detailModel.isScrolling { break }
                    }
                }
                #endif

                let newProcessedContent = ContentProcessor.shared.preprocess(markdown: realContent)
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    processedContent = newProcessedContent
                    lastContent = realContent
                }
            }
        }
    }

    @ViewBuilder
    func markDownContent(_ content: String) -> some View {
        Markdown(content)
            .markdownTextStyle {
                FontFamily(.custom(fontName))
                FontWeight(fontWeight.actualWeight)
                FontSize(fontSize)
                ForegroundColor(controlTextColor)
            }
            .processedContent(processedContent)
            .markdownTheme(MarkdownColours.enchantedThemeMedium)
            //.markdownCodeSyntaxHighlighter(.splash(theme: codeHighlightColorScheme))
            .markdownCodeSyntaxHighlighter(
                CodeHighlighter(
                    colorScheme: colorScheme,
                    fontSize: fontSize * 0.8,
                    enabled: true
                )
            )
            .markdownInlineAttributeRewriter(inlineRewriter)
            .markdownInlineTextRenderer{ attributedString, container, fontSize, fontColor in
                renderInlineText(attributedString: attributedString,
                                 with: container,
                                 fontSize: fontSize,
                                 fontColor: fontColor,
                                 contentCache: processedContent.contentCache,
                                 searchKey: SearchKey(c: conversationModel.searchText, d: detailModel.searchText)
                )
            }
            .padding(10)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(backGroundRadius))
                    .stroke(Color.white.opacity(backGroundRadius), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private func plainTextContent(_ content: String) -> some View {
        let resolvedFont: SwiftUI.Font = {
            if fontName == "System Font" {
                return .system(size: fontSize, weight: fontWeight.actualWeight)
            }
            // For custom fonts, `.weight(...)` may not take effect depending on the font family,
            // but we keep it for consistency with the Markdown renderer.
            return .custom(fontName, size: fontSize).weight(fontWeight.actualWeight)
        }()
        
        Text(verbatim: content)
            .font(resolvedFont)
            .foregroundStyle(controlTextColor)
            .multilineTextAlignment(.leading)
            .padding(10)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(backGroundRadius))
                    .stroke(Color.white.opacity(backGroundRadius), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    func popView() -> some View {
        VStack {
            ScrollView {
                if showMardDown {
                    Markdown(messageData.content)
                    markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontWeight(fontWeight.actualWeight)
                        FontSize(fontSize)
                        ForegroundColor(controlTextColor)
                    }
                    .markdownTheme(MarkdownColours.enchantedThemeMedium)
                    .markdownCodeSyntaxHighlighter(.splash(theme: codeHighlightColorScheme))
                } else {
                    TextView(messageData.content)
                }
            }
            
            Button {
                withAnimation {
                    showMardDown = !showMardDown
                }
            } label: {
                Image(systemName: showMardDown ? "doc.plaintext" : "doc.text")
            }
        }
        #if os(macOS)
        #if os(macOS)
        .frame(width: 500, height: 600)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .padding()
    }
}
