//
//  ConversationSidebar.swift
//  InferX
//
//  Created by mingdw on 2025/4/13.
//

import Defaults
import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ConversationSidebar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ConversationModel.self) private var conversationModel

    @State private var showingFiletedConversation = false
    @State private var isHovering = false
    
    let rowHeight: CGFloat = 40
    private let searchBarHeight: CGFloat = {
        #if os(iOS)
        return 36
        #else
        return 20
        #endif
    }()
    private let sidebarTopPadding: CGFloat = {
        #if os(iOS)
        return 8
        #else
        return 20
        #endif
    }()
    private let topSectionVerticalPadding: CGFloat = {
        #if os(iOS)
        return 12
        #else
        return 20
        #endif
    }()

    var body: some View {
        contentStack
            .padding(.top, sidebarTopPadding)
            #if os(macOS)
            .frame(width: 200)
            #else
            .frame(maxWidth: .infinity)
            #endif
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
        VStack(alignment: .leading, spacing: 6) {
            searchBarView
                .frame(height: searchBarHeight)
            searchScopeHintView
        }
        .padding(.vertical, topSectionVerticalPadding)
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
        #if os(iOS)
        List {
            ForEach(conversationModel.filteredConversations) { conversation in
                ConversationSidebarItem(conversation: conversation)
                    .listRowInsets(EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await conversationModel.detailModel(for: conversation).deleteAllMessages()
                                conversationModel.deleteConversation(conversation: conversation)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            // 置顶：更新 updatedAt 让它排到最前面
                            conversation.updatedAt = Date()
                            loadConversations(conversationModel.searchText)
                        } label: {
                            Label("Pin", systemImage: "pin")
                        }
                        .tint(.orange)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        #else
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(conversationModel.filteredConversations) { conversation in
                    ConversationSidebarItem(conversation: conversation)
                        .padding(.horizontal, 5)
                }
            }
        }
        #endif
    }
    
    private var createSessionButton: some View {
        buttonContent
            #if os(macOS)
            .frame(width: 180)
            #else
            .frame(maxWidth: .infinity)
            #endif
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
        HStack(alignment: .center, spacing: 8) {
            textFieldView
            toggleView
        }
    }
    
    private var textFieldView: some View {
        searchTextField(for: conversationModel)
            .frame(maxWidth: .infinity)
    }
    
    private var toggleView: some View {
        searchToggle(for: conversationModel)
            .fixedSize()
    }

    private var searchScopeHintView: some View {
        HStack(spacing: 6) {
            Image(systemName: conversationModel.includeMessageContent ? "globe" : "list.bullet")
            Text(
                conversationModel.includeMessageContent
                    ? "Search all sessions (including messages)"
                    : "Search session list only"
            )
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.leading, 6)
        .lineLimit(2)
        .accessibilityLabel(
            conversationModel.includeMessageContent
                ? Text("Search all sessions (including messages)")
                : Text("Search session list only")
        )
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
            .background(RoundedRectangle(cornerRadius: 12).fill(isHovering ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(1) : Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.4)))
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .foregroundColor(Color(nsColor: .controlTextColor))
            .accentColor(Color(nsColor: .controlAccentColor))
#else
        return textField
            .background(RoundedRectangle(cornerRadius: 12).fill(isHovering ? Color(uiColor: .systemGray6).opacity(1) : Color(uiColor: .systemGray6).opacity(0.4)))
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .foregroundColor(Color.primary)
            .accentColor(Color.accentColor)
#endif
    }
    
    private func searchToggle(for model: ConversationModel) -> some View {
        @Bindable var conversationModel = model
        
        return Toggle(isOn: $conversationModel.includeMessageContent) {
            Text("Global")
                .font(.caption2)
        }
#if os(macOS)
        .toggleStyle(.checkbox)
        .controlSize(.small)
#else
        .toggleStyle(.switch)
#endif
        .help("Include message content when searching")
        .onChange(of: conversationModel.includeMessageContent) { _ in
            filteredConversations(conversationModel.searchText)
        }
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
