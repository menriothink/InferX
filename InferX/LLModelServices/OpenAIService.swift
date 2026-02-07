//
//  OpenAIService.swift
//  InferX
//
//  Created for OpenAI-compatible API endpoints (including cursor-api-server)
//

import Foundation

actor OpenAIService {
    static let shared = OpenAIService()

    private func isInvalidConfig(modelAPI: ModelAPIDescriptor) async -> SimpleError? {
        guard !modelAPI.endPoint.isEmpty else {
            return SimpleError(message: "OpenAI API endpoint is empty")
        }
        // Note: API Key is optional for some OpenAI-compatible endpoints (e.g., cursor-api-server)
        return nil
    }

    private func setAuthorizationHeader(for request: inout URLRequest, with modelAPI: ModelAPIDescriptor) {
        if !modelAPI.apiKey.isEmpty {
            request.setValue("Bearer \(modelAPI.apiKey)", forHTTPHeaderField: "Authorization")
        }
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

            var request = try OKRequest<Never>(route: .custom(path: "/v1/models", method: "GET"))
                .asURLRequest(baseURL: baseURL)

            setAuthorizationHeader(for: &request, with: modelAPI)

            let response: OpenAIModelsResponse = try await OKHTTPClient.shared.send(
                request: request,
                with: OpenAIModelsResponse.self
            )

            let models = response.data.map { openAIModel in
                var meta = ModelMeta()
                meta.description = "Owned by \(openAIModel.ownedBy ?? "unknown")"
                
                // Check for vision/multimodal support based on model name
                let modelIdLower = openAIModel.id.lowercased()
                if modelIdLower.contains("vision") || 
                   modelIdLower.contains("gpt-4o") ||
                   modelIdLower.contains("gpt-4-turbo") {
                    meta.mediaSupport = true
                }

                return RemoteModel(
                    name: openAIModel.id,
                    modelProvider: .openAI,
                    modelMeta: meta
                )
            }

            await handler(.finished(models))
        } catch {
            var urlError = ""
            if let error = error as? URLError {
                urlError = "URLError Code: \(error.code)"
            }
            let simpleError = SimpleError(
                message: "Failed to load OpenAI models, error: \(error.localizedDescription), " + urlError
            )
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

            let requestData = OpenAIChatRequestData(from: chatRequest)
            var request = try OKRequest(
                route: .custom(path: "/v1/chat/completions", method: "POST"),
                body: requestData
            ).asURLRequest(baseURL: baseURL)

            setAuthorizationHeader(for: &request, with: modelAPI)

            let response = await OKHTTPClient.shared.stream(request: request, with: OpenAIChatResponse.self)

            for try await element in response {
                await handler(ChatCompletion.receiving(ChatResponse(from: element)))
            }

            await handler(ChatCompletion.finished)
        } catch {
            let urlError = error.localizedDescription
            let simpleError = SimpleError(message: "Stream terminated with error: " + urlError)
            await handler(ChatCompletion.failure(simpleError))
        }
    }
}

// MARK: - Request Data Structures

extension OpenAIService {
    struct OpenAIChatRequestData: Encodable {
        let model: String
        let messages: [OpenAIMessage]
        let stream: Bool
        let temperature: Float?
        let maxTokens: Int?
        let topP: Float?
        let seed: Int?

        struct OpenAIMessage: Encodable {
            let role: String
            let content: String
        }

        private enum CodingKeys: String, CodingKey {
            case model, messages, stream, temperature
            case maxTokens = "max_tokens"
            case topP = "top_p"
            case seed
        }

        init(from chatRequest: ChatRequest) {
            self.model = chatRequest.modelName
            self.stream = true

            var allMessages: [OpenAIMessage] = []

            // Add system prompt if enabled
            let modelParameter = chatRequest.modelParameter
            if modelParameter.enableSystemPrompt {
                allMessages.append(OpenAIMessage(
                    role: "system",
                    content: modelParameter.systemPrompt
                ))
            }

            // Convert chat messages
            let chatMessages = chatRequest.messages.map { message -> OpenAIMessage in
                let role: String
                switch message.role {
                case .user: role = "user"
                case .assistant: role = "assistant"
                case .system: role = "system"
                }

                let content = message.parts.compactMap { part -> String? in
                    if case .text(let text) = part {
                        return text
                    }
                    return nil
                }.joined()

                return OpenAIMessage(role: role, content: content)
            }

            allMessages.append(contentsOf: chatMessages)
            self.messages = allMessages

            // Set optional parameters
            self.temperature = modelParameter.enableTemperature ? modelParameter.temperature : nil
            self.maxTokens = modelParameter.enableOutputTokens ? modelParameter.outputTokens : nil
            self.topP = modelParameter.enableTopP ? modelParameter.topP : nil
            self.seed = modelParameter.enableSeed ? modelParameter.seed : nil
        }
    }
}

// MARK: - Response Data Structures

extension OpenAIService {
    struct OpenAIChatResponse: Decodable {
        let id: String?
        let object: String?
        let created: Int?
        let model: String
        let choices: [Choice]
        let usage: Usage?

        struct Choice: Decodable {
            let index: Int?
            let delta: Delta?
            let message: Message?
            let finishReason: String?

            struct Delta: Decodable {
                let role: String?
                let content: String?
            }

            struct Message: Decodable {
                let role: String?
                let content: String?
            }

            private enum CodingKeys: String, CodingKey {
                case index, delta, message
                case finishReason = "finish_reason"
            }
        }

        struct Usage: Decodable {
            let promptTokens: Int?
            let completionTokens: Int?
            let totalTokens: Int?

            private enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }

    struct OpenAIModelsResponse: Decodable {
        let object: String?
        let data: [OpenAIModel]

        struct OpenAIModel: Decodable {
            let id: String
            let object: String?
            let created: Int?
            let ownedBy: String?

            private enum CodingKeys: String, CodingKey {
                case id, object, created
                case ownedBy = "owned_by"
            }
        }
    }
}

// MARK: - ChatResponse Extension

extension ChatResponse {
    init(from openAIResponse: OpenAIService.OpenAIChatResponse) {
        // Extract text content from streaming delta or complete message
        let text: String
        if let choices = openAIResponse.choices.first {
            if let deltaContent = choices.delta?.content {
                text = deltaContent
            } else if let messageContent = choices.message?.content {
                text = messageContent
            } else {
                text = ""
            }
        } else {
            text = ""
        }

        self.model = openAIResponse.model
        self.createdAt = Date()
        self.message = text.isEmpty ? nil : ChatResponse.Message(
            role: .assistant,
            parts: [.text(text)]
        )

        // Check if generation is complete
        self.done = openAIResponse.choices.contains { $0.finishReason != nil }
        self.doneReason = openAIResponse.choices.first?.finishReason

        // Build statistics if usage data is available
        if let usage = openAIResponse.usage {
            self.chatStatics = ChatStatics(
                totalDuration: nil,
                loadDuration: nil,
                promptEvalCount: usage.promptTokens,
                promptEvalDuration: nil,
                evalCount: usage.completionTokens,
                evalDuration: nil
            )
        } else {
            self.chatStatics = nil
        }
    }
}
