//
//  Untitled.swift
//  InferX
//
//  Created by mingdw on 2025/4/5.
//

import SwiftUI

struct ConverSationHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ModelManagerModel.self) var modelManager
    @Environment(SettingsModel.self) private var settingsModel
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(ConversationDetailModel.self) private var detailModel
    @Environment(\.openWindow) private var openWindow
        
    var body: some View {
        let headerHeight: CGFloat = {
            #if os(iOS)
            return 44
            #else
            return 30
            #endif
        }()
        let headerFont: Font = {
            #if os(iOS)
            return .title3
            #else
            return .title2
            #endif
        }()
        let leadingPadding: CGFloat = {
            #if os(iOS)
            return 12
            #else
            return 80
            #endif
        }()
        let trailingPadding: CGFloat = {
            #if os(iOS)
            return 12
            #else
            return 20
            #endif
        }()

        ZStack {
            #if os(macOS)
            Color.clear
                .background(DraggableArea())
            #else
            Color.clear
            #endif
            
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        if settingsModel.sidebarState == .left {
                            settingsModel.sidebarState = .none
                        } else {
                            settingsModel.sidebarState = .left
                        }
                    }
                }) {
                    Image(systemName: "arrow.uturn.backward.circle.badge.ellipsis")
                }
                .padding(.leading, leadingPadding)
                .contentShape(Rectangle())
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        settingsModel.selectedItem = .modelAPIManager
                        modelManager.selectedItem = .modelAPIDetail
                        if modelManager.activeModelAPI == nil {
                            modelManager.activeModelAPI = modelManager.modelAPIs.first
                        }
                    }
                }) {
                    Image(systemName: "book.and.wrench")
                }
                .padding(.leading, 10)
                .contentShape(Rectangle())
                
                #if os(macOS)
                Button {
                    toggleSettingsWindow()
                } label: {
                    Image(systemName: "gear")
                }
                .padding(.leading, 20)
                .contentShape(Rectangle())
                #endif

                Spacer()
                                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        detailModel.scrollToTopMessage.toggle()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.body)
                }
                .contentShape(Rectangle())
                .frame(height: headerHeight)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        detailModel.isSearching.toggle()
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                }
                .padding(.leading, 10)
                .contentShape(Rectangle())
                
                Button(action: conversationModel.createConversation) {
                    Image(systemName: "bubble.and.pencil")
                }
                .padding(.leading, 10)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        if settingsModel.sidebarState == .right {
                            settingsModel.sidebarState = .none
                        } else {
                            settingsModel.sidebarState = .right
                        }
                    }
                }) {
                    Image(systemName: "slider.horizontal.3")
                }
                .padding(.trailing, trailingPadding)
                .padding(.leading, 10)
                .contentShape(Rectangle())
            }
        }
        .font(headerFont)
        .zIndex(2)
        .buttonStyle(.plain)
        #if os(iOS)
        .padding(.vertical, 6)
        #else
        .padding(.top, 10)
        #endif
        .frame(height: headerHeight)
    }
    
    private func toggleSettingsWindow() {
        #if os(macOS)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "Settings" }) {
            if window.isKeyWindow {
                window.close()
            } else {
                openWindow(id: "Settings")
            }
        } else {
            openWindow(id: "Settings")
        }
        #endif
    }
}
