//
//  SearchBarView.swift
//  InferX
//
//  Created by mingdw on 2025/5/21.
//

import SwiftUI

struct SearchBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var detailModel: ConversationDetailModel
    @FocusState private var isSearchFocused: Bool
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            TextField("Search...", text: $detailModel.searchText)
                .focused($isSearchFocused)
                //.task {
                //    isSearchFocused = false
                //}
                .textFieldStyle(.plain)
                .padding(.leading, 20)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? Color(.unemphasizedSelectedContentBackgroundColor).opacity(1) : Color(.unemphasizedSelectedContentBackgroundColor).opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: isHovering)
                .foregroundColor(Color(.controlTextColor))
                .accentColor(Color(.controlAccentColor))
                .onSubmit {
                    isSearchFocused = false
                    detailModel.scrollToBottomMessage.toggle()
                }
                .onExitCommand {
                    isSearchFocused = false
                    withAnimation(.easeInOut(duration: 0.5)) {
                        detailModel.isSearching = false
                    }
                }
                .onHover { isHovering = $0 }
                .overlay {
                    HStack {
                        Button(action: {
                            detailModel.scrollToBottomMessage.toggle()
                        }) {
                            Image(systemName: "magnifyingglass")
                                .contentShape(Rectangle())
                        }
                        .padding(2)
                        
                        Spacer()
                        
                        Button(action: {
                            detailModel.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle")
                                .contentShape(Rectangle())
                        }
                        .padding(2)
                    }
                    .foregroundColor(.primary)
                    .buttonStyle(.plain)
                }
        }
    }
}
