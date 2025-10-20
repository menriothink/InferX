//
//  ModelAPIDefaultView.swift
//  InferX
//
//  Created by mingdw on 2025/10/9.
//

import SwiftUI

struct ModelAPIDefaultView: View {
    @Environment(SettingsModel.self) private var settingsModel
    @Environment(ConversationModel.self) private var conversationModel
    
    @State private var addAPISheet: Bool = false
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "key.icloud.fill")
                .font(.system(size: 70))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 10) {
                Text("Configure your first API")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Connecting to a local or cloud model requires adding an API configuration first.\nLet's start here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            VStack(spacing: 25) {
                Button(action: {
                    addAPISheet = true
                }) {
                    Label("Add API Configuration", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        settingsModel.selectedItem = .conversation
                        conversationModel.selectedConversation = conversationModel.conversations?.first
                    }
                }) {
                    Label("Back to Conversation", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(width: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $addAPISheet) {
            ModelAPIAddSheetView()
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(Color.accentColor)
            .background(Color.clear)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

