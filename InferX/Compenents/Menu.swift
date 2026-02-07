//
//  CopyDelete.swift
//  InferX
//
//  Created by mingdw on 2025/5/3.
//

import SwiftUI
import Defaults
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct MenuView: View {
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(ConversationDetailModel.self) private var detailModel
        
    let messageData: MessageData
    
    var body: some View {
        #if os(iOS)
        iosMenuView
        #else
        macOSMenuView
        #endif
    }
    
    // MARK: - iOS Layout
    #if os(iOS)
    @State private var showStats = false
    
    private var isUser: Bool { messageData.role == .user }
    
    private var iosMenuView: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            // Stats (collapsible on iOS, assistant only)
            if let statics = messageData.chatStatics, !isUser {
                if showStats {
                    iosStatsView(statics: statics)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            
            // Action buttons
            HStack(spacing: 10) {
                Button(action: copyText) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: deleteMessage) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                if !isUser, messageData.chatStatics != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStats.toggle()
                        }
                    } label: {
                        Image(systemName: showStats ? "chart.bar.fill" : "chart.bar")
                            .font(.system(size: 13))
                            .foregroundStyle(showStats ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Timestamp
            Text(messageData.createdAt.toFullFormattedWithMilliseconds())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private func iosStatsView(statics: ChatStatics) -> some View {
        let items: [(String, String)] = [
            messageData.fullName.map { ("Model", $0) },
            statics.promptEvalCount.map { ("Prompts", "\($0)") },
            statics.evalCount.map { ("Tokens", "\($0)") },
            statics.tokensPerSecond.map { ("Speed", String(format: "%.1f t/s", $0)) },
        ].compactMap { $0 }

        // Original iOS layout
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider().frame(height: 20).padding(.horizontal, 8)
                }
                VStack(spacing: 2) {
                    Text(item.0)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(item.1)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    #endif
    
    // MARK: - macOS Layout
    private var macOSMenuView: some View {
        VStack(alignment: messageData.role == .user ? .trailing : .leading) {
            if let statics = messageData.chatStatics, messageData.role == .assistant {
                VStack(alignment: .leading, spacing: 6) {
                    // First line: model name (can be very long)
                    if let fullName = messageData.fullName, !fullName.isEmpty {
                        Text(fullName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(fullName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Second line: token / speed stats
                    HStack(spacing: 12) {
                        if let promptEvalCount = statics.promptEvalCount {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("prompts")
                                    .lineLimit(1)
                                Text("\(promptEvalCount)")
                                    .lineLimit(1)
                            }
                        }
                        
                        if let promptEvalDuration = statics.promptEvalDuration {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("prompts duration")
                                    .lineLimit(1)
                                Text("\(promptEvalDuration)s")
                                    .lineLimit(1)
                            }
                        }
                        
                        if let evalCount = statics.evalCount {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("tokens")
                                    .lineLimit(1)
                                Text("\(evalCount)")
                                    .lineLimit(1)
                            }
                        }
                        
                        if let evalDuration = statics.evalDuration {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("tokens duration")
                                    .lineLimit(1)
                                Text("\(evalDuration)s")
                                    .lineLimit(1)
                            }
                        }
                        
                        if let tokensPerSecond = statics.tokensPerSecond {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("tokens per second")
                                    .lineLimit(1)
                                Text("\(tokensPerSecond)")
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
            }
            
            HStack(spacing: 10) {
                Button(action: copyText) {
                    Image(systemName: "doc.on.doc")
                        .help("Copy")
                }
                
                Button(action: deleteMessage) {
                    Image(systemName: "delete.left")
                        .help("Delete")
                }
            }
            .buttonStyle(ToolbarIconButtonStyle())
            
            Text(messageData.createdAt.toFullFormattedWithMilliseconds())
                .font(.caption)
                .padding(.top, 2)
        }
        .background(.clear)
    }
    
    private func copyText() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(messageData.realContent, forType: .string)
        #else
        UIPasteboard.general.string = messageData.realContent
        #endif
        detailModel.toastMessage = "Message is copied"
        detailModel.showToast.toggle()
    }
    
    private func deleteMessage() {
        Task {
            await detailModel.deleteMessage(messageData.id)
            detailModel.reLoadCurrentMessages.toggle()
            detailModel.toastMessage = "Message is deleted"
            detailModel.showToast.toggle()
        }
    }
}
