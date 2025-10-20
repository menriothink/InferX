import Foundation
import SwiftData

enum MessageFetchError: Error {
    case missingMessageDateRange
    case missingMessageStartDate
    case missingMessageEndDate
    case missingFetchDirection
}

//This service is only for Message model.
@ModelActor
final actor MessageService {
    func checkConversationFromMessages(
        for conversationID: UUID,
        searchKey: SearchKey
    ) throws -> Bool {
        let searchKeyC = searchKey.c
        let searchKeyD = searchKey.d
        let isSearchKeyCEmpty = searchKey.c.isEmpty
        let isSearchKeyDEmpty = searchKey.d.isEmpty

        var fetchDescriptor = FetchDescriptor<Message>(
            predicate: #Predicate<Message> { message in
                (!message.thinkContent.isEmpty || !message.realContent.isEmpty) &&
                message.conversationID == conversationID &&
                (isSearchKeyCEmpty || message.realContent.localizedStandardContains(searchKeyC)) &&
                (isSearchKeyDEmpty || message.realContent.localizedStandardContains(searchKeyD))
            },
            sortBy: [SortDescriptor(\Message.createdAt, order: .forward)]
        )
        fetchDescriptor.fetchLimit = 1

        let messages = try modelContext.fetch(fetchDescriptor)

        //timestampedLogger("fetchMessages called after fetch messages count: \(messages.count), Thread: \(Thread.isMainThread ? "Main Thread" : "Background Thread")", level: .debug)

        return !messages.isEmpty
    }

    func deleteAllMessages(from conversationID: UUID) throws {
        let predicate = #Predicate<Message>{ $0.conversationID == conversationID }
        try modelContext.delete(model: Message.self, where: predicate)
        try modelContext.saveChanges()
    }

    func deleteMessage(_ messageID: UUID) throws {
        let predicate = #Predicate<Message>{ $0.id == messageID}
        try modelContext.delete(model: Message.self, where: predicate)
        try modelContext.saveChanges()
    }

    func updateMessage(_ messageData: MessageData?) throws {
        if let messageData = messageData {
            let messageID = messageData.id
            let predicate = #Predicate<Message> { $0.id == messageID }
            var descriptor = FetchDescriptor<Message>(predicate: predicate)
            descriptor.fetchLimit = 1
            if let message = try modelContext.fetch(descriptor).first {
                messageData.saveToMessage(to: message)
                try modelContext.saveChanges()
            }
        }
    }

    func updateMessage() throws {
        try modelContext.saveChanges()
    }

    func createMessage(_ messageData: MessageData) throws {
        let message = Message()
        messageData.saveToMessage(to: message)
        self.modelContext.insert(message)
        try modelContext.saveChanges()
    }

    func fetchTopMessage(_ conversationID: UUID, _ searchKey: SearchKey) throws -> MessageData? {
        let searchKeyC = searchKey.c
        let searchKeyD = searchKey.d
        let isSearchKeyCEmpty = searchKey.c.isEmpty
        let isSearchKeyDEmpty = searchKey.d.isEmpty

        var predicate: Predicate<Message>
        predicate = #Predicate<Message> { message in
            message.conversationID == conversationID &&
            (isSearchKeyCEmpty || message.realContent.localizedStandardContains(searchKeyC)) &&
            (isSearchKeyDEmpty || message.realContent.localizedStandardContains(searchKeyD))
        }
        var fetchDescriptor = FetchDescriptor<Message>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Message.createdAt, order: .forward)]
        )
        fetchDescriptor.fetchLimit = 1

        let messages = try modelContext.fetch(fetchDescriptor)
        if let message = messages.first {
            return MessageData(from: message)
        }
        return nil
    }

    func fetchBottomMessage(_ conversationID: UUID, _ searchKey: SearchKey) throws -> MessageData? {
        let searchKeyC = searchKey.c
        let searchKeyD = searchKey.d
        let isSearchKeyCEmpty = searchKey.c.isEmpty
        let isSearchKeyDEmpty = searchKey.d.isEmpty

        //timestampedLogger("fetchBottomMessage called enter", level: .debug)

        var predicate: Predicate<Message>
        predicate = #Predicate<Message> { message in
            message.conversationID == conversationID &&
            //(!message.thinkContent.isEmpty || !message.realContent.isEmpty) &&
            (isSearchKeyCEmpty || message.realContent.localizedStandardContains(searchKeyC)) &&
            (isSearchKeyDEmpty || message.realContent.localizedStandardContains(searchKeyD))
        }
        var fetchDescriptor = FetchDescriptor<Message>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Message.createdAt, order: .reverse)]
        )
        fetchDescriptor.fetchLimit = 1

        //timestampedLogger("fetchBottomMessage called before", level: .debug)

        let messages = try modelContext.fetch(fetchDescriptor)
        if let message = messages.first {
            return MessageData(from: message)
        }
        return nil
    }

    func fetchMessages(
        for conversationID: UUID,
        from fetchFrom: FetchFrom,
        to endingDate: Date?,
        direction: Direction?,
        numbers: Int,
        searchKey: SearchKey
    ) throws -> [MessageData]? {
        let searchKeyC = searchKey.c
        let searchKeyD = searchKey.d
        let isSearchKeyCEmpty = searchKey.c.isEmpty
        let isSearchKeyDEmpty = searchKey.d.isEmpty

        var sortOrder: SortOrder = .forward
        var predicate: Predicate<Message>

        //timestampedLogger("fetchMessages called enter", level: .debug)

        switch fetchFrom {
        case .starting(let startingDate):
            if let endingDate {  // Range search
                predicate = #Predicate<Message> { message in
                    message.conversationID == conversationID &&
                    (startingDate...endingDate).contains(message.createdAt) &&
                    //(!message.thinkContent.isEmpty || !message.realContent.isEmpty) &&
                    (isSearchKeyCEmpty || message.realContent.localizedStandardContains(searchKeyC)) &&
                    (isSearchKeyDEmpty || message.realContent.localizedStandardContains(searchKeyD))
                }
            } else {
                guard let direction else {
                    throw MessageFetchError.missingFetchDirection
                }
                switch direction {
                case .up:
                    predicate = #Predicate<Message> { message in
                        message.conversationID == conversationID &&
                        message.createdAt < startingDate &&
                        (isSearchKeyCEmpty || message.realContent.localizedStandardContains(searchKeyC)) &&
                        (isSearchKeyDEmpty || message.realContent.localizedStandardContains(searchKeyD))
                    }
                    sortOrder = .reverse
                case .down:
                    predicate = #Predicate<Message> { message in
                        message.conversationID == conversationID &&
                        message.createdAt > startingDate &&
                        (isSearchKeyCEmpty || message.realContent.localizedStandardContains(searchKeyC)) &&
                        (isSearchKeyDEmpty || message.realContent.localizedStandardContains(searchKeyD))
                    }
                default: throw MessageFetchError.missingFetchDirection
                }
            }
        case .top, .bottom:
            predicate = #Predicate<Message> { message in
                message.conversationID == conversationID &&
                (isSearchKeyCEmpty || message.realContent.localizedStandardContains(searchKeyC)) &&
                (isSearchKeyDEmpty || message.realContent.localizedStandardContains(searchKeyD))
            }
            if fetchFrom == .bottom {
                sortOrder = .reverse
            }
        }

        var fetchDescriptor = FetchDescriptor<Message>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Message.createdAt, order: sortOrder)]
        )

        if numbers != 0 {
            fetchDescriptor.fetchLimit = numbers
        }

        let matchedMessages = try modelContext.fetch(fetchDescriptor)
        
        var messagesDatas = matchedMessages.map { MessageData(from: $0) }
        
        if sortOrder == .reverse {
            messagesDatas = messagesDatas.reversed()
        }
        
        //timestampedLogger("fetchMessages called after, messages count: \(messagesDatas.count), Thread: \(Thread.isMainThread ? "Main Thread" : "Background Thread")", level: .debug)
        return messagesDatas
    }

    func fetchChatStaticForModel(
        start: Date,
        end: Date,
        modelName: String,
        modelAPIName: String,
        roleRaw: String
    ) throws -> (Int, Int, Int) {
        let predicate = #Predicate<Message> { message in
            message.modelName == modelName &&
            message.modelAPIName == modelAPIName &&
            message.roleRaw == roleRaw &&
            (start...end).contains(message.createdAt) &&
            (!message.thinkContent.isEmpty || !message.realContent.isEmpty)
        }

        let fetchDescriptor = FetchDescriptor<Message>(predicate: predicate)

        let matchedMessages = try modelContext.fetch(fetchDescriptor)

        let tokenSums = matchedMessages.reduce((prompt: 0, completion: 0)) { partialResult, message in
            let newPromptSum = partialResult.prompt + (message.promptEvalCount ?? 0)
            let newCompletionSum = partialResult.completion + (message.evalCount ?? 0)
            return (prompt: newPromptSum, completion: newCompletionSum)
        }

        let promptTokens = tokenSums.prompt
        let completionTokens = tokenSums.completion
        let requests = matchedMessages.count

        //timestampedLogger("fetchChatStaticForModel called after, promptTokens: \(promptTokens), completionTokens: \(completionTokens), requests: \(requests), start time: \(start), end time: \(end), Thread: \(Thread.isMainThread ? "Main Thread" : "Background Thread")", level: .debug)

        return (promptTokens, completionTokens, requests)
    }

    func deleteEverything() throws {
        try modelContext.delete(model: Conversation.self)
        try modelContext.delete(model: ModelAPI.self)
        try modelContext.delete(model: Message.self)
        try modelContext.saveChanges()
    }
}
