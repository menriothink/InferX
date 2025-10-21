//
//  ReduceMessagesView.swift
//  InferX
//
//  Created by mingdw on 2025/4/6.
//

import AlertToast
import MarkdownUI
import SwiftUI
import SwiftUIX
import Defaults

struct RenderMessageContent: View {
    @Environment(\.colorScheme) private var colorScheme

    let messageData: MessageData

    @State private var showPopover = false
    @State private var showMardDown = false

    @Default(.fontWeightBlack) var fontWeightBlack
    @Default(.fontWeightWhite) var fontWeightWhite
    @Default(.fontSizeBlack) var fontSizeBlack
    @Default(.fontSizeWhite) var fontSizeWhite
    @Default(.fontNameWhite) var fontNameWhite
    @Default(.fontNameBlack) var fontNameBlack
    @Default(.backgroundContentLightRadius) var backgroundContentLightRadius
    @Default(.backgroundContentDarkRadius) var backgroundContentDarkRadius

    @State private var isExpanded: Bool = false

    private let lineLimitThreshold = 500

    private var totalLineCount: Int {
        return messageData.content.count
    }

    private var needsTruncation: Bool {
        totalLineCount > lineLimitThreshold
    }

    private var currentLineLimit: Int {
        if needsTruncation && !isExpanded {
            return lineLimitThreshold
        }
        return totalLineCount
    }

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

    var body: some View {
        VStack(alignment: .trailing) {
            if !messageData.attachmentsData.isEmpty {
                VStack(spacing: 5) {
                    ForEach(Array(messageData.attachmentsData.keys), id: \.self) { attachmentId in
                        if let attachmentData = messageData.attachmentsData[attachmentId] {
                            MessageAttachmentView(
                                attachmentData: attachmentData
                            )
                        }
                    }
                }
                .padding(.bottom, 10)
            }

            Markdown(MarkdownContent(String(messageData.content.prefix(currentLineLimit))))
                .markdownTextStyle {
                    FontFamily(.custom(fontName))
                    FontWeight(fontWeight.actualWeight)
                    FontSize(fontSize)
                    ForegroundColor(Color(.controlTextColor))
                }
                .markdownTheme(MarkdownColours.enchantedThemeMedium)
                .markdownCodeSyntaxHighlighter(
                    CodeHighlighter(
                        colorScheme: colorScheme,
                        fontSize: fontSize - 3,
                        enabled: true
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.gray.opacity(0.05))
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        .padding(-5)
                )

            if needsTruncation {
                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    Text(isExpanded ? "Show Less" : "Show More...")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, -4)
            }

        }
        .onDisappear {
            if needsTruncation {
                isExpanded = false
            }
        }
    }
}
