//
//  RightSidebar.swift
//  InferX
//
//  Created by mingdw on 2025/5/13.
//

#if os(macOS)
import Luminare
#endif
import SwiftUI

struct ConversationRightSidebar: View {
    @Environment(ConversationDetailModel.self) private var detailModel
                
    private let padding: CGFloat = 6

    private var conversationTitleBinding: Binding<String> {
        Binding {
            detailModel.conversation?.title ?? ""
        } set: {
            detailModel.conversation?.title = $0
        }
    }
    
    private var conversationPromptBinding: Binding<String> {
        Binding {
            detailModel.conversation?.userPrompt ?? ""
        } set: {
            detailModel.conversation?.userPrompt = $0
        }
    }
    
    private var conversationPromptEnableBinding: Binding<Bool> {
        Binding {
            detailModel.conversation?.userPromptEnable ?? false
        } set: {
            detailModel.conversation?.userPromptEnable = $0
        }
    }

    var body: some View {
        #if os(macOS)
        macOSContent
        #else
        iOSContent
        #endif
    }
    
    #if os(macOS)
    @ViewBuilder
    private var macOSContent: some View {
        VStack(alignment: .leading) {
            LuminareSection("Conversation Title") {
                TextField("Enter title", text: conversationTitleBinding)
                    .textFieldStyle(.plain)
                    .padding(padding)
            }
            .padding(.bottom, 20)
            
            HStack {
                Text("System Prompt")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Toggle("", isOn: conversationPromptEnableBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, 4)
            
            LuminareSection("") {
                TextEditor(text: conversationPromptBinding)
                    .multilineTextAlignment(.leading)
                    .frame(maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .opacity(conversationPromptEnableBinding.wrappedValue ? 1 : 0.6)
            }
            .layoutPriority(1)
            .disabled(!conversationPromptEnableBinding.wrappedValue)
        }
        .padding()
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .behindWindow,
                state: .active
            )
        }
        .scrollContentBackground(.hidden)
        .transition(.move(edge: .trailing))
        .onTapGesture {}
    }
    #else
    @ViewBuilder
    private var iOSContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Conversation Title Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Conversation Title")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Enter title", text: conversationTitleBinding)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // System Prompt Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("System Prompt")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Toggle("", isOn: conversationPromptEnableBinding)
                        .labelsHidden()
                }
                
                TextEditor(text: conversationPromptBinding)
                    .frame(height: 150)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .opacity(conversationPromptEnableBinding.wrappedValue ? 1 : 0.6)
                    .disabled(!conversationPromptEnableBinding.wrappedValue)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
    #endif
