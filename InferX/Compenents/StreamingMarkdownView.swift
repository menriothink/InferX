//
//  StreamingMarkdownView.swift
//  InferX
//
//  Created by mingdw on 2025/6/15.
//

import SwiftUI
import MarkdownUI
import Defaults
import Splash

struct StreamingMarkdownView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @Default(.fontWeightBlack) var fontWeightBlack
    @Default(.fontWeightWhite) var fontWeightWhite
    @Default(.fontSizeBlack) var fontSizeBlack
    @Default(.fontSizeWhite) var fontSizeWhite
        
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
    
    private var codeHighlightColorScheme: Splash.Theme {
        switch colorScheme {
        case .dark:
            return .darkTheme
        default:
            return .sundellsColors
        }
    }
    
    let sourceText: String
    let characterDelay: TimeInterval

    @State private var displayedText: String = ""
    @State private var proxy: ScrollViewProxy? = nil
    
    private let bottomID = UUID()

    init(sourceText: String, characterDelay: TimeInterval = 0.008) {
        self.sourceText = sourceText
        self.characterDelay = characterDelay
    }

    var body: some View {
        ScrollViewReader { proxy in
            Markdown(displayedText)
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontWeight(fontWeight.actualWeight)
                    FontSize(fontSize)
                    ForegroundColor(.primary)
                }
                .markdownTheme(MarkdownColours.enchantedThemeMedium)
                .markdownCodeSyntaxHighlighter(.splash(theme: codeHighlightColorScheme))
        }
        .onAppear {
            self.proxy = proxy
            startStreaming()
        }
        .onChange(of: sourceText) { _, newText in
            resetAndStream()
        }
    }

    private func startStreaming() {
        Task {
            for char in sourceText {
                displayedText.append(char)
                try await Task.sleep(for: .seconds(characterDelay))
            }
        }
    }
    
    private func resetAndStream() {
        displayedText = ""
        startStreaming()
    }
    
    private func scrollToBottom() {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy?.scrollTo(bottomID, anchor: .bottom)
        }
    }
}
