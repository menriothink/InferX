import SwiftUI
import SwiftData

struct ConversationSidebarItem: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ConversationModel.self) private var conversationModel
    #if os(iOS)
    @Environment(SettingsModel.self) private var settingsModel
    #endif

    let conversation: Conversation

    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false
    @State private var showingDeleteTaskAlert = false

    var body: some View {
        VStack(alignment: .leading) {
            Text(conversation.title)
                #if os(iOS)
                .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                #else
                .font(.system(size: 12))
                #endif
                .lineLimit(1)
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .help(conversation.title)
            
            HStack {
                Text(conversation.updatedAt.toFormatted(style: .short))
                    .lineLimit(1)
                    #if os(iOS)
                    .font(.system(size: 11))
                    #else
                    .font(.system(size: 8))
                    #endif
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                
                Text(conversation.createdAt.toFormatted(style: .short))
                    .lineLimit(1)
                    #if os(iOS)
                    .font(.system(size: 11))
                    #else
                    .font(.system(size: 8))
                    #endif
                    .foregroundColor(.secondary)
            }
        }
        #if os(iOS)
        .frame(height: 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        #else
        .frame(height: 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            if isActive || isHovering {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
        #endif
        .clipShape(.rect(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            selectConversation()
        }
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
        .contextMenu {
            Button(role: .destructive, action: { showingDeleteTaskAlert = true }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteTaskAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteConversation)
        } message: {
            Text("Are you sure you want to delete conversation \(conversation.title)?")
        }
        .animation(.easeOut(duration: 0.2), value: isActive)
        #if os(macOS)
        .animation(.easeOut(duration: 0.2), value: isHovering)
        #endif
        .onAppear {
            checkIfSelfIsActiveTab()
        }
        .onChange(of: conversationModel.selectedConversation) { _, _ in
            checkIfSelfIsActiveTab()
        }
    }
    
    private func selectConversation() {
        if let oldConversation = conversationModel.selectedConversation,
           oldConversation != conversation {
            conversationModel.detailModel(for: oldConversation).foldEnable = true
        }
        conversationModel.selectedConversation = conversation
        
        // iOS: 选择后自动关闭侧边栏
        #if os(iOS)
        withAnimation(.easeInOut(duration: 0.3)) {
            settingsModel.sidebarState = .none
        }
        #endif
    }

    private func checkIfSelfIsActiveTab() {
        isActive = conversationModel.selectedConversation == conversation
    }
    
    private func deleteConversation() {
        let conversation = self.conversation
        Task {
            await conversationModel.detailModel(for: conversation).deleteAllMessages()
            conversationModel.deleteConversation(conversation: conversation)
        }
    }
}
