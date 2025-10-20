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
                markDownView(thinkContent: thinkContent, realContent: realContent)
            } else {
                let prefixContent = realContent.prefix(limitChar)
                markDownView(thinkContent: thinkContent, realContent: String(prefixContent))
            }
  
            if !detailModel.inferring || !isBottomMessage {
                if detailModel.foldEnable && realContent.count > limitChar {
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
                            .padding(.vertical, 8)
                            Spacer()
                        }
                        .background(.clear)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                }
                
                MenuView(messageData: messageData)
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
        .padding(.leading, 5)
    }
 
    @ViewBuilder
    func markDownView(thinkContent: String, realContent: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            matchedTab(
                modelProvider: messageData.modelProvider
            )?.iconView() ?? Image("AppIconSidebar")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 25, height: 25)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.25), radius: 5, x: -1, y: 5)
            
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
                                        //.transition(.lineByLine(duration: 0.8))
                                        .animation(nil, value: parser.completedContent)
                                } else {
                                    TextView(parser.streamingContent)
                                        //.transition(.lineByLine(duration: 0.8))
                                        .animation(nil, value: parser.completedContent)
                                }
                                
                            }
                            .task(id: processedContent.content, priority: .background) {
                                parser.process(newContent: processedContent.content)
                            }
                        } else {
                            markDownContent(processedContent.content)
                        }
                    } else {
                        TextView(realContent)
                    }
                }
            }
            .task(id: realContent, priority: .high) {
                if !realContent.isEmpty {
                    processedContent = ContentProcessor.shared.preprocess(markdown: realContent)
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
                ForegroundColor(Color(.controlTextColor))
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
    func popView() -> some View {
        VStack {
            ScrollView {
                if showMardDown {
                    Markdown(messageData.content)
                    markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontWeight(fontWeight.actualWeight)
                        FontSize(fontSize)
                        ForegroundColor(Color(.controlTextColor))
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
        .frame(width: 500, height: 600)
        .padding()
    }
}
