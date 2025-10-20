//
//  RightSidebar.swift
//  InferX
//
//  Created by mingdw on 2025/5/13.
//

import Luminare
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
                if conversationPromptEnableBinding.wrappedValue {
                    TextEditor(text: conversationPromptBinding)
                        .multilineTextAlignment(.leading)
                        .frame(maxHeight: .infinity)
                        .scrollContentBackground(.hidden)
                }
            }
            .layoutPriority(1)
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
}
