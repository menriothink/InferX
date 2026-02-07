//
//  ConversationMessage.swift
//  InferX
//
//  Created by mingdw on 2025/4/4.
//

import SwiftUI

struct ConversationMessage: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ConversationDetailModel.self) private var detailModel

    let messageData: MessageData
    let isBottomMessage: Bool

    var body: some View {
        let horizontalPadding: CGFloat = {
            #if os(iOS)
            return 8
            #else
            return 20
            #endif
        }()
        let userLeadingPadding: CGFloat = {
            #if os(iOS)
            return 24
            #else
            return 50
            #endif
        }()
        let assistantTrailingPadding: CGFloat = {
            #if os(iOS)
            return 12
            #else
            return 20
            #endif
        }()

        HStack {
            if messageData.role == .user {
                Spacer()
            }

            if messageData.role == .assistant || messageData.role == .system {
                MessageWithMarkdown(messageData: messageData, isBottomMessage: isBottomMessage)
            } else {
                #if os(iOS)
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .trailing, spacing: 4) {
                        RenderMessageContent(messageData: messageData)
                    
                        MenuView(messageData: messageData)
                    }

                    Image("AppIconSidebar")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .shadow(color: .black.opacity(0.15), radius: 2, x: -1, y: 2)
                }
                #else
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .trailing, spacing: 8) {
                        RenderMessageContent(messageData: messageData)
                    
                        MenuView(messageData: messageData)
                            .padding(.top, -5)
                    }

                    Image("AppIconSidebar")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 25, height: 25)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .shadow(color: .black.opacity(0.25), radius: 5, x: -1, y: 5)
                }
                #endif
            }

            if messageData.role == .assistant || messageData.role == .system {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: messageData.role == .user ? .trailing : .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.leading, messageData.role == .user ? userLeadingPadding : 0)
        .padding(.trailing, messageData.role == .user ? 0 : assistantTrailingPadding)
        .lineSpacing(2)
        .textSelection(.enabled)
        .padding(.vertical, 20)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var bubbleBackgroundColor: Color {
        switch messageData.role {
        case .user:
            return colorScheme == .dark ? .gray.opacity(1) : .yellow.opacity(1)
        case .assistant, .system:
            return .clear
        }
    }

    private var bubbleTextColor: Color {
        switch messageData.role {
        case .user:
            return colorScheme == .dark ? Color.white : Color.black
        case .assistant, .system:
            return colorScheme == .dark ? Color.white : Color.black
        }
    }
}
