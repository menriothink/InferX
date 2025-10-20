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
        ZStack {
            Color.clear
                .background(DraggableArea())
            
            HStack {
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
                .padding(.leading, 80)
                
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
                
                Button {
                    toggleSettingsWindow()
                } label: {
                    Image(systemName: "gear")
                }
                .padding(.leading, 20)

                Spacer()
                                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        detailModel.scrollToTopMessage.toggle()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        detailModel.isSearching.toggle()
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                }
                .padding(.leading, 10)
                
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
                .padding(.trailing, 20)
                .padding(.leading, 10)
            }
        }
        .font(.title2)
        .buttonStyle(.plain)
        .padding(.top, 10)
        .frame(height: 30)
    }
    
    private func toggleSettingsWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "Settings" }) {
            if window.isKeyWindow {
                window.close()
            } else {
                openWindow(id: "Settings")
            }
        } else {
            openWindow(id: "Settings")
        }
    }
}
