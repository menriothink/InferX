//
//  ConversationModel.swift
//  InferX
//
//  Created by mingdw on 2025/4/12.
//

import SwiftUI
import SwiftData

@MainActor
@Observable
class ConversationModel: @unchecked Sendable {
    var conversationActive = false
    var selectedConversation: Conversation? {
        didSet {
            if let conversation = selectedConversation {
                _ = detailModel(for: conversation)
            }
        }
    }

    var filteredConversations: [Conversation] = []

    private var detailModels: [Conversation.ID : ConversationDetailModel] = [:]

    var includeMessageContent = false
    var searchText: String = ""
    var conversations: [Conversation]?
    var modelContext: ModelContext?

    var conversationChanged = false

    var error: Error?
    var errorTitle: String?
    var showErrorAlert = false

    func throwError(_ error: Error, title: String? = nil) {
        logger.error("\(error.localizedDescription)")
        self.error = error
        errorTitle = title
        showErrorAlert = true
    }

    func detailModel(for conversation: Conversation) -> ConversationDetailModel {
        if let existingModel = detailModels[conversation.id] {
            return existingModel
        } else {
            let newModel = ConversationDetailModel(conversation)
            detailModels[conversation.id] = newModel
            return newModel
        }
    }

    func createConversation() {
        let conversation = Conversation()
        modelContext?.insert(conversation)
        saveContextChanges()
        _ = detailModel(for: conversation)
        conversations?.insert(conversation, at: 0)
        selectedConversation = conversation
        conversationChanged.toggle()
    }

    func deleteConversation(conversation: Conversation) {
        detailModels.removeValue(forKey: conversation.id)
        conversations?.removeAll { $0.id == conversation.id }
        if selectedConversation == conversation {
            selectedConversation = conversations?.first
        }
        modelContext?.delete(conversation)
        saveContextChanges()
        conversationChanged.toggle()
    }

    func filteredConversations(_ keyword: String) -> [Conversation] {
        if keyword.isEmpty {
            return conversations ?? []
        } else {
            return conversations?.filter { conversation in
                conversation.title.localizedStandardContains(keyword)
            } ?? []
        }
    }

    func saveContextChanges() {
        if modelContext?.hasChanges ?? false {
            do {
                try modelContext?.save()
            } catch {
                timestampedLogger(
                    "swift data saveChanges failed",
                    level: .debug
                )
            }
        }
    }

    func filterConversationFromMessages(
        for conversations: [Conversation],
        _ searchKey: SearchKey
    ) async -> [Conversation] {
        var filteredConversations: [Conversation] = []
        guard !searchKey.c.isEmpty else {
            return filteredConversations
        }

        await withTaskGroup(of: (Bool, UUID).self) { group in
            for conversation in conversations {
                let conversationID = conversation.id
                group.addTask {
                    do {
                        if try await SwiftDataProvider.share.messageService.checkConversationFromMessages(
                            for: conversationID,
                            searchKey: searchKey
                        ) {
                            return (true, conversationID)
                        } else {
                            return (false, conversationID)
                        }
                    } catch {
                        timestampedLogger(
                            "filterConversationFromMessages failed for searchKey from conversation: \(searchKey), \(conversationID)",
                            level: .debug
                        )
                        return (false, conversationID)
                    }
                }
            }

            for await (chunkResult, conversationID) in group {
                if chunkResult {
                    let conversation = self.conversations?.first {
                        $0.id == conversationID
                    }

                    if let conversation {
                        filteredConversations.append(conversation)
                    }
                }
            }
        }

        return filteredConversations
    }
}
