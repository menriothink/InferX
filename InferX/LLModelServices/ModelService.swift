//
//  LLMServiceBase.swift
//  InferX
//
//  Created by mingdw on 2025/4/23.
//

import SwiftUI
import Foundation

enum InputPart {
    case text(String)
    case attachmentsData([UUID: AttachmentData]?)
}

enum OutputPart {
    case text(String)
    case inlineMedia(mimeType: String, data: Data)
    case fileMedia(mimeType: String, fileUri: String)
}

enum ModelsCompletion {
    case finished([RemoteModel])
    case failure(SimpleError)
}

enum ChatCompletion {
    case receiving(ChatResponse)
    case finished
    case failure(SimpleError)
}

enum FileUploadCompletion {
    case finished(String?)
    case failure(SimpleError)
}

struct SimpleError: Error, LocalizedError {
    let message: String
    var errorDescription: String? {
        return message
    }
}

struct ModelMeta: Hashable {
    var inputTokenLimit: Int? = nil
    var outputTokenLimit: Int? = nil
    var maxTemperature: Float? = nil
    var temperature: Float? = nil
    var modelSize: Int? = nil
    var topP: Float? = nil
    var topK: Int? = nil
    var version: String? = nil
    var description: String? = nil
    var thingking: Bool = false
    var mediaSupport: Bool = false
    var seed: Bool = false
    var repetitionPenalty: Float? = nil
    var baseContextLength: Int? = nil
    var contextExtension: String? = nil
    var originNote: String? = nil
    var slidingWindow: Int? = nil
    var slidingLayers: Int? = nil
    var fullLayers: Int? = nil
    var moeExpertsPerToken: Int? = nil
    var moeLocalExperts: Int? = nil
    var vocabSize: Int? = nil
    var dtype: String? = nil
    var quantBits: Int? = nil
    var quantGroupSize: Int? = nil
    var quantMode: String? = nil
    var padTokenId: Int? = nil
    var eosTokenId: Int? = nil
    var chatTemplate: String? = nil
    var ropeType: String? = nil
    var ropeFactor: Double? = nil
    var ropeBetaFast: Double? = nil
    var ropeBetaSlow: Double? = nil
    var ropeTruncate: Bool? = nil
}

struct ChatStatics {
    let totalDuration: TimeInterval?
    let loadDuration: TimeInterval?
    let promptEvalCount: Int?
    let promptEvalDuration: TimeInterval?
    let evalCount: Int?
    let evalDuration: TimeInterval?

    var promptTokensPerSecond: Double? {
        guard let promptEvalCount, let promptEvalDuration, promptEvalDuration != 0 else { return nil }
        return Double(promptEvalCount) / promptEvalDuration
    }

    var tokensPerSecond: Double? {
        guard let evalCount, let evalDuration, evalDuration != 0 else { return nil }
        return Double(evalCount) / evalDuration
    }
}

struct ChatRequest {
    let modelName: String
    let modelParameter: ModelParameter
    let messages: [Message]

    struct Message {
        let role: Role
        let parts: [InputPart]
    }
}

struct ChatResponse {
    let model: String
    let createdAt: Date
    let message: Message?
    let done: Bool
    let doneReason: String?
    let chatStatics: ChatStatics?

    struct Message {
        var role: Role
        let parts: [OutputPart]
    }
}

struct FileUploadRequest {
    let fileURL: URL
    let progressHandler: @Sendable (Progress) async -> Void
}

struct RemoteModel: Identifiable, Sendable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var modelProvider: ModelProvider = .none
    var modelMeta: ModelMeta?
    var fullName: String { modelProvider.rawValue + "::" + name }
}

struct ModelAPIDescriptor: Identifiable, Sendable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var modelProvider: ModelProvider = .none
    var endPoint: String = ""
    var apiKey: String = ""
    var cacheDir: URL?
    
    init(from modelAPI: ModelAPI) {
        self.name = modelAPI.name
        self.modelProvider = modelAPI.modelProvider
        self.endPoint = modelAPI.endPoint
        self.apiKey = modelAPI.apiKey
        self.cacheDir = modelAPI.localModelsDir
    }
}

