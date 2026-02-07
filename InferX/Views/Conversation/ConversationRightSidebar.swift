//
//  RightSidebar.swift
//  InferX
//
//  Created by mingdw on 2025/5/13.
//

import SwiftUI

struct ConversationRightSidebar: View {
    @Environment(ConversationDetailModel.self) private var detailModel
    #if os(iOS)
    @Environment(SettingsModel.self) private var settingsModel
    #endif

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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerBar

                VStack(alignment: .leading, spacing: 8) {
                    Text("Conversation Title")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("Enter title", text: conversationTitleBinding)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text("System Prompt")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Toggle("", isOn: conversationPromptEnableBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    TextEditor(text: conversationPromptBinding)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .opacity(conversationPromptEnableBinding.wrappedValue ? 1 : 0.6)
                        .disabled(!conversationPromptEnableBinding.wrappedValue)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(12)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    settingsModel.sidebarState = .none
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 40, height: 5)

            Spacer()

            Color.clear
                .frame(width: 28, height: 28)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 25)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard abs(horizontal) > vertical else { return }
                    if horizontal > 50 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            settingsModel.sidebarState = .none
                        }
                    }
                }
        )
    }
    #endif
}
