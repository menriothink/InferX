//
//  ContentView.swift
//  InferX
//
//  Created by mingdw on 2025/5/20.
//

import SwiftUI
import SwiftData
import Defaults

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SettingsModel.self) private var settingsModel
    
    @Query(sort: \Conversation.updatedAt, order: .reverse)
    private var conversations: [Conversation]
    
    @Query(sort: \ModelAPI.createdAt, order: .forward)
    private var modelAPIs: [ModelAPI]
    
    @Query(sort: \Model.createdAt, order: .reverse)
    private var localModels: [Model]
    
    @State private var modelManager = ModelManagerModel()
    @State private var conversationModel = ConversationModel()
        
    @Default(.modelDirectoryBookmark) private var modelDirectoryBookmark
    @Default(.proxyHost) var proxyHost
    @Default(.proxyPort) var proxyPort
    @Default(.proxyEnable) var proxyEnable
    @Default(.ignorHost) var ignorHost
    
    var body: some View {
        @Bindable var settingsModel = settingsModel
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                switch settingsModel.selectedItem {
                case .conversation:
                    ConversationView()
                case .modelAPIManager:
                    ModelAPIManagerView()
                }
            }
            .environment(conversationModel)
            .environment(modelManager)
            .frame(minWidth: 650, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
                withAnimation(.easeInOut(duration: 0.8)) {
                    settingsModel.sidebarState = .none
                }
            }
            .onChange(of: settingsModel.sidebarState) {
                if settingsModel.sidebarState == .left {
                    settingsModel.selectedItem = .conversation
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .foregroundColor(Color.primary)
        .font(.system(size: 13, weight: .regular, design: .rounded))
        .task {
            conversationModel.conversations = self.conversations
            conversationModel.modelContext = self.modelContext
            
            modelManager.modelAPIs = self.modelAPIs
            modelManager.activeModelAPI = modelManager.modelAPIs.first
            modelManager.modelContext = self.modelContext
            modelManager.localModels = Dictionary(grouping: self.localModels, by: { $0.apiName })
            
            if conversationModel.selectedConversation == nil {
                conversationModel.selectedConversation = conversationModel.conversations?.first
            }
            
            await OKHTTPClient.shared.setIgnorHost(ignorHost: self.ignorHost)
            if proxyEnable {
                await OKHTTPClient.shared.setProxy(
                    proxyHost: self.proxyHost,
                    proxyPort: UInt32(self.proxyPort)
                )
            } else {
                await OKHTTPClient.shared.setProxy()
            }
                       
            modelManager.resetAvailabilityAndCleanModels()
            
            await modelManager.updateAllModelsStatus()
        }
    }
}
