import Foundation

actor GeminiService {
    static let shared = GeminiService()

    private func isInvalidConfig(modelAPI: ModelAPIDescriptor) async -> SimpleError? {
        guard !modelAPI.apiKey.isEmpty else {
            return SimpleError(message: "Gemini API init failed, apiKey is empty")
        }

        guard !modelAPI.endPoint.isEmpty else {
            return SimpleError(message: "Gemini API init failed, end point is empty")
        }

        return nil
    }

    private func setAuthorizationHeader(for request: inout URLRequest, with modelAPI: ModelAPIDescriptor) {
        if modelAPI.endPoint.lowercased().contains("openai") {
            request.setValue("Bearer \(modelAPI.apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue(modelAPI.apiKey, forHTTPHeaderField: "x-goog-api-key")
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

            var listRequest = try OKRequest<Never>(route: .models(["/models"]))
                .asURLRequest(baseURL: baseURL)
            
            setAuthorizationHeader(for: &listRequest, with: modelAPI)
            
            let models: [RemoteModel]
            
            if modelAPI.endPoint.lowercased().contains("openai") {
                let response: OpenAIModelsResponse = try await OKHTTPClient.shared.send(
                    request: listRequest,
                    with: OpenAIModelsResponse.self
                )
                
                models = response.data.map { openAIModel in
                    var meta = ModelMeta()
                    meta.description = "Owned by \(openAIModel.ownedBy ?? "unknown")"
                    if openAIModel.id.lowercased().contains("vision") {
                        meta.mediaSupport = true
                    }
                    
                    return RemoteModel(
                        name: openAIModel.id,
                        modelProvider: .gemini,
                        modelMeta: meta
                    )
                }
            } else {
                let response: GeminiModelsResponse = try await OKHTTPClient.shared.send(
                    request: listRequest,
                    with: GeminiModelsResponse.self
                )

                models = await withTaskGroup(of: RemoteModel?.self) { group in
                    for item in response.models {
                        group.addTask { [weak self] in
                            guard let self else { return nil }
                            let detail = await self.fetchGeminiModelDetail(modelAPI: modelAPI, baseURL: baseURL, modelName: item.name)
                            let meta = await self.buildModelMeta(from: detail ?? item, modelAPI: modelAPI)
                            return RemoteModel(
                                name: item.name.replacingOccurrences(of: "models/", with: ""),
                                modelProvider: .gemini,
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
            }
            await handler(.finished(models))
        } catch {
            var urlError = ""
            if let error = error as? URLError { urlError = "URLError Code: \(error.code)" }
            let simpleError = SimpleError(message: "Failed to load Gemini models, error: \(error) " + urlError + " apiKey: \(modelAPI.apiKey), endPoint: \(modelAPI.endPoint)")
            print(simpleError)
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
            
            let isOpenAIEndpoint = modelAPI.endPoint.lowercased().contains("openai")
            let request: URLRequest
            
            if isOpenAIEndpoint {
                let requestData = OpenAIChatRequestData(from: chatRequest)
                var req = try OKRequest(
                    route: .custom(path: "/v1/chat/completions", method: "POST"),
                    body: requestData
                ).asURLRequest(baseURL: baseURL)
                setAuthorizationHeader(for: &req, with: modelAPI)
                request = req
            } else {
                let requestData = GeminiChatRequestData(
                    from: chatRequest,
                    uploadedFiles: try await queryUploadedFiles(modelAPI: modelAPI)
                )
                var req = try OKRequest<GeminiChatRequestData>(
                    route: .modelInfo(["/models/\(chatRequest.modelName):streamGenerateContent"]),
                    body: requestData
                ).asURLRequest(baseURL: baseURL)
                setAuthorizationHeader(for: &req, with: modelAPI)
                request = req
            }


            /*if let body = request.httpBody, let jsonString = String(data: body, encoding: .utf8) {
                print("--- Sending JSON Payload ---")
                print("Chat request: \(jsonString)")
                print("--------------------------")
            }*/
            
            if isOpenAIEndpoint {
                let response = await OKHTTPClient.shared.stream(request: request, with: OpenAIChatResponse.self)
                for try await element in response {
                    await handler(ChatCompletion.receiving(ChatResponse(from: element)))
                }
            } else {
                let response = await OKHTTPClient.shared.stream(request: request, with: GeminiChatResponse.self)
                for try await element in response {
                    await handler(ChatCompletion.receiving(ChatResponse(from: element)))
                }
            }

            await handler(ChatCompletion.finished)
        } catch {
            let urlError = error.localizedDescription
            let simpleError = SimpleError(message: "Stream terminated with error: " + urlError)
            await handler(ChatCompletion.failure(simpleError))
        }
    }

    func uploadFile(
        modelAPI: ModelAPIDescriptor,
        for fileUploadRequest: FileUploadRequest,
        handler: @escaping @Sendable (FileUploadCompletion) async -> Void
    ) async {
        if modelAPI.endPoint.lowercased().contains("openai") {
            await handler(FileUploadCompletion.failure(SimpleError(message: "File upload is not supported for this endpoint.")))
            return
        }
        do {
            if let simpleError = await isInvalidConfig(modelAPI: modelAPI) {
                throw simpleError
            }

            let fileURL = fileUploadRequest.fileURL

            let currentHash = FileManager.default.sha256Base64(for: fileURL)

            let displayName = currentHash ?? fileURL.lastPathComponent

            if let uploadedFiles = try await queryUploadedFiles(modelAPI: modelAPI),
               let mathcedFile = getMatchedFileMeta(for: displayName, from: uploadedFiles) {
                await handler(FileUploadCompletion.finished(mathcedFile.uri))
                print("File \(fileURL) has been uploaded before.")
                return
            }

            let tmpPDFURL = await FileManager.default.convertToPDFIfNeeded(from: fileURL)

            defer {
                if let tmpPDFURL {
                    do {
                        try FileManager.default.removeItem(at: tmpPDFURL)
                        print("🗑️ Temporary PDF file cleaned up successfully via defer.")
                    } catch {
                        print("🚨 Error cleaning up temporary file: \(error)")
                    }
                }
            }

            guard let fileSize = FileManager.default.getFileSize(for: tmpPDFURL ?? fileURL) else {
                let simpleError = SimpleError(message: "Could not get file size or file does not exist")
                throw simpleError
            }

            guard let mimeType = FileManager.default.getMimeType(for: tmpPDFURL ?? fileURL) else {
                let simpleError = SimpleError(message: "Could not get file type")
                throw simpleError
            }

            let baseURL = URL(string: "https://generativelanguage.googleapis.com/upload/v1beta/files")!

            let metadata = GeminiUploadMetadataRequest(file: .init(displayName: displayName))

            let startRequest = try OKRequest(
                route: .custom(path: "", method: "POST"),
                body: metadata,
                headers: [
                    "X-Goog-Upload-Protocol": "resumable",
                    "X-Goog-Upload-Command": "start",
                    "X-Goog-Upload-Header-Content-Length": "\(fileSize)",
                    "X-Goog-Upload-Header-Content-Type": mimeType
                ]
            ).asURLRequest(baseURL: baseURL.appendingQuery(param: "key", value: modelAPI.apiKey)!)

            let (_, startResponse) = try await OKHTTPClient.shared.send(request: startRequest)

            guard let httpResponse = startResponse as? HTTPURLResponse,
                let uploadURLString = httpResponse.value(forHTTPHeaderField: "x-goog-upload-url"),
                let uploadURL = URL(string: uploadURLString) else {
                let simpleError = SimpleError(
                    message: "File API Step 1 failed: Did not receive a valid 'x-goog-upload-url' header."
                )
                await handler(FileUploadCompletion.failure(simpleError))
                return
            }

            //print("Returned uploadURL \(uploadURL)")

            let uploadRoute = OKRoute.custom(path: "", method: "POST")
            let uploadHeaders = [
                "Content-Length": "\(fileSize)",
                "X-Goog-Upload-Offset": "0",
                "X-Goog-Upload-Command": "upload, finalize"
            ]

            let uploadRequest = try OKRequest<Never>(route: uploadRoute, headers: uploadHeaders)
                .asURLRequest(baseURL: uploadURL)

            let uploadResponse: GeminiFileResponse = try await OKHTTPClient.shared.upload(
                request: uploadRequest,
                fromFile: tmpPDFURL ?? fileURL,
                progressHandler: fileUploadRequest.progressHandler
            )

            if uploadResponse.file.state != .active {
                print("File uploaded successfully, but status is \(uploadResponse.file.state.rawValue). Now waiting for it to become active...")

                let activeFile = try await waitForFileToBeActive(
                    modelAPI: modelAPI,
                    fileName: uploadResponse.file.name
                )

                await handler(.finished(activeFile.uri))

            } else {
                print("File uploaded and activated immediately!")
                await handler(.finished(uploadResponse.file.uri))
            }
        } catch {
            var urlError = ""
            if let error = error as? URLError {
                urlError = "URLError Code: \(error.code)"
            }
            let simpleError = SimpleError(
                message: "Upload file failed, error: \(error.localizedDescription), " + urlError
            )
            await handler(FileUploadCompletion.failure(simpleError))
        }
    }

    private func queryUploadedFiles(modelAPI: ModelAPIDescriptor) async throws -> [GeminiFile]? {
        if modelAPI.endPoint.lowercased().contains("openai") {
            return nil
        }
        do {
            guard let baseURL = URL(string: modelAPI.endPoint) else {
               throw SimpleError(message: "endpoint is invalid")
            }

            let queryURL = baseURL.appendingPathComponent("/files")

            let request = try OKRequest<Never>(
                route: .custom(path: "", method: "GET")
            ).asURLRequest(baseURL: queryURL.appendingQuery(param: "key", value: modelAPI.apiKey)!)

            let response: GeminiFileListResponse = try await OKHTTPClient.shared.send(
                request: request,
                with: GeminiFileListResponse.self
            )

            //print("response \(response)")
            return response.files
        } catch {
            print("queryUploadedFiles failed: \(error)")
            throw SimpleError(message: "queryUploadedFiles failed, \(error.localizedDescription)")
        }
    }

    private func getMatchedFileMeta(
        for fileHash: String,
        from uploadFiles: [GeminiFile]
    ) -> GeminiFile? {
        if let matchedFile = uploadFiles.first(
            where: { $0.displayName == fileHash && $0.state == .active }
        ) {
            return matchedFile
        }
        return nil
    }

    private func queryFileStatus(modelAPI: ModelAPIDescriptor, fileName: String) async -> GeminiFile? {
        do {
            guard let baseURL = URL(string: modelAPI.endPoint) else {
               throw SimpleError(message: "endpoint is invalid")
            }

            let queryURL = baseURL.appendingPathComponent("/\(fileName)")

            let request = try OKRequest<Never>(
                route: .custom(path: "", method: "GET")
            ).asURLRequest(baseURL: queryURL.appendingQuery(param: "key", value: modelAPI.apiKey)!)

            let response: GeminiFile = try await OKHTTPClient.shared.send(
                request: request,
                with: GeminiFile.self
            )

            //print("response \(response)")
            return response
        } catch {
            print("queryFileStatus failed: \(error)")
            return nil
        }
    }

    private func removeUploadedFile(modelAPI: ModelAPIDescriptor, fileName: String) async {
        do {
            let queryURL = URL(string: fileName)!

            let request = try OKRequest<Never>(
                route: .custom(path: "", method: "DELETE")
            ).asURLRequest(baseURL: queryURL.appendingQuery(param: "key", value: modelAPI.apiKey)!)

            let _: Void = try await OKHTTPClient.shared.send(request: request)

            print("🚨 Successfully deleted server file \(fileName)")
        } catch {
            print("🚨 Failed to delete server file \(fileName): \(error)")
        }
    }

    func waitForFileToBeActive(
        modelAPI: ModelAPIDescriptor,
        fileName: String,
        timeout: TimeInterval = 120.0
    ) async throws -> GeminiFile {
        let startTime = Date()
        var attempt = 0
        var delay: TimeInterval = 1.0

        while Date().timeIntervalSince(startTime) < timeout {
            if let fileInfo = await queryFileStatus(modelAPI: modelAPI, fileName: fileName) {
                switch fileInfo.state {
                case .active:
                    return fileInfo

                case .failed:
                    throw SimpleError(message: "File processing failed with status FAILED.")

                case .processing, .stateUnspecified:
                    break
                }

                attempt += 1

                let elapsedTime = Date().timeIntervalSince(startTime)
                if elapsedTime + delay > timeout {
                    throw SimpleError(message: "Wait for file activation timed out.")
                }
            }

            try await Task.sleep(for: .seconds(delay))

            delay = min(delay * 2, 15.0)
        }

        throw SimpleError(message: "Wait for file activation timed out.")
    }
}

extension GeminiService {
    struct GeminiChatRequestData: Encodable {
        let contents: [GeminiMessage]
        let systemInstruction: GeminiMessage?
        let generationConfig: GeminiGenerationConfig?

        init(from chatRequest: ChatRequest, uploadedFiles: [GeminiFile]?) {
            self.contents = chatRequest.messages.compactMap { message -> GeminiMessage? in
                var geminiRole: String

                switch message.role {
                case .user:
                    geminiRole = "user"
                case .assistant:
                    geminiRole = "model"
                case .system:
                    return nil
                }

                guard !message.parts.isEmpty else { return nil }

                //let geminiParts = message.parts.flatMap { part -> [GeminiPart] in
                var geminiParts: [GeminiPart] = []
                for part in message.parts {
                    switch part {
                    case .text(let text):
                        geminiParts.append(GeminiPart(text: text))

                    case .attachmentsData(let attachmentsData):
                        guard let attachmentsData, !attachmentsData.isEmpty,
                              let uploadedFiles, !uploadedFiles.isEmpty else { continue }

                        let matchedAttachments = attachmentsData.values.compactMap { attachment -> GeminiPart? in
                            guard let matched = uploadedFiles.first(where: {
                                $0.uri == attachment.url && $0.state == .active
                            }) else { return nil }

                            return GeminiPart(
                                file_data: .init(
                                    mime_type: matched.mimeType,
                                    file_uri: matched.uri
                                )
                            )
                        }

                        geminiParts.append(contentsOf: matchedAttachments)
                    }
                }

                guard !geminiParts.isEmpty else { return nil }

                return GeminiMessage(
                    role: geminiRole,
                    parts: geminiParts
                )
            }

            let modelParameter = chatRequest.modelParameter
            if modelParameter.enableSystemPrompt {
                self.systemInstruction = GeminiMessage(
                    role: "user",
                    parts: [GeminiPart(text: modelParameter.systemPrompt)]
                )
            } else {
                self.systemInstruction = nil
            }

            self.generationConfig = GeminiGenerationConfig(
                maxOutputTokens: modelParameter.enableOutputTokens ? modelParameter.outputTokens : nil,
                temperature: modelParameter.enableTemperature ? modelParameter.temperature : nil,
                topP: modelParameter.enableTopP ? modelParameter.topP : nil,
                topK: modelParameter.enableTopK ? modelParameter.topK : nil,
                seed: modelParameter.enableSeed ? modelParameter.seed : nil,
                repetitionPenalty: modelParameter.enableRepetitionPenalty ? modelParameter.repetitionPenalty : nil,
                includeThoughts: modelParameter.thinking,
                thinkingBudget: -1
            )

            //print("generationConfig: \(String(describing: generationConfig))")
            //print("modelParameter: \(modelParameter)")
        }

        struct GeminiMessage: Encodable {
            let role: String
            let parts: [GeminiPart]
        }

        struct GeminiPart: Encodable {
            let text: String?
            let file_data: GeminiFileData?

            struct GeminiFileData: Encodable {
                let mime_type: String
                let file_uri: String
            }

            init(text: String? = nil, file_data: GeminiFileData? = nil) {
                self.text = text
                self.file_data = file_data
            }
        }

        struct GeminiGenerationConfig: Encodable {
            struct ThinkingConfig: Encodable {
                let includeThoughts: Bool
                let thinkingBudget: Int?
            }

            let maxOutputTokens: Int?
            let temperature: Float?
            let topP: Float?
            let topK: Int?
            let seed: Int?
            let repetitionPenalty: Float?
            var thinkingConfig: ThinkingConfig?

            init(
                maxOutputTokens: Int? = nil,
                temperature: Float? = nil,
                topP: Float? = nil,
                topK: Int? = nil,
                seed: Int? = nil,
                repetitionPenalty: Float? = nil,
                includeThoughts: Bool = false,
                thinkingBudget: Int? = nil
            ) {
                let thingkingConfig = includeThoughts ?
                        ThinkingConfig(includeThoughts: true, thinkingBudget: thinkingBudget) : nil
                self.thinkingConfig = thingkingConfig
                self.maxOutputTokens = maxOutputTokens
                self.temperature = temperature
                self.topP = topP
                self.topK = topK
                self.seed = seed
                self.repetitionPenalty = repetitionPenalty
                self.thinkingConfig = thingkingConfig
            }
        }
    }

    struct OpenAIChatRequestData: Encodable {
        let model: String
        let messages: [OpenAIMessage]
        let stream: Bool = true
        
        struct OpenAIMessage: Encodable {
            let role: String
            let content: String
        }
        
        init(from chatRequest: ChatRequest) {
            self.model = chatRequest.modelName
            self.messages = chatRequest.messages.map {
                var role: String
                switch $0.role {
                case .user: role = "user"
                case .assistant: role = "assistant"
                case .system: role = "system"
                }
                
                let content = $0.parts.compactMap { part -> String? in
                    if case .text(let text) = part {
                        return text
                    }
                    return nil
                }.joined()
                
                return OpenAIMessage(role: role, content: content)
            }
        }
    }

    struct OpenAIChatResponse: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
                let role: String?
            }
            let delta: Delta
            let finishReason: String?
            private enum CodingKeys: String, CodingKey {
                case delta
                case finishReason = "finish_reason"
            }
        }
        let choices: [Choice]
        let model: String
    }


    struct OpenAIModelsResponse: Decodable {
        let data: [OpenAIModel]

        struct OpenAIModel: Decodable {
            let id: String
            let object: String
            let created: TimeInterval?
            let ownedBy: String?

            private enum CodingKeys: String, CodingKey {
                case id, object, created
                case ownedBy = "owned_by"
            }
        }
    }

    struct GeminiChatResponse: Decodable {
        let candidates: [GeminiCandidate]
        let usageMetadata: UsageMetadata?

        struct GeminiCandidate: Decodable {
            let content: GeminiContent
            let finishReason: String?

            struct GeminiContent: Decodable {
                let role: String
                let parts: [GeminiPart]

                struct GeminiPart: Decodable {
                    enum PartType: String, Codable {
                        case text
                        case inlineData
                        case fileData
                    }

                    var type: PartType?
                    var text: String?
                    var inlineData: InlineData?
                    var fileData: FileData?

                    private enum CodingKeys: String, CodingKey {
                        case text
                        case inlineData
                        case fileData
                    }

                    init(from decoder: Decoder) {
                        do {
                            let container = try decoder.container(keyedBy: CodingKeys.self)
                            if container.contains(.text) {
                                self.type = .text
                                self.text = try container.decode(String.self, forKey: .text)
                                self.inlineData = nil
                                self.fileData = nil
                            } else if container.contains(.inlineData) {
                                self.type = .inlineData
                                self.text = nil
                                self.inlineData = try container.decode(InlineData.self, forKey: .inlineData)
                                self.fileData = nil
                            } else if container.contains(.fileData) {
                                self.type = .fileData
                                self.text = nil
                                self.inlineData = nil
                                self.fileData = try container.decode(FileData.self, forKey: .fileData)
                            }
                        } catch {
                            self.type = nil
                            self.text = nil
                            self.inlineData = nil
                            self.fileData = nil
                        }
                    }

                    struct InlineData: Decodable {
                        let mimeType: String
                        let data: String
                    }

                    struct FileData: Decodable {
                        let mimeType: String
                        let fileUri: String
                    }
                }
            }
        }

        struct UsageMetadata: Decodable {
            let promptTokenCount: Int
            let candidatesTokenCount: Int
            let totalTokenCount: Int
        }
    }

    struct GeminiModelsResponse: Decodable {
        let models: [GeminiModel]

        struct GeminiModel: Decodable {
            let name: String
            let baseModelId: String?
            let version: String?
            let displayName: String?
            let description: String?
            let inputTokenLimit: Int?
            let outputTokenLimit: Int?
            let supportedGenerationMethods: [String]?
            let thinking: Bool?
            let temperature: Float?
            let maxTemperature: Float?
            let topP: Float?
            let topK: Int?
        }
    }

    struct GeminiUploadMetadataRequest: Encodable {
        struct FileMetadata: Encodable {
            let displayName: String
            private enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
            }
        }
        let file: FileMetadata
    }

    struct GeminiFile: Decodable, Sendable {
        let name: String
        let displayName: String?
        let mimeType: String
        let sizeBytes: String
        let createTime: String
        let updateTime: String?
        let expirationTime: String?
        let sha256Hash: String
        let uri: String
        let downloadUri: String?
        let state: FileState
        let source: FileSource?
        let videoMetadata: VideoFileMetadata?

        enum FileState: String, Codable {
            case stateUnspecified = "STATE_UNSPECIFIED"
            case processing = "PROCESSING"
            case active = "ACTIVE"
            case failed = "FAILED"
        }

        enum FileSource: String, Codable {
            case sourceUnspecified = "SOURCE_UNSPECIFIED"
            case uploaded = "UPLOADED"
            case generated = "GENERATED"
        }

        struct VideoFileMetadata: Codable {
            let videoDuration: String
        }
    }

    struct GeminiFileResponse: Decodable, Sendable {
        let file: GeminiFile
    }

    struct GeminiFileListResponse: Decodable, Sendable {
        let files: [GeminiFile]?
    }
}

extension ChatResponse {
    init(from geminiResponse: GeminiService.GeminiChatResponse) {
        let allParts = geminiResponse.candidates.flatMap { candidate in
            candidate.content.parts.compactMap { part in
                if let text = part.text {
                    return OutputPart.text(text)
                } else if let inlineData = part.inlineData,
                          let data = Data(base64Encoded: inlineData.data) {
                    return OutputPart.inlineMedia(mimeType: inlineData.mimeType, data: data)
                } else if let fileData = part.fileData {
                    return OutputPart.fileMedia(mimeType: fileData.mimeType, fileUri: fileData.fileUri)
                } else {
                    return nil
                }
            }
        }

        let deduplicatedParts: [OutputPart] = {
            var seenTexts = Set<String>()
            return allParts.compactMap {
                if case let .text(text) = $0 {
                    guard !seenTexts.contains(text) else { return nil }
                    seenTexts.insert(text)
                }
                return $0
            }
        }()

        self.model = ""
        self.createdAt = Date()
        self.message = deduplicatedParts.isEmpty ? nil : ChatResponse.Message(
            role: .assistant,
            parts: deduplicatedParts
        )

        self.done = geminiResponse.candidates.contains { $0.finishReason != nil }
        self.doneReason = geminiResponse.candidates.last?.finishReason

        var chatStatics: ChatStatics?
        if let usageMetadata = geminiResponse.usageMetadata {
            chatStatics = ChatStatics(
                totalDuration: nil,
                loadDuration: nil,
                promptEvalCount: usageMetadata.promptTokenCount,
                promptEvalDuration: nil,
                evalCount: usageMetadata.candidatesTokenCount,
                evalDuration: nil
            )
        }
        self.chatStatics = chatStatics
    }
    
    init(from openAIResponse: GeminiService.OpenAIChatResponse) {
        let text = openAIResponse.choices.compactMap { $0.delta.content }.joined()
        self.model = openAIResponse.model
        self.createdAt = Date()
        self.message = text.isEmpty ? nil : .init(role: .assistant, parts: [.text(text)])
        self.done = openAIResponse.choices.contains { $0.finishReason != nil }
        self.doneReason = openAIResponse.choices.last?.finishReason
        self.chatStatics = nil
    }
}

private extension GeminiService {
    func fetchGeminiModelDetail(modelAPI: ModelAPIDescriptor, baseURL: URL, modelName: String) async -> GeminiModelsResponse.GeminiModel? {
        do {
            let path = "/\(modelName)"
            var req = try OKRequest<Never>(route: .modelInfo([path])).asURLRequest(baseURL: baseURL)
            setAuthorizationHeader(for: &req, with: modelAPI)
            let detail: GeminiModelsResponse.GeminiModel = try await OKHTTPClient.shared.send(request: req, with: GeminiModelsResponse.GeminiModel.self)
            return detail
        } catch {
            return nil
        }
    }

    func buildModelMeta(from model: GeminiModelsResponse.GeminiModel, modelAPI: ModelAPIDescriptor) async -> ModelMeta {
        var meta = ModelMeta()
        meta.inputTokenLimit = model.inputTokenLimit
        meta.outputTokenLimit = model.outputTokenLimit
        meta.maxTemperature = model.maxTemperature
        meta.temperature = model.temperature
        meta.topP = model.topP
        meta.topK = model.topK
        meta.version = model.version
        meta.description = model.description
        //meta.thingking = model.thinking ?? false
        meta.thingking = false
        meta.seed = true
        if let methods = model.supportedGenerationMethods {
            if methods.contains(where: { $0.localizedCaseInsensitiveContains("multimodal") || $0.localizedCaseInsensitiveContains("image") || $0.localizedCaseInsensitiveContains("file") }) {
                meta.mediaSupport = true
            }
        }
        if meta.mediaSupport == false, let desc = model.description?.lowercased() {
            if ["image","multi-modal","multimodal","vision","file","video","audio"].contains(where: { desc.contains($0) }) { meta.mediaSupport = true }
        }
        let nameLower = model.name.lowercased()
        if meta.mediaSupport == false {
            if ["vision","flash","pro","pro-vision"].contains(where: { nameLower.contains($0) }) {
                if nameLower.contains("gemini") { meta.mediaSupport = true }
            }
        }
        if meta.mediaSupport == false, let alt = (model.displayName ?? model.baseModelId)?.lowercased() {
            if ["vision","image","video","audio","multimodal","multi-modal"].contains(where: { alt.contains($0) }) { meta.mediaSupport = true }
        }

        if meta.mediaSupport == false {
            meta.mediaSupport = await probeImageSupport(modelAPI: modelAPI, modelName: model.name)
        }

        //if let sizeString = model.displayName ?? model.baseModelId {
        //    if let parsed = parseModelSize(from: sizeString) { meta.modelSize = parsed }
        //}
        return meta
    }

    func parseModelSize(from text: String) -> Int? {
        let pattern = "([0-9]+(?:\\.[0-9]+)?)([BMbm])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges == 3 else { return nil }
        if let numRange = Range(match.range(at: 1), in: text), let unitRange = Range(match.range(at: 2), in: text) {
            let numberString = String(text[numRange])
            let unit = String(text[unitRange]).uppercased()
            guard let value = Double(numberString) else { return nil }
            let multiplier: Double = (unit == "B") ? 1_000_000_000 : 1_000_000
            return Int(value * multiplier)
        }
        return nil
    }

    private func probeImageSupport(
        modelAPI: ModelAPIDescriptor,
        modelName: String
    ) async -> Bool {
        guard let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==")
        else { return false }

        struct ProbePart: Encodable {
            let inlineData: InlineData
            struct InlineData: Encodable {
                let mimeType: String
                let data: String
            }
        }
        struct ProbeContent: Encodable {
            let role: String
            let parts: [ProbePart]
        }
        struct ProbeRequest: Encodable {
            let contents: [ProbeContent]
        }

        let reqBody = ProbeRequest(
            contents: [
                ProbeContent(
                    role: "user",
                    parts: [
                        ProbePart(
                            inlineData: .init(
                                mimeType: "image/png",
                                data: tinyPNG.base64EncodedString()
                            )
                        )
                    ]
                )
            ]
        )

        do {
            guard let baseURL = URL(string: modelAPI.endPoint) else { return false }
            var request = try OKRequest<ProbeRequest>(
                route: .modelInfo(["/models/\(modelName):streamGenerateContent"]),
                body: reqBody
            ).asURLRequest(baseURL: baseURL)
            setAuthorizationHeader(for: &request, with: modelAPI)

            let stream = await OKHTTPClient.shared.stream(request: request, with: GeminiChatResponse.self)
            for try await chunk in stream {
                if chunk.candidates.contains(where: { candidate in
                    candidate.content.parts.contains { $0.text?.isEmpty == false }
                }) {
                    return true
                }
                if chunk.candidates.isEmpty && chunk.usageMetadata != nil {
                    continue
                }
            }
            return false
        } catch {
            return false
        }
    }
}