actor ModelService {
    func loadModels(
        for modelAPI: ModelAPIDescriptor,
        handler: @escaping @Sendable (ModelsCompletion) async -> Void
    ) async {
        if let loader = ModelService.modelLoad[modelAPI.modelProvider] {
            return await loader(modelAPI, handler)
        } else {
            print("There is no model loader found for provider: \(modelAPI.modelProvider)")
        }
    }

    func chatModel(
        for modelAPI: ModelAPIDescriptor,
        request: ChatRequest,
        handler: @escaping @Sendable (ChatCompletion) async -> Void
    ) async {
        guard let modelChat = ModelService.modelChat[modelAPI.modelProvider] else {
            let error = SimpleError(message: "You should select a model for the chat!")
            let completion = ChatCompletion.failure(error)
            await handler(completion)
            return
        }

        await modelChat(modelAPI, request, handler)
    }

    func uploadFile(
        for modelAPI: ModelAPIDescriptor,
        request: FileUploadRequest,
        handler: @escaping @Sendable (FileUploadCompletion) async -> Void
    ) async {
        guard let uploadFile = ModelService.uploadFile[modelAPI.modelProvider] else {
            let error = SimpleError(message: "Current model doesn't support File API!")
            let completion = FileUploadCompletion.failure(error)
            await handler(completion)
            return
        }
        await uploadFile(modelAPI, request, handler)
    }

    func provider(for modelName: String) -> ModelProvider? {
        for provider in ModelProvider.allCases {
            if modelName.hasPrefix(provider.rawValue + ":") {
                return provider
            }
        }
        return nil
    }
}

enum Role: String, Decodable, Sendable {
    case system
    case user
    case assistant

    var description: String {
        "\(self)"
    }
}

enum ModelProvider: String, Codable, Identifiable, CaseIterable {
    case ollama = "Ollama"
    case openAI = "OpenAI"
    case huggingFace = "HuggingFace"
    case gemini = "Gemini"
    case none = "None"

    var id: String { self.rawValue }

    var endPoint: String {
        switch self {
        case .ollama:
            return "http://localhost:11434"
        case .openAI:
            return ""
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta"
        case .huggingFace:
            return "https://huggingface.co"
        case .none:
            return ""
        }
    }
}

let imageSize: CGFloat = 25
var tabs: [SidebarTabView<ModelProvider>] {
    [
        .init(
            .ollama,
            Image("ollama"),
            32
        ),
        .init(
            .huggingFace,
            Image("huggingface"),
            22
        ),
        .init(
            .openAI,
            Image("huggingface"),
            imageSize
        ),
        .init(
            .gemini,
            Image("Gemini"),
            imageSize
        )
    ]
}

func matchedTab(modelProvider: ModelProvider?) -> SidebarTabView<ModelProvider>? {
    tabs.first { $0.id == modelProvider }
}

extension ModelService {
    static let modelLoad: [ModelProvider: @Sendable (
        ModelAPIDescriptor,
        @escaping @Sendable (ModelsCompletion) async -> Void
    ) async -> Void] = [
        .huggingFace: { modelAPI, handler in
            return await HuggingFaceService.shared.getModels(
                modelAPI: modelAPI,
                handler: handler
            )
        },
        .ollama: { modelAPI, handler in
            return await OllamaService.shared.getModels(
                modelAPI: modelAPI,
                handler: handler
            )
        },
        .gemini: { modelAPI, handler in
            return await GeminiService.shared.getModels(
                modelAPI: modelAPI,
                handler: handler
            )
        }
    ]

    static let modelChat: [ModelProvider: @Sendable (
        ModelAPIDescriptor,
        ChatRequest,
        @escaping @Sendable (ChatCompletion) async -> Void
    ) async -> Void] = [
        .huggingFace: { modelAPI, request, handler in
            await HuggingFaceService.shared.chatModel(
                modelAPI: modelAPI,
                for: request,
                handler: handler
            )
        },
        .ollama: { modelAPI, request, handler in
            await OllamaService.shared.chatModel(
                modelAPI: modelAPI,
                for: request,
                handler: handler
            )
        },
        .gemini: { modelAPI, request, handler in
            return await GeminiService.shared.chatModel(
                modelAPI: modelAPI,
                for: request,
                handler: handler
            )
        }
    ]

    static let uploadFile: [ModelProvider: @Sendable (
        ModelAPIDescriptor,
        FileUploadRequest,
        @escaping @Sendable (FileUploadCompletion) async -> Void
    ) async -> Void] = [
        .gemini: { modelAPI, request, handler in
            return await GeminiService.shared.uploadFile(
                modelAPI: modelAPI,
                for: request,
                handler: handler
            )
        }
    ]
}
