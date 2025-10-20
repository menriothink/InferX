//
//  OllamaService.swift
//  InferX
//
//  Created by mingdw on 2025/4/20.
//

import Foundation

actor OllamaService {
    static let shared = OllamaService()

    private func isInvalidConfig(modelAPI: ModelAPIDescriptor) async -> SimpleError? {
        guard !modelAPI.endPoint.isEmpty else {
            return SimpleError(message: "Ollama API endpoint is empty")
        }

        return nil
    }

    func getModels(
        modelAPI: ModelAPIDescriptor,
        handler: @escaping @Sendable (ModelsCompletion) async -> Void
    ) async {
        if let simpleError = await isInvalidConfig(modelAPI: modelAPI) {
            await handler(.failure(simpleError))
            return
        }

        do {
            guard let baseURL = URL(string: modelAPI.endPoint) else {
               throw SimpleError(message: "endpoint is invalid")
            }
            let request = try OKRequest<Never>(route: .models(["/api/tags"]))
                .asURLRequest(baseURL: baseURL)
            let response: OllamaModelResponse = try await OKHTTPClient.shared.send(
                request: request,
                with: OllamaModelResponse.self
            )

            let models: [RemoteModel] = await withTaskGroup(of: RemoteModel?.self) { group in
                for model in response.models {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        let meta = await self.buildModelMeta(for: model, modelAPI: modelAPI)
                        return RemoteModel(
                            name: model.name,
                            modelProvider: .ollama,
                            modelMeta: meta
                        )
                    }
                }

                var collectedModels: [RemoteModel] = []
                for await model in group.compactMap({ $0 }) {
                    collectedModels.append(model)
                }

                return collectedModels
            }
            await handler(.finished(models))
        } catch {
            var urlError = ""
            if let error = error as? URLError { urlError = "URLError Code: \(error.code)" }
            let simpleError = SimpleError(message: "Failed to load Ollama models, error: \(error), " + urlError)
            await handler(.failure(simpleError))
        }
    }

    func chatModel(
        modelAPI: ModelAPIDescriptor,
        for chatRequest: ChatRequest,
        handler: @escaping @Sendable (ChatCompletion) async -> Void
    ) async {
        if let simpleError = await isInvalidConfig(modelAPI: modelAPI) {
            await handler(ChatCompletion.failure(simpleError))
            return
        }

        do {
            guard let baseURL = URL(string: modelAPI.endPoint) else {
               throw SimpleError(message: "endpoint is invalid")
            }

            let requestData = OllamaChatRequestData(from: chatRequest)
            let request = try OKRequest<OllamaChatRequestData>(
                route: .modelInfo(["/api/chat"]),
                body: requestData
            ).asURLRequest(baseURL: baseURL)

            let response = await OKHTTPClient.shared.stream(request: request, with: OllamaChatResponse.self)

            for try await element in response {
                await handler(ChatCompletion.receiving(ChatResponse(from: element)))
            }
            await handler(ChatCompletion.finished)
        } catch {
            var urlError = error.localizedDescription
            if let error = error as? URLError {
                urlError += "URLError Code: \(error.code)"
            }
            let simpleError = SimpleError(message: "Stream terminated with error: \(error), " + urlError)
            await handler(ChatCompletion.failure(simpleError))
        }
    }

    private func probeImageSupport(
        modelAPI: ModelAPIDescriptor,
        modelName: String
    ) async -> Bool {
        guard let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==")
              else { return false }

        let msg = OllamaChatRequestData.Message(role: .user, content: "Describe this image briefly.", images: [tinyPNG.base64EncodedString()])
        let reqData = OllamaChatRequestData(model: modelName, messages: [msg])
        do {
            guard let baseURL = URL(string: modelAPI.endPoint) else {
               throw SimpleError(message: "endpoint is invalid")
            }

            let request = try OKRequest<OllamaChatRequestData>(
                route: .modelInfo(["/api/chat"]),
                body: reqData
            ).asURLRequest(baseURL: baseURL)

            let stream = await OKHTTPClient.shared.stream(request: request, with: OllamaChatResponse.self)
            var receivedAny = false
            for try await chunk in stream {
                if chunk.message != nil { receivedAny = true; break }
                if chunk.done { break }
            }
            return receivedAny
        } catch {
            return false
        }
    }
}

