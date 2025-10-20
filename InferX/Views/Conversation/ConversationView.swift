//
//  ConversationView.swift
//  InferX
//
//  Created by mingdw on 2025/4/13.
//

import SwiftUI
import SwiftData
import SwiftUIX

struct ConversationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(ModelManagerModel.self) var managerModel
    @Environment(SettingsModel.self) private var settingsModel
    
    @State private var showingAddTaskAlert = false
    
    var body: some View {
        VStack(alignment: .leading) {
            if let conversation = conversationModel.selectedConversation ??
                                    conversationModel.conversations?.first {
                ConversationDetail()
                    .id(conversation.id)
                    .environment(conversationModel.detailModel(for: conversation))
            } else {
                ConversationDefaultView {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        conversationModel.createConversation()
                    }
                }
            }
        }
    }
}
