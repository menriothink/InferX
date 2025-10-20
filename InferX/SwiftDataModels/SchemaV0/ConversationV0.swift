import SwiftData
import Foundation

extension SchemaV0 {
    @Model
    final class Conversation: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
        var title: String = ""
        var modelID: UUID? = nil
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var userPrompt: String = ""
        var userPromptEnable: Bool = false

        #Index<Conversation>(
            [\.id],
            [\.updatedAt]
        )

        init(
            title: String,
            modelID: UUID?,
            createdAt: Date,
            updateAt: Date,
            userPrompt: String,
            userPromptEnable: Bool
         ) {
             self.title = title
             self.modelID = modelID
             self.createdAt = createdAt
             self.updatedAt = updateAt
             self.userPrompt = userPrompt
             self.userPromptEnable = userPromptEnable
         }
    }
}
