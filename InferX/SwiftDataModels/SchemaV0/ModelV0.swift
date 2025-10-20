import Foundation
import SwiftData

extension SchemaV0 {
    @Model
    final class Model: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
        var name: String = ""
        var apiName: String = ""
        var providerRaw: String = ""
        var createdAt: Date = Date()
        var isAvailable: Bool = false
        var enableTemperature: Bool = false
        var temperature: Float = 0.8
        var enableTopP: Bool = false
        var topP: Float = 1.0
        var enableTopK: Bool = false
        var topK: Int = 40
        var inputMessages: Int = 20
        var enableInputTokens: Bool = false
        var inputTokens: Int = 1_000_000
        var enableOutputTokens: Bool = false
        var outputTokens: Int = 1_000_000
        var enableRepetitionPenalty: Bool = false
        var repetitionPenalty: Float = 1.1
        var enableSystemPrompt: Bool = false
        var systemPrompt: String = ""
        var thinking: Bool = false
        var thinkingTags: String = ""
        var enableSeed: Bool = false
        var seed: Int = 40
        var modelSize: Int = 0

        #Index<Model>(
            [\.id],
            [\.name, \.apiName]
        )

        init(
            name: String,
            apiName: String,
            providerRaw: String
        ) {
            self.name = name
            self.apiName = apiName
            self.providerRaw = providerRaw
        }
    }
}
