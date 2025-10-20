//
//  ConversationDefaultView.swift
//  InferX
//
//  Created by mingdw on 2025/10/9.
//

import SwiftUI

struct ConversationDefaultView: View {
    @Environment(ModelManagerModel.self) var managerModel
    @Environment(SettingsModel.self) private var settingsModel
    
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "bubble.middle.bottom.fill")
                .font(.system(size: 70))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 10) {
                Text("Start your first conversation")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Click the button below to create your first chat session.\nStart exploring the endless possibilities of AI.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            VStack(spacing: 25) {
                
                Button(action: onCreate) {
                    Label("Create new chat", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
            
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        settingsModel.selectedItem = .modelAPIManager
                        managerModel.selectedItem = .modelAPIDetail
                        managerModel.activeModelAPI = managerModel.modelAPIs.first
                    }
                }) {
                    Label("API Settings", systemImage: "gearshape.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(width: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

