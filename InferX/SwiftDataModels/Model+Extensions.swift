import Foundation
import SwiftData
import Defaults

extension Model {
    var fullName: String { apiName + "::" + name }

    var modelProvider: ModelProvider {
        get {
            ModelProvider(rawValue: providerRaw) ?? .none
        }
        set {
            providerRaw = newValue.rawValue
        }
    }

    convenience init(
        name: String,
        apiName: String,
        modelProvider: ModelProvider = .none
    ) {
        self.init(
            name: name,
            apiName: apiName,
            providerRaw: modelProvider.rawValue
        )
    }

    func applyParameter(_ p: ModelParameter) {
        enableTemperature = p.enableTemperature
        temperature = p.temperature
        enableTopP = p.enableTopP
        topP = p.topP
        enableTopK = p.enableTopK
        topK = p.topK
        inputMessages = p.inputMessages
        enableInputTokens = p.enableInputTokens
        inputTokens = p.inputTokens
        enableOutputTokens = p.enableOutputTokens
        outputTokens = p.outputTokens
        enableRepetitionPenalty = p.enableRepetitionPenalty
        repetitionPenalty = p.repetitionPenalty
        enableSystemPrompt = p.enableSystemPrompt
        systemPrompt = p.systemPrompt
        thinking = p.thinking
        thinkingTags = p.thinkingTags
        enableSeed = p.enableSeed
        seed = p.seed
        modelSize = p.modelSize
    }

    enum ModelError: Error, LocalizedError {
        case nameAlreadyExists(String)
        case emptyNameNotAllowed
        case modelSizeExceedLimits(String, Double)

        var errorDescription: String? {
            switch self {
            case .nameAlreadyExists(let name):
                return "Model '\(name)' already exists in the current API, please select another model name."
            case .emptyNameNotAllowed:
                return "Name cannot be empty."
            case .modelSizeExceedLimits(let modelId, let memoryInUse):
                let memoryInMB = Int(memoryInUse)
                let gpuCacheLimitMB = Int(Defaults[.gpuCacheLimit])
                return "Model \(modelId) memory in use \(memoryInMB)MB is greater than the current system setting \(gpuCacheLimitMB)MB."
            }
        }
    }
}

struct ModelParameter: Codable, Sendable, Hashable {
    var enableTemperature: Bool = false
    var temperature: Float = 0.8
    var enableTopP: Bool = false
    var topP: Float = 1.0
    var enableTopK: Bool = false
    var topK: Int = 40
    var inputMessages: Int = 20
    var enableInputTokens: Bool = false
    var inputTokens: Int = 1048576
    var enableOutputTokens: Bool = false
    var outputTokens: Int = 65536
    var enableRepetitionPenalty: Bool = false
    var repetitionPenalty: Float = 1.1
    var enableSystemPrompt: Bool = false
    var systemPrompt: String = ""
    var thinking: Bool = false
    var thinkingTags: String = ""
    var enableSeed: Bool = false
    var seed: Int = 40
    var modelSize: Int = 0

    init() {}
    
    init(from model: Model) {
        self.enableTemperature = model.enableTemperature
        self.temperature = model.temperature
        self.enableTopP = model.enableTopP
        self.topP = model.topP
        self.enableTopK = model.enableTopK
        self.topK = model.topK
        self.inputMessages = model.inputMessages
        self.enableInputTokens = model.enableInputTokens
        self.inputTokens = model.inputTokens
        self.enableOutputTokens = model.enableOutputTokens
        self.outputTokens = model.outputTokens
        self.enableRepetitionPenalty = model.enableRepetitionPenalty
        self.repetitionPenalty = model.repetitionPenalty
        self.enableSystemPrompt = model.enableSystemPrompt
        self.systemPrompt = model.systemPrompt
        self.thinking = model.thinking
        self.thinkingTags = model.thinkingTags
        self.enableSeed = model.enableSeed
        self.seed = model.seed
        self.modelSize = model.modelSize
    }
}
