//
//  ConversationDetailModel.swift
//  InferX
//
//  Created by mingdw on 2025/4/13.
//

import SwiftUI
import SwiftData
import AlertToast
import Defaults

enum FetchFrom: Equatable {
    case top
    case bottom
    case starting(Date)
}

enum Direction {
    case up
    case down
    case none
}

@MainActor
@Observable
final class ConversationDetailModel {
    var conversation: Conversation?

    var currentVisableHeight: CGFloat?

    var searchText: String = ""
    var cacheContent = ""
    var isSearching = false

    var historyFilteredKeywords = ""

    var inferStopping = false
    var foldEnable = true
    var mardDownEnable = true

    var showToast = false
    var toastMessage = ""
    var toastType: AlertToast.AlertType = .regular

    var image: Image?

    var chatTask: Task<Void, Never>?

    var reLoadCurrentMessages = false
    var scrollToTopMessage = false
    var scrollToBottomMessage = false
    var topMessage: MessageData?
    var bottomMessage: MessageData?
    var visibleMessageIDs: [PersistentIdentifier?] = []
    var lastVisibleMessageID: PersistentIdentifier?

    let defaultMessages = 10
    var messagesPageSize: Int {
        get {
            if foldEnable || !mardDownEnable {
                return 50
            }
            return 10
        }
    }

    var messagesLoadSize: Int {
        get {
            if foldEnable || !mardDownEnable {
                return 10
            }
            return 5
        }
    }

    var messagesDropSize: Int {
        get {
            if foldEnable || !mardDownEnable {
                return 10
            }
            return 5
        }
    }

    var inferring: Bool = false {
        didSet {
            if inferring && !oldValue {
                startEscapeTime = Date()
            } else if !inferring && oldValue {
                startEscapeTime = nil
            }
        }
    }
    var startEscapeTime: Date?


    init(_ conversation: Conversation) {
        self.conversation = conversation
    }

    func updateMessage(_ messageData: MessageData?) async {
        do {
            try await SwiftDataProvider.share.messageService.updateMessage(messageData)
        } catch {
            print("updateMessage failed")
        }
    }

    func fetchTopBottomMessage(isBottom: Bool, searchKey: SearchKey) async -> MessageData? {
        guard let conversationID = self.conversation?.id else {
            print("fetchTopBottomMessage, service or conversation ID missed")
            return nil
        }

        do {
            if isBottom {
                guard self.bottomMessage == nil else {
                    return self.bottomMessage
                }
                return try await SwiftDataProvider.share.messageService.fetchBottomMessage(conversationID, searchKey)
            } else {
                guard self.topMessage == nil else {
                    return self.topMessage
                }
                return try await SwiftDataProvider.share.messageService.fetchTopMessage(conversationID, searchKey)
            }
        } catch {
            print("fetchTopMessages failed for conversation: \(conversationID)")
        }
        return nil
    }

    func fetchMessages(
        from fetchFrom: FetchFrom,
        to endingDate: Date? = nil,
        direction: Direction? = nil,
        numbers: Int,
        searchKey: SearchKey = SearchKey(c: "", d: "")
    ) async -> (MessageData?, MessageData?, [MessageData]?) {
        guard let conversationID = self.conversation?.id else {
            print("fetchMessages, service or conversation ID missed")
            return (nil, nil, nil)
        }

        do {
            async let earliestTask = Task {
                try await SwiftDataProvider.share.messageService.fetchTopMessage(conversationID, searchKey)
            }

            async let latestTask = Task {
                try await SwiftDataProvider.share.messageService.fetchBottomMessage(conversationID, searchKey)
            }

            async let fetchMessagesTask = Task {
                try await SwiftDataProvider.share.messageService.fetchMessages(
                    for: conversationID,
                    from: fetchFrom,
                    to: endingDate,
                    direction: direction,
                    numbers: numbers,
                    searchKey: searchKey
                )
            }

            let (topMessageData, bottomMessageData, messagesData) =
                        try await (earliestTask.value, latestTask.value, fetchMessagesTask.value)
            return (topMessageData, bottomMessageData, messagesData)
        } catch {
            print("fetchMessages failed for conversation: \(conversationID)")
        }
        return (nil, nil, nil)
    }

    func deleteAllMessages() async {
        guard let conversationID = self.conversation?.id else {
            print("deleteAllMessages, service or conversation ID missed")
            return
        }

        do {
            try await SwiftDataProvider.share.messageService.deleteAllMessages(from: conversationID)
        } catch {
            print("deleteAllMessages for \(conversationID) failed")
        }
    }

    func deleteMessage(_ messageID: UUID) async {
        do {
            try await SwiftDataProvider.share.messageService.deleteMessage(messageID)
        } catch {
            print("delete message failed")
        }
    }

    func fetchChatStaticForModel(
        from fetchFrom: Date,
        to endingDate: Date,
        modelName: String,
        modelAPIName: String,
        role: Role
    ) async -> (Int, Int, Int) {
        do {
            return try await SwiftDataProvider.share.messageService.fetchChatStaticForModel(
                start: fetchFrom,
                end: endingDate,
                modelName: modelName,
                modelAPIName: modelAPIName,
                roleRaw: role.rawValue
            )
        } catch {
            print("fetchChatStaticForModel failed for model: \(modelAPIName), \(modelName)")
            return (0, 0, 0)
        }
    }
}
