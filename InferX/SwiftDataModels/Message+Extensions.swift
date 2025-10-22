import Foundation

struct AttachmentData: Sendable {
    var bookmark: Data
    var url: String?
    var thumbnail: Data?
}

extension Message {
    var role: Role {
        get {
            Role(rawValue: roleRaw) ?? .user
        }
        set {
            roleRaw = newValue.rawValue
        }
    }

    var modelProvider: ModelProvider? {
        get {
            guard let providerRaw else { return nil }
            return ModelProvider(rawValue: providerRaw)
        }
        set {
            providerRaw = newValue?.rawValue
        }
    }

    var attachmentsData: [UUID: AttachmentData] {
        get {
            var resultingAttachments: [UUID: AttachmentData] = [:]
            for (id, bookmarkData) in attachBookmarks {
                let attachmentData = AttachmentData(
                    bookmark: bookmarkData,
                    url: attachUploadUrls[id],
                    thumbnail: attachThumbnails[id]
                )
                resultingAttachments[id] = attachmentData
            }

            return resultingAttachments
        }

        set {
            guard !newValue.isEmpty else {
                return
            }

            for (id, attachmentData) in newValue {
                self.attachBookmarks[id] = attachmentData.bookmark
                self.attachUploadUrls[id] = attachmentData.url
                self.attachThumbnails[id] = attachmentData.thumbnail
            }
        }
    }

    var chatStatics: ChatStatics? {
        get {
            guard self.promptEvalCount != nil, self.evalCount != nil else {
                return nil
            }

            return ChatStatics(
                totalDuration: self.totalDuration,
                loadDuration: self.loadDuration,
                promptEvalCount: self.promptEvalCount,
                promptEvalDuration: self.promptEvalDuration,
                evalCount: self.evalCount,
                evalDuration: self.evalDuration
            )
        }

        set {
            self.totalDuration = newValue?.totalDuration
            self.loadDuration = newValue?.loadDuration
            self.promptEvalCount = newValue?.promptEvalCount
            self.promptEvalDuration = newValue?.promptEvalDuration
            self.evalCount = newValue?.evalCount
            self.evalDuration = newValue?.evalDuration
        }
    }
}

struct MessageData: Identifiable, Sendable {
    var id: UUID
    var role: Role
    var content: String
    var createdAt: Date
    var conversationID: UUID
    var modelName: String?
    var modelAPIName: String?
    var modelProvider: ModelProvider?
    var elapsedTimeString: String?
    var attachmentsData: [UUID: AttachmentData]
    var chatStatics: ChatStatics?

    var fullName: String? {
        guard let modelName = self.modelName,
              let modelAPIName = self.modelAPIName,
              let modelProvider = self .modelProvider else { return nil }

        return "\(modelAPIName)::\(modelProvider.rawValue)::\(modelName)"
    }

    init(
        id: UUID = UUID(),
        role: Role = .user,
        content: String = "",
        createdAt: Date = .now,
        conversationID: UUID = UUID(),
        modelName: String? = nil,
        modelAPIName: String? = nil,
        modelProvider: ModelProvider? = nil,
        elapsedTimeString: String? = nil,
        attachmentsData: [UUID: AttachmentData] = [:],
        chatStatics: ChatStatics? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.conversationID = conversationID
        self.modelName = modelName
        self.modelAPIName = modelAPIName
        self.modelProvider = modelProvider
        self.elapsedTimeString = elapsedTimeString
        self.attachmentsData = attachmentsData
        self.chatStatics = chatStatics
    }

    init(from message: Message) {
        self.init(
            id: message.id,
            role: message.role,
            content: message.thinkContent + message.realContent,
            createdAt: message.createdAt,
            conversationID: message.conversationID,
            modelName: message.modelName,
            modelAPIName: message.modelAPIName,
            modelProvider: message.modelProvider,
            elapsedTimeString: message.elapsedTimeString,
            attachmentsData: message.attachmentsData,
            chatStatics: message.chatStatics
        )
    }

    func saveToMessage(to message: Message) {
        message.id = self.id
        message.role = self.role
        message.thinkContent = self.think.isEmpty ? "" : "<think>" + self.think + "</think>"
        message.realContent = self.realContent
        message.createdAt = self.createdAt
        message.conversationID = self.conversationID
        message.modelName = self.modelName
        message.modelAPIName = self.modelAPIName
        message.modelProvider = self.modelProvider
        message.elapsedTimeString = self.elapsedTimeString
        message.chatStatics = self.chatStatics
        message.attachmentsData = self.attachmentsData
    }

    static func create(
        role: Role,
        content: String = "",
        attachmentsData: [UUID: AttachmentData] = [:],
        conversationID: UUID?,
        modelName: String? = nil,
        modelAPIName: String? = nil,
        modelProvider: ModelProvider? = nil
    ) async -> MessageData? {
        if let conversationID {
            let messageData = MessageData(
                role: role,
                content: content,
                conversationID: conversationID,
                modelName: modelName,
                modelAPIName: modelAPIName,
                modelProvider: modelProvider,
                attachmentsData: attachmentsData
            )

            do {
                try await SwiftDataProvider.share.messageService.createMessage(messageData)
                return messageData
            } catch {
                print("Create \(role) message failed: \(error)")
            }
        }
        return nil
    }

    static func create(from messageData: MessageData) async -> Bool {
        do {
            try await SwiftDataProvider.share.messageService.createMessage(messageData)
            return true
        } catch {
            print("Create \(messageData.role) message failed: \(error)")
            return false
        }
    }
    
    var think: String {
        guard self.role == .assistant else { return "" }
        if !content.contains("<think>") && !content.contains("</think>") { return "" }

        let firstThinkRange = content.range(of: "<think>")
        let lastEndThinkRange = content.range(of: "</think>", options: .backwards)
        if let thinkStart = firstThinkRange {
            if let thinkEnd = lastEndThinkRange {
                let thinkContentRange = content.startIndex..<thinkEnd.lowerBound
                let rawContent = String(content[thinkContentRange])
                return rawContent
                    .replacingOccurrences(of: "<think>", with: "")
                    .replacingOccurrences(of: "</think>", with: "")
            } else {
                return String(content[thinkStart.upperBound...])
            }
        }

        return ""
    }

    var hasThink: Bool {
        guard self.role == .assistant else { return false }

        if content.contains("<think>") {
            return true
        }
        return false
    }

    var thinkComplete: Bool {
        guard self.role == .assistant else { return false }

        if content.contains("<think>") {
            if content.contains("</think>") {
                return true
            }
        }
        return false
    }

    var realContent: String {
        guard self.role == .assistant else { return content }

        guard let completeThinkBlockRegex = try? NSRegularExpression(
            pattern: "<think>.*?</think>",
            options: .dotMatchesLineSeparators
        ) else {
            return ""
        }
        
        let fullRange = NSRange(content.startIndex..., in: content)
        let contentWithoutFullBlocks = completeThinkBlockRegex.stringByReplacingMatches(
            in: content,
            options: [],
            range: fullRange,
            withTemplate: ""
        )

        if let lastEndThinkRange = contentWithoutFullBlocks.range(of: "</think>", options: .backwards) {
            return String(contentWithoutFullBlocks[lastEndThinkRange.upperBound...])
        }

        if contentWithoutFullBlocks.contains("<think>") {
            return ""
        }

        return contentWithoutFullBlocks
    }
}