private extension OllamaService {
    func buildModelMeta(for model: OllamaModelResponse.Model, modelAPI: ModelAPIDescriptor) async -> ModelMeta {
        var meta = ModelMeta()
        meta.version = model.digest
        //if let size = parseParameterSize(model.details.parameterSize) { meta.modelSize = size }
        meta.description = [model.details.family, model.details.parameterSize, model.details.quantizationLevel]
            .compactMap { $0 }
            .joined(separator: " • ")
        let famLower = model.details.family.lowercased()
        meta.thingking = famLower.contains("deepseek") || famLower.contains("reason") || famLower.contains("r1")
        meta.seed = true
        /*if shouldProbeImageSupport(for: model) {
            let supported = await probeImageSupport(modelAPI: modelAPI, modelName: model.name)
            meta.mediaSupport = supported
        } else {
            meta.mediaSupport = false
        }*/
        meta.mediaSupport = probeImageSupport(for: model)
        return meta
    }

    func parseParameterSize(_ raw: String) -> Int? {
        let pattern = "([0-9]+(?:\\.[0-9]+)?)([BbMm])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, range: range), match.numberOfRanges == 3 else { return nil }
        guard let numRange = Range(match.range(at: 1), in: raw), let unitRange = Range(match.range(at: 2), in: raw) else { return nil }
        let numberString = String(raw[numRange])
        let unit = String(raw[unitRange]).uppercased()
        guard let value = Double(numberString) else { return nil }
        let multiplier: Double = (unit == "B") ? 1_000_000_000 : 1_000_000
        return Int(value * multiplier)
    }

    func probeImageSupport(for model: OllamaModelResponse.Model) -> Bool {
        let family = model.details.family.lowercased()
        if family.contains("llava") || family.contains("vision") || family.contains("clip") { return true }
        if let families = model.details.families?.map({ $0.lowercased() }) {
            if families.contains(where: { $0.contains("llava") || $0.contains("vision") || $0.contains("clip") }) { return true }
        }
        return false
    }
}

struct OllamaChatRequestData: Sendable {
    private let stream: Bool

    /// A string representing the model identifier to be used for the chat session.
    public let model: String

    /// An array of ``Message`` instances representing the content to be sent to the Ollama API.
    public let messages: [Message]

    /// An optional array of ``OKJSONValue`` representing the tools available for tool calling in the chat.
    public let tools: [OKJSONValue]?

    /// Optional ``OKJSONValue`` representing the JSON schema for the response.
    /// Be sure to also include "return as JSON" in your prompt
    public let format: OKJSONValue?

    /// Optional ``OKCompletionOptions`` providing additional configuration for the chat request.
    public var options: OKCompletionOptions?

    public init(
        model: String,
        messages: [Message],
        tools: [OKJSONValue]? = nil,
        format: OKJSONValue? = nil,
        options: OKCompletionOptions? = nil
    ) {
        self.stream = tools == nil
        self.model = model
        self.messages = messages
        self.tools = tools
        self.format = format
        self.options = options
    }

    /// A structure that represents a single message in the chat request.
    public struct Message: Encodable, Sendable {
        /// A ``Role`` value indicating the sender of the message (system, assistant, user).
        public let role: Role

        /// A string containing the message's content.
        public let content: String

        /// An optional array of base64-encoded images.
        public let images: [String]?

        public init(role: Role, content: String, images: [String]? = nil) {
            self.role = role
            self.content = content
            self.images = images
        }

        /// An enumeration that represents the role of the message sender.
        public enum Role: String, Encodable, Sendable {
            /// Indicates the message is from the system.
            case system

            /// Indicates the message is from the assistant.
            case assistant

            /// Indicates the message is from the user.
            case user
        }
    }
}

struct OKCompletionOptions: Encodable, Sendable {
    /// Optional integer to enable Mirostat sampling for controlling perplexity.
    /// (0 = disabled, 1 = Mirostat, 2 = Mirostat 2.0)
    /// Mirostat sampling helps regulate the unpredictability of the output,
    /// balancing coherence and diversity. The default value is 0, which disables Mirostat.
    public var mirostat: Int?

    /// Optional double influencing the adjustment speed of the Mirostat algorithm.
    /// (Lower values result in slower adjustments, higher values increase responsiveness.)
    /// This parameter, `mirostatEta`, adjusts how quickly the algorithm reacts to feedback
    /// from the generated text. A default value of 0.1 provides a moderate adjustment speed.
    public var mirostatEta: Float?

    /// Optional double controlling the balance between coherence and diversity.
    /// (Lower values lead to more focused and coherent text)
    /// The `mirostatTau` parameter sets the target perplexity level, influencing how
    /// creative or constrained the text generation should be. Default is 5.0.
    public var mirostatTau: Float?

    /// Optional integer setting the size of the context window for token generation.
    /// This defines the number of previous tokens the model considers when generating new tokens.
    /// Larger values allow the model to use more context, with a default of 2048 tokens.
    public var numCtx: Int?

