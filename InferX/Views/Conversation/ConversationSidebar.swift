//
//  ConversationSidebar.swift
//  InferX
//
//  Created by mingdw on 2025/4/13.
//

import Defaults
import SwiftUI
import SwiftData

struct ConversationSidebar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ConversationModel.self) private var conversationModel

    @State private var showingFiletedConversation = false
    @State private var isHovering = false
    
    let rowHeight: CGFloat = 40

    var body: some View {
        contentStack
            .modifier(SidebarLayout())
    }
    
    private struct SidebarLayout: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(.top, 20)
                .frame(width: 200)
        }
    }
    
    private var contentStack: some View {
        ZStack {
            backgroundView
            mainContent
        }
    }
    
    private var mainContent: some View {
        VStack(alignment: .trailing, spacing: 0) {
            topSection
            conversationListView
            createSessionButton
            Spacer()
        }
    }
    
    private var topSection: some View {
        searchBarView
            .frame(height: 20)
            .padding(.vertical, 20)
            .padding(.leading, 5)
    }
    
    private var conversationListView: some View {
        scrollViewContent
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
    }
    
    private var scrollViewContent: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(conversationModel.filteredConversations) { conversation in
                    ConversationSidebarItem(conversation: conversation)
                        .padding(.horizontal, 5)
                }
            }
        }
    }
    
    private var createSessionButton: some View {
        buttonContent
            .frame(width: 180)
            .padding(10)
            .padding(.top, 20)
    }
    
    private var buttonContent: some View {
        UltraButtonView(
            fontSize: 12,
            text: "Create a new session") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    conversationModel.createConversation()
                }
            }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
#if os(macOS)
        EffectView(
            .hudWindow,
            blendingMode: .behindWindow,
            emphasized: true
        )
#else
        EffectView(
            .systemMaterial,
            emphasized: true
        )
#endif
    }
    
    private var searchBarView: some View {
        HStack(alignment: .bottom) {
            textFieldView
            toggleView
        }
    }
    
    private var textFieldView: some View {
        searchTextField(for: conversationModel)
    }
    
    private var toggleView: some View {
        searchToggle(for: conversationModel)
    }
    
    private func searchTextField(for model: ConversationModel) -> some View {
        @Bindable var conversationModel = model
        
        let textField = UltramanTextField(
            $conversationModel.searchText,
            placeholder: Text("Search Conversation..."),
            onSubmit: {
                filteredConversations(conversationModel.searchText)
            }
        )
        .onHover { isHovering = $0 }
        
#if os(macOS)
        return textField
            .background(RoundedRectangle(cornerRadius: 12).fill(isHovering ? Color(.unemphasizedSelectedContentBackgroundColor).opacity(1) : Color(.unemphasizedSelectedContentBackgroundColor).opacity(0.4)))
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .foregroundColor(Color(.controlTextColor))
            .accentColor(Color(.controlAccentColor))
#else
        return textField
            .background(RoundedRectangle(cornerRadius: 12).fill(isHovering ? Color(.systemGray6).opacity(1) : Color(.systemGray6).opacity(0.4)))
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .foregroundColor(Color.primary)
            .accentColor(Color.accentColor)
#endif
    }
    
    private func searchToggle(for model: ConversationModel) -> some View {
        @Bindable var conversationModel = model
        
        return Toggle(isOn: $conversationModel.includeMessageContent) {
            EmptyView()
        }
#if os(macOS)
        .toggleStyle(.checkbox)
#else
        .toggleStyle(.switch)
#endif
        .help("Include message content when searching")
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
