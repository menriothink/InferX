import Foundation
import SwiftData

extension SchemaV0 {
    @Model
    final class Message: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
        var roleRaw: String = ""
        var thinkContent: String = ""
        var realContent: String = ""
        var createdAt: Date = Date()
        var conversationID: UUID = UUID()
        var modelName: String? = nil
        var modelAPIName: String? = nil
        var providerRaw: String? = nil
        var elapsedTimeString: String? = nil
        var totalDuration: TimeInterval? = nil
        var loadDuration: TimeInterval? = nil
        var promptEvalCount: Int? = nil
        var promptEvalDuration: TimeInterval? = nil
        var evalCount: Int? = nil
        var evalDuration: TimeInterval? = nil
        var attachBookmarks: [UUID: Data] = [:]
        var attachUploadUrls: [UUID: String] = [:]
        @Attribute(.externalStorage) var attachThumbnails: [UUID: Data] = [:]

        #Index<Message>(
            [\.createdAt],
            [\.conversationID],
            [\.conversationID, \.createdAt],
            [\.modelName, \.modelAPIName, \.createdAt]
        )

        init() {}
    }
}