    /// Optional integer setting how far back the model looks to prevent repetition.
    /// This parameter, `repeatLastN`, determines the number of tokens the model
    /// reviews to avoid repeating phrases. A value of 64 is typical, while 0 disables this feature.
    public var repeatLastN: Int?

    /// Optional double setting the penalty strength for repetitions.
    /// A higher value increases the penalty for repeated tokens, discouraging repetition.
    /// The default value is 1.1, providing moderate repetition control.
    public var repeatPenalty: Float?

    /// Optional double to control the model's creativity.
    /// (Higher values increase creativity and randomness)
    /// The `temperature` parameter adjusts the randomness of predictions; higher values
    /// like 0.8 make outputs more creative and diverse. The default is 0.7.
    public var temperature: Float?

    /// Optional integer for setting a random number seed for generation consistency.
    /// Specifying a seed ensures the same output for the same prompt and parameters,
    /// useful for testing or reproducing results. Default is 0, meaning no fixed seed.
    public var seed: Int?

    /// Optional string defining stop sequences for the model to cease generation.
    /// The `stop` parameter specifies sequences that, when encountered, will halt further text generation.
    /// Multiple stop sequences can be defined. For example, "AI assistant:".
    public var stop: String?

    /// Optional double for tail free sampling, reducing impact of less probable tokens.
    /// `tfsZ` adjusts how much the model avoids unlikely tokens, with higher values
    /// reducing their influence. A value of 1.0 disables this feature.
    public var tfsZ: Float?

    /// Optional integer for the maximum number of tokens to predict.
    /// `numPredict` sets the upper limit for the number of tokens to generate.
    /// A default of 128 tokens is typical, with special values like -1 for infinite generation.
    public var numPredict: Int?

    /// Optional integer to limit nonsense generation and control answer diversity.
    /// The `topK` parameter limits the set of possible tokens to the top-k likely choices.
    /// Lower values (e.g., 10) reduce diversity, while higher values (e.g., 100) increase it. Default is 40.
    public var topK: Int?

    /// Optional double working with top-k to balance text diversity and focus.
    /// `topP` (nucleus sampling) retains tokens that cumulatively account for a certain
    /// probability mass, adding flexibility beyond `topK`. A value like 0.9 increases diversity.
    public var topP: Float?

    /// Optional double for the minimum probability threshold for token inclusion.
    /// `minP` ensures that tokens below a certain probability threshold are excluded,
    /// focusing the model's output on more probable sequences. Default is 0.0, meaning no filtering.
    public var minP: Float?

    public init(mirostat: Int? = nil, mirostatEta: Float? = nil, mirostatTau: Float? = nil, numCtx: Int? = nil, repeatLastN: Int? = nil, repeatPenalty: Float? = nil, temperature: Float? = nil, seed: Int? = nil, stop: String? = nil, tfsZ: Float? = nil, numPredict: Int? = nil, topK: Int? = nil, topP: Float? = nil, minP: Float? = nil) {
        self.mirostat = mirostat
        self.mirostatEta = mirostatEta
        self.mirostatTau = mirostatTau
        self.numCtx = numCtx
        self.repeatLastN = repeatLastN
        self.repeatPenalty = repeatPenalty
        self.temperature = temperature
        self.seed = seed
        self.stop = stop
        self.tfsZ = tfsZ
        self.numPredict = numPredict
        self.topK = topK
        self.topP = topP
        self.minP = minP
    }
}

extension OllamaChatRequestData: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stream, forKey: .stream)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encodeIfPresent(format, forKey: .format)

        if let options {
            try options.encode(to: encoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case stream, model, messages, tools, format
    }
}

extension OllamaChatRequestData {
    init(from chatRequest: ChatRequest) {
        var messages = chatRequest.messages.map { message in
            var content: String = ""
            for part in message.parts {
                switch part {
                case .text(let textContent):
                    content = textContent

                case .attachmentsData(_): break
                }
            }

            return OllamaChatRequestData.Message(
                role: OllamaChatRequestData.Message.Role(rawValue: message.role.rawValue) ?? .assistant,
                content: content
            )
        }

        let modelParameter = chatRequest.modelParameter
        if modelParameter.enableSystemPrompt {
            let systemMessage = OllamaChatRequestData.Message(
                role: .system,
                content: modelParameter.systemPrompt
            )
            messages.insert(systemMessage, at: 0)
        }

        let options = OKCompletionOptions(
            repeatPenalty: modelParameter.repetitionPenalty,
            temperature: modelParameter.temperature,
            seed: modelParameter.seed,
            numPredict: modelParameter.outputTokens,
            topK: modelParameter.topK,
            topP: modelParameter.topP
        )

        self.init(
            model: chatRequest.modelName,
            messages: messages,
            options: options
        )
    }
}

