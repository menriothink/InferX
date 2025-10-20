//
//  ConversationSidebar.swift
//  InferX
//
//  Created by mingdw on 2025/4/13.
//

import Defaults
import Luminare
import SwiftUI
import SwiftData

struct ConversationSidebar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ConversationModel.self) private var conversationModel

    @State private var showingFiletedConversation = false
    @State private var isHovering = false
    
    let rowHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(alignment: .bottom) {
                @Bindable var conversationModel = conversationModel
                UltramanTextField(
                        $conversationModel.searchText,
                        placeholder: Text("Search Conversation..."),
                        onSubmit: {
                            filteredConversations(conversationModel.searchText)
                        }
                )
                .onHover { isHovering = $0 }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHovering ? Color(.unemphasizedSelectedContentBackgroundColor).opacity(1) : Color(.unemphasizedSelectedContentBackgroundColor).opacity(0.4))
                )
                .animation(.easeInOut(duration: 0.2), value: isHovering)
                .foregroundColor(Color(.controlTextColor))
                .accentColor(Color(.controlAccentColor))
                
                Toggle(isOn: $conversationModel.includeMessageContent) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .help("Include message content when searching")
            }
            .frame(height: 20)
            .padding(.vertical, 20)
            .padding(.leading, 5)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(conversationModel.filteredConversations) { conversation in
                        ConversationSidebarItem(conversation: conversation)
                            .padding(.horizontal, 5)
                    }
                }
            }
            .task(id: conversationModel.conversationChanged) {
                if conversationModel.searchText.isEmpty {
                    loadConversations(conversationModel.searchText)
                }
            }
            .overlay {
                if showingFiletedConversation {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            
            UltraButtonView(
                fontSize: 12,
                text: "Create a new session") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        conversationModel.createConversation()
                    }
                }
                .frame(width: 180)
                .padding(10)
                .padding(.top, 20)
            
            Spacer()
        }
        .padding(.top, 20)
        .frame(width: 200)
        .transition(.move(edge: .leading))
        .scrollContentBackground(.hidden)
        .background {
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .behindWindow,
                state: .active
            )
        }
        .onTapGesture{}
    }
    
    private func filteredConversations(_ keyword: String) {
        if showingFiletedConversation { return }
        showingFiletedConversation = true
        conversationModel.filteredConversations = conversationModel.filteredConversations(keyword)
        conversationModel.filteredConversations.sort { $0.updatedAt > $1.updatedAt }
        
        if conversationModel.includeMessageContent, let snapshot = conversationModel.conversations {
            Task {
                let existingIDs = Set(conversationModel.filteredConversations.map(\.id))
                let newConversations = snapshot.filter { !existingIDs.contains($0.id) }
                let filteredConversations = await conversationModel.filterConversationFromMessages(for: newConversations, SearchKey(c: keyword, d: ""))
                if !filteredConversations.isEmpty {
                    conversationModel.filteredConversations.append(contentsOf: filteredConversations)
                    conversationModel.filteredConversations.sort { $0.updatedAt > $1.updatedAt }
                    if let selectedConversation = conversationModel.selectedConversation {
                        conversationModel.detailModel(for: selectedConversation).scrollToBottomMessage.toggle()
                    }
                }
                showingFiletedConversation = false
            }
        } else {
            showingFiletedConversation = false
        }
    }
    
    private func loadConversations(_ keyword: String) {
        if showingFiletedConversation { return }
        showingFiletedConversation = true
        conversationModel.filteredConversations = conversationModel.filteredConversations(keyword)
        conversationModel.filteredConversations.sort { $0.updatedAt > $1.updatedAt }
        showingFiletedConversation = false
    }
}
