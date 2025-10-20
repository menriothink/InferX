//
//  SettingsSidebarView.swift
//  InferX
//
//  Created by mingdw on 2025/4/15.
//

import SwiftUI

struct ModelAPISidebar: View {
    @Environment(ModelManagerModel.self) var modelManager
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(SettingsModel.self) private var settingsModel
    
    @State var showAddModelSheet = false
    @State var showAddModelAPISheet = false
    
    let itemPadding: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading) {
            Group {
                Text("Settings")
                    .font(.title2)
                Text("model API settings")
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.5))
            }
            .padding(.horizontal, itemPadding)

            if !modelManager.modelAPIs.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(modelManager.modelAPIs) { modelAPI in
                            ModelAPISidebarItem(modelAPI: modelAPI)
                                .id(modelAPI.id)
                                .padding(.leading, 10)
                        }
                    }
                }
            }

            Spacer()
            
            UltraButtonView(
                fontSize: 12,
                text: "Add Conversation") {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        settingsModel.selectedItem = .conversation
                        conversationModel.createConversation()
                    }
                }
                .padding(10)
                .padding(.bottom, -10)
            
            UltraButtonView(
                fontSize: 12,
                text: "Add Model") {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showAddModelSheet = true
                    }
                }
                .sheet(isPresented: $showAddModelSheet) {
                    ModelAddSheetView()
                }
                .padding(10)
                .padding(.bottom, -10)
            
            UltraButtonView(
                fontSize: 12,
                text: "Add Model API") {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showAddModelAPISheet = true
                    }
                }
                .sheet(isPresented: $showAddModelAPISheet) {
                    ModelAPIAddSheetView()
                }
                .padding(10)
        }
        .padding(.trailing, -15)
    }
}