extension ChatResponse {
    init(from ollamaChatResponse: OllamaChatResponse) {
        self.model = ollamaChatResponse.model
        self.createdAt = ollamaChatResponse.createdAt
        self.message = {
            if let msg = ollamaChatResponse.message {
                return ChatResponse.Message(
                    role: Role(rawValue: msg.role.rawValue) ?? .assistant,
                    parts: [
                        .text(msg.content)
                        //.inlineMedia(mimeType: "image/jpeg", data: imageData), // 示例输入图像
                        //.fileMedia(mimeType: "video/mp4", fileUri: "gs://cloud-samples-data/generative-ai/video/pixel8.mp4") // 示例视频 URI
                    ]
                )
            } else {
                return nil
            }
        }()

        self.done = ollamaChatResponse.done
        self.doneReason = ollamaChatResponse.doneReason
        self.chatStatics = ChatStatics(
            totalDuration: ollamaChatResponse.totalDuration?.asSecondsFromNano,
            loadDuration: ollamaChatResponse.loadDuration?.asSecondsFromNano,
            promptEvalCount: ollamaChatResponse.promptEvalCount,
            promptEvalDuration: ollamaChatResponse.promptEvalDuration?.asSecondsFromNano,
            evalCount: ollamaChatResponse.evalCount,
            evalDuration: ollamaChatResponse.evalDuration?.asSecondsFromNano
        )
    }
}

/// A structure that represents the response to a chat request from the Ollama API.
struct OllamaChatResponse: Decodable, Sendable {
    /// The identifier of the model that processed the request.
    public let model: String

    /// The date and time when the response was created.
    public let createdAt: Date

    /// An optional ``Message`` instance representing the content of the response.
    /// Contains the main message data, including the role of the sender and the content.
    public let message: Message?

    /// A boolean indicating whether the chat session is complete.
    public let done: Bool

    /// An optional string providing the reason for the completion of the chat session.
    public let doneReason: String?

    /// An optional integer representing the total duration of processing the request, in nanoseconds.
    public let totalDuration: Int?

    /// An optional integer representing the time taken to load the model, in nanoseconds.
    public let loadDuration: Int?

    /// An optional integer indicating the number of tokens in the prompt that were evaluated.
    public let promptEvalCount: Int?

    /// An optional integer representing the duration of prompt evaluations, in nanoseconds.
    public let promptEvalDuration: Int?

    /// An optional integer indicating the number of tokens generated in the response.
    public let evalCount: Int?

    /// An optional integer representing the duration of all evaluations, in nanoseconds.
    public let evalDuration: Int?

    /// A structure that represents a single response message.
    public struct Message: Decodable, Sendable {
        /// The role of the message sender (system, assistant, user).
        public var role: Role

        /// The content of the message.
        public var content: String

        /// An optional array of ``ToolCall`` instances representing any tools invoked in the response.
        public var toolCalls: [ToolCall]?

        /// An enumeration representing the role of the message sender.
        public enum Role: String, Decodable, Sendable {
            /// The message is from the system.
            case system

            /// The message is from the assistant.
            case assistant

            /// The message is from the user.
            case user
        }

        /// A structure that represents a tool call in the response.
        public struct ToolCall: Decodable, Sendable {
            /// An optional ``Function`` structure representing the details of the tool call.
            public let function: Function?

            /// A structure that represents the details of a tool call.
            public struct Function: Decodable, Sendable {
                /// The name of the tool being called.
                public let name: String?

                /// An optional ``OKJSONValue`` representing the arguments passed to the tool.
                public let arguments: OKJSONValue?
            }
        }
    }
}

struct OllamaModelResponse: Decodable, Sendable {
    /// An array of ``Model`` instances, each representing a specific model available in the Ollama API.
    public let models: [Model]

    /// A structure that details individual models.
    public struct Model: Decodable, Sendable {
        /// A string representing the name of the model.
        public let name: String

        /// A string containing a digest or hash of the model, typically used for verification or identification.
        public let digest: String

        /// An integer indicating the size of the model, often in bytes.
        public let size: Int

        /// A `Date` representing the last modification date of the model.
        public let modifiedAt: Date

        /// The details about the model.
        public let details: ModelDetails

        /// A structure that represents the details of the model.
        public struct ModelDetails: Decodable, Sendable {
            /// The format of the model. E.g. "gguf".
            public let format: String

            /// The family of the model. E.g. "llama".
            public let family: String

            /// The parameter size of the model. E.g. "8.0B".
            public let parameterSize: String

            /// The quantization level of the model. E.g. "Q4_0".
            public let quantizationLevel: String

            /// All the families of the model. E.g. ["llama", "phi3"].
            public let families: [String]?
        }
    }
}
