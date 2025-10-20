//
//  CopyDelete.swift
//  InferX
//
//  Created by mingdw on 2025/5/3.
//

import SwiftUI
import Defaults

struct MenuView: View {
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(ConversationDetailModel.self) private var detailModel
        
    let messageData: MessageData
    
    var body: some View {
        VStack(alignment: messageData.role == .user ? .trailing : .leading) {
            if let statics = messageData.chatStatics, messageData.role == .assistant {
                HStack(spacing: 10) {
                    if let fullName = messageData.fullName, !fullName.isEmpty {
                        VStack(alignment: .leading) {
                            Text("model")
                            Text(fullName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(fullName)
                        }
                    }
                    
                    if let promptEvalCount = statics.promptEvalCount {
                        VStack(alignment: .leading) {
                            Text("prompts")
                            Text("\(promptEvalCount)")
                        }
                    }
                    
                    if let promptEvalDuration = statics.promptEvalDuration {
                        VStack(alignment: .leading) {
                            Text("prompts duration")
                            Text("\(promptEvalDuration)s")
                        }
                    }
                    
                    if let evalCount = statics.evalCount {
                        VStack(alignment: .leading) {
                            Text("tokens")
                            Text("\(evalCount)")
                        }
                    }
                    
                    if let evalDuration = statics.evalDuration {
                        VStack(alignment: .leading) {
                            Text("tokens duration")
                            Text("\(evalDuration)s")
                        }
                    }
                    
                    if let tokensPerSecond = statics.tokensPerSecond {
                        VStack(alignment: .leading) {
                            Text("tokens per second")
                            Text("\(tokensPerSecond)")
                        }
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
        .padding(.leading, 25)
        .background(.clear)
    }
    
    private func copyText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(messageData.realContent, forType: .string)
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
