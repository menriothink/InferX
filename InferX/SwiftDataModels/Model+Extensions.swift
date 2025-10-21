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

    func applyParameter(_ parameter: ModelParameter) {
        enableTemperature = parameter.enableTemperature
        temperature = parameter.temperature
        enableTopP = parameter.enableTopP
        topP = parameter.topP
        enableTopK = parameter.enableTopK
        topK = parameter.topK
        inputMessages = parameter.inputMessages
        enableInputTokens = parameter.enableInputTokens
        inputTokens = parameter.inputTokens
        enableOutputTokens = parameter.enableOutputTokens
        outputTokens = parameter.outputTokens
        enableRepetitionPenalty = parameter.enableRepetitionPenalty
        repetitionPenalty = parameter.repetitionPenalty
        enableSystemPrompt = parameter.enableSystemPrompt
        systemPrompt = parameter.systemPrompt
        thinking = parameter.thinking
        thinkingTags = parameter.thinkingTags
        enableSeed = parameter.enableSeed
        seed = parameter.seed
        modelSize = parameter.modelSize
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
