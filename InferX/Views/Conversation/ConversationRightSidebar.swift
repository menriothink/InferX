//
//  RightSidebar.swift
//  InferX
//
//  Created by mingdw on 2025/5/13.
//

import SwiftUI

struct ConversationRightSidebar: View {
    @Environment(ConversationDetailModel.self) private var detailModel

    private let padding: CGFloat = 6

    private var conversationTitleBinding: Binding<String> {
        Binding {
            detailModel.conversation?.title ?? ""
        } set: { newValue in
            detailModel.conversation?.title = newValue
        }
    }

    private var conversationPromptBinding: Binding<String> {
        Binding {
            detailModel.conversation?.userPrompt ?? ""
        } set: { newValue in
            detailModel.conversation?.userPrompt = newValue
        }
    }

    private var conversationPromptEnableBinding: Binding<Bool> {
        Binding {
            detailModel.conversation?.userPromptEnable ?? false
        } set: { newValue in
            detailModel.conversation?.userPromptEnable = newValue
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
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Conversation Title") {
                TextField("Enter title", text: conversationTitleBinding)
                    .textFieldStyle(.plain)
                    .padding(padding)
            }
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

            GroupBox("System Prompt Content") {
                TextEditor(text: conversationPromptBinding)
                    .multilineTextAlignment(.leading)
                    .frame(maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .opacity(conversationPromptEnableBinding.wrappedValue ? 1 : 0.6)
                    .padding(padding)
            }
        }
        .padding()
        #if os(macOS)
        .frame(width: 300)
        #else
        .frame(maxWidth: .infinity)
        #endif
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            EffectView(.hudWindow, blendingMode: .behindWindow)
        }
        .scrollContentBackground(.hidden)
        .transition(.move(edge: .trailing))
        .onTapGesture {}
    }
    #else
    @ViewBuilder
    private var iOSContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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
}
