import SwiftUI
import SwiftData

struct ConversationSidebarItem: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ConversationModel.self) private var conversationModel

    let conversation: Conversation

    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false
    @State private var showingDeleteTaskAlert = false

    var body: some View {
        VStack(alignment: .leading) {
            Text(conversation.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .help(conversation.title)
            
            HStack {
                Text(conversation.updatedAt.toFormatted(style: .short))
                    .lineLimit(1)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                
                Text(conversation.createdAt.toFormatted(style: .short))
                    .lineLimit(1)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            if isActive || isHovering {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive || isHovering ? Color.gray.opacity(0.2) : Color.clear)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            if let oldConversation = conversationModel.selectedConversation,
               oldConversation != conversation {
                conversationModel.detailModel(for: oldConversation).foldEnable = true
            }
            conversationModel.selectedConversation = conversation
            //conversationModel.conversationActive.toggle()
        }
        .onHover { hovering in
            isHovering = hovering
        }
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
        .animation(.easeOut(duration: 0.2), value: isActive || isHovering)
        .onAppear {
            checkIfSelfIsActiveTab()
        }
        .onChange(of: conversationModel.selectedConversation) { _, _ in
            checkIfSelfIsActiveTab()
        }
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
