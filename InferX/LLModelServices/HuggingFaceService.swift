//
//  HuggingFaceService.swift
//  InferX
//
//  Created by mingdw on 2025/6/28.
//

import Alamofire
import Foundation
import Defaults
import MLXLMCommon
import MLX
import MLXLLM
import Tokenizers
import AsyncAlgorithms

typealias RemoteHFModel = HuggingFaceModel

struct TagPair: Hashable {
    let start: String
    let end: String
}

struct LocalHFModel: Sendable, Hashable {
    let id: String
    let createdAt: Date
    let repoURL: URL
    let snapshotPath: URL
    let lastCommit: String
    let expectedFiles: [String]
    let fileNames: [String]
    let fileCount: Int
    let totalSize: Int
    let status: Status

    enum Status: Equatable, Sendable, Hashable {
        case inCache
        case inComplete(missingFiles: [String])
        case needsUpdate
    }
}

private struct HFConfig: Decodable {
    let max_position_embeddings: Int?
    let n_ctx: Int?
    let context_length: Int?
    let seq_length: Int?
    let rope_scaling: RopeScaling?
    let hidden_size: Int?
    let num_hidden_layers: Int?
    let _commit_hash: String?
    let vision_tower: String?
    let vision_config: VisionConfig?
    let image_size: Int?
    let processor_config: ProcessorConfig?
    struct RopeScaling: Decodable { let factor: Double?; let original_max_position_embeddings: Int? }
    struct VisionConfig: Decodable { let image_size: Int? }
    struct ProcessorConfig: Decodable { let image_size: Int? }
}

private struct HFGenerationConfig: Decodable {
    let max_new_tokens: Int?
    let temperature: Float?
    let top_p: Float?
    let top_k: Int?
    let seed: Int?
}

private enum HFMetaParser { static let decoder = JSONDecoder() }

actor HuggingFaceService {
    static let shared = HuggingFaceService()

    private var localModels: [String: [LocalHFModel]] = [:]
    private var nextUrl: URL?
    private var imageProbeCache: [String: Bool] = [:]

    func getModels(
        modelAPI: ModelAPIDescriptor,
        handler: @escaping @Sendable (ModelsCompletion) async -> Void
    ) async {
        var localModels = self.localModels[modelAPI.name] ?? []
        if localModels.isEmpty {
            cleanupStaleLocks(cacheDir: modelAPI.cacheDir)
            do {
                localModels = try await self.updateLocalHFModelsFromCache(modelAPI: modelAPI)
            } catch(let errors) {
                let simpleError = SimpleError(message: "\(errors.localizedDescription)")
                await handler(.failure(simpleError))
                return
            }
        }

        let models = await withTaskGroup(of: RemoteModel?.self) { group in
            for m in localModels where m.status == .inCache {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    let meta = await self.buildModelMeta(for: m, cacheDir: modelAPI.cacheDir)
                    return RemoteModel(name: m.id, modelProvider: .huggingFace, modelMeta: meta)
                }
            }

            var collectedModels: [RemoteModel] = []
            for await model in group.compactMap({ $0 }) {
                collectedModels.append(model)
            }

            return collectedModels
        }
        await handler(.finished(models))
    }

    func chatModel(
        modelAPI: ModelAPIDescriptor,
        for chatRequest: ChatRequest,
        handler: @escaping @Sendable (ChatCompletion) async -> Void
    ) async {

        let modelId = chatRequest.modelName

        do {
            guard let url = modelAPI.cacheDir else {
                throw SimpleError(message: "Model cache directory not set. Please specify it in application settings.")
            }

            guard let url = FileManager.default.securityAccessFile(url: url) else {
                throw SimpleError(message: "Could not activate security-scoped access to \(url.path) in chatModel.")
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            guard let localModel = self.localModels[modelAPI.name]?.first(where: {
                $0.id == modelId
            }) else {
                throw SimpleError(message: "No HF model available \(modelId).")
            }
            
            guard let lastMessage = chatRequest.messages.last, lastMessage.role == .user else {
                throw SimpleError(message: "The last message in the chat history is not from the user.")
            }

            var messages = chatRequest.messages.map { message in
                var content: String = ""
                for part in message.parts {
                    switch part {
                    case .text(let textContent):
                        content = textContent

                    case .attachmentsData(_): break
                    }
                }

                switch message.role {
                case .assistant:
                    return Chat.Message.assistant(content)
                case .system:
                    return Chat.Message.system(content)
                case .user:
                    return Chat.Message.user(content)
                }
            }

            let modelParameter = chatRequest.modelParameter
            if modelParameter.enableSystemPrompt {
                let systemMessage = Chat.Message.system(modelParameter.systemPrompt)
                messages.insert(systemMessage, at: 0)
            }

            print("Chat HF model: \(localModel.repoURL.path)")

            let generateParameters = GenerateParameters(
                maxTokens: modelParameter.outputTokens,
                temperature: modelParameter.temperature,
                topP: modelParameter.topP,
                repetitionPenalty: modelParameter.repetitionPenalty
            )

            let stream = try await LLMEvaluator.shared.generate(
                dir: localModel.snapshotPath,
                chat: messages,
                cacheLimit: Int(Defaults[.gpuCacheLimit]) * 1024,
                seed: Double(modelParameter.seed),
                enableThinking: modelParameter.thinking,
                generateParameters: generateParameters
            )

            for await batch in stream._throttle(
                for: Duration.seconds(0.25),
                reducing: Generation.collect
            )
            {
                let output = batch.compactMap { $0.chunk }.joined(separator: "")
                let generateCompletionInfo = batch.compactMap({ $0.info }).first
                let processedOutput = replaceTags(in: output, parameter: modelParameter)
                //print("output: \(output)\nprocessedOutput: \(processedOutput)\ninfo: \(String(describing: generateCompletionInfo))\n")
                print("output: \(processedOutput)")
                let streamingResponse = ChatResponse(
                    text: processedOutput,
                    modelId: modelId,
                    done: generateCompletionInfo != nil ? true : false,
                    generateCompletionInfo: generateCompletionInfo
                )
                await handler(.receiving(streamingResponse))
                /*
                if let toolCall = batch.compactMap({ $0.toolCall }).first {
                    try await handleToolCall(toolCall, prompt: prompt)
                }*/
            }
            await handler(.finished)
        } catch let simpleError as SimpleError {
            await handler(.failure(simpleError))
        } catch {
            await handler(.failure(SimpleError(message: "Error generating response: \(modelId), \(error.localizedDescription)")))
        }
    }
}

extension HuggingFaceService {
    private func createLocalModel(
        modelAPI: ModelAPIDescriptor,
        from repo: CachedRepoInfo
    ) async throws -> LocalHFModel? {
        if let latestRevision = repo.revisions.max(by: { $0.lastModified < $1.lastModified }) {
            let localFiles = latestRevision.files.map { $0.fileName }.sorted()
            var expectedFiles: [String]? = nil
            var lastCommit: String? = nil
            let remoteModelInfo = try await self.getRemoteHFModel(
                modelAPI: modelAPI,
                repoId: repo.repoId
            )

            expectedFiles = remoteModelInfo.siblings?
                .filter { sibling in
                    let filename = sibling.rfilename
                    let isNotHidden = !filename.hasPrefix(".")
                    let isNotReadme = (filename.lowercased() != "readme.md")
                    return isNotHidden && isNotReadme
                }
                .map { $0.rfilename }
            lastCommit = remoteModelInfo.sha

            var status: LocalHFModel.Status = .inCache
            if let expectedFiles {
                let missingFiles = Array(Set(expectedFiles).subtracting(Set(localFiles)))
                if !missingFiles.isEmpty {
                    status = .inComplete(missingFiles: missingFiles)
                }
            } else if let lastCommit, lastCommit != latestRevision.commitHash
                        || localFiles.isEmpty {
                status = .needsUpdate
            }

            let localModel = LocalHFModel(
                id: repo.repoId,
                createdAt: Date(timeIntervalSince1970: latestRevision.lastModified),
                repoURL: repo.repoPath,
                snapshotPath: latestRevision.snapshotPath,
                lastCommit: latestRevision.commitHash,
                expectedFiles: expectedFiles ?? [],
                fileNames: latestRevision.files.map { $0.fileName }.sorted(),
                fileCount: latestRevision.files.count,
                totalSize: latestRevision.sizeOnDisk,
                status: status
            )

            //print("createLocalModel: repo: \(repo.repoId), repoURL: \(repo.repoPath), lastModified:  \(latestRevision.lastModified)")
            return localModel
        } else {
            return nil
        }
    }

    func updateLocalHFModelsFromCache(modelAPI: ModelAPIDescriptor) async throws -> [LocalHFModel] {
        guard let cacheDir = modelAPI.cacheDir else {
            let simpleError = SimpleError(message: "Model cache directory not set. Please specify it in application settings.")
            print("\(simpleError.localizedDescription)")
            throw simpleError
        }

        guard let cacheDir = FileManager.default.securityAccessFile(url: cacheDir) else {
            let simpleError = SimpleError(message: "Could not activate security-scoped access to \(cacheDir.path) in updateLocalHFModelsFromCache.")
            print("\(simpleError.localizedDescription)")
            throw simpleError
        }

        defer {
            cacheDir.stopAccessingSecurityScopedResource()
        }

        let hfCacheInfo = try CacheManager(cacheDir: cacheDir).scanCacheDir()

        var localModels: [LocalHFModel] = []

        for repo in hfCacheInfo.repos {
            if let localModel = try await createLocalModel(modelAPI: modelAPI, from: repo),
               !localModels.contains(where: { $0.id == localModel.id }) {
                localModels.append(localModel)
            }
        }

        self.localModels[modelAPI.name] = localModels
        self.localModels[modelAPI.name]?.sort( by: { $0.createdAt > $1.createdAt } )
        return localModels
    }

    func getLocalHFModels(modelAPI: ModelAPIDescriptor) async throws -> [LocalHFModel] {
        var localModels = self.localModels[modelAPI.name] ?? []

        if localModels.isEmpty {
            cleanupStaleLocks(cacheDir: modelAPI.cacheDir)

            localModels = try await self.updateLocalHFModelsFromCache(modelAPI: modelAPI)
        }

        return localModels
    }

    func addLocalHFModel(modelAPI: ModelAPIDescriptor, for repo: URL) async throws {
        guard let cacheDir = modelAPI.cacheDir else {
            let simpleError = SimpleError(message: "Model cache directory not set. Please specify it in application settings.")
            print("\(simpleError.localizedDescription)")
            throw simpleError
        }

        guard let cacheDir = FileManager.default.securityAccessFile(url: cacheDir) else {
            let simpleError = SimpleError(message: "Could not activate security-scoped access to \(cacheDir.path) in addLocalHFModel.")
            print("\(simpleError.localizedDescription)")
            throw simpleError
        }

        defer {
            cacheDir.stopAccessingSecurityScopedResource()
        }

        //repo is appended snapshots, needs to remove it
        let repoInfo = try CacheManager(cacheDir: cacheDir).scanCachedRepo(repo)

        var localModels = self.localModels[modelAPI.name] ?? []

        if let localModel = try await createLocalModel(modelAPI: modelAPI, from: repoInfo) {
            localModels.removeAll(where: { $0.id == localModel.id })
            localModels.append(localModel)
        }

        self.localModels[modelAPI.name] = localModels
        self.localModels[modelAPI.name]?.sort( by: { $0.createdAt > $1.createdAt } )
    }

    func getRemoteHFModels(
        modelAPI: ModelAPIDescriptor,
        loadMore: Bool = false,
        search: String? = nil,
        sortValue: String = "",
        limit: String = "20",
        direction: String = "-1",
        filter: String = "mlx"
    ) async throws
    -> [RemoteHFModel] {

        guard !modelAPI.endPoint.isEmpty else {
            throw SimpleError(message: "HFApi endpoint is null")
        }

        let hfApi = HFApi(endpoint: modelAPI.endPoint, token: modelAPI.apiKey)

        do {
            let result: (models: [HuggingFaceModel], nextUrl: URL?)
            if loadMore, let nextUrl = self.nextUrl {
                result = try await hfApi.listModels(nextPageUrl: nextUrl)
            } else {
                result = try await hfApi.listModels(
                    search: search,
                    sort: sortValue,
                    limit: limit,
                    direction: direction,
                    filter: filter
                )
            }

            self.nextUrl = result.nextUrl
            return result.models
        } catch {
            var urlError = ""
            if let error = error as? URLError {
                urlError = "URLError Code: \(error.code)"
            }
            throw SimpleError(message: "Failed to access HuggingFace models, error: \(error) " + urlError)
        }
    }

    func getRemoteHFModel(modelAPI: ModelAPIDescriptor, repoId: String) async throws -> RemoteHFModel {
        guard !modelAPI.endPoint.isEmpty else {
            throw SimpleError(message: "HFApi endpoint is null")
        }

        let hfApi = HFApi(endpoint: modelAPI.endPoint, token: modelAPI.apiKey)

        do {
            return try await hfApi.getRemoteModelInfo(repoId: repoId)
        } catch {
            var urlError = ""
            if let error = error as? URLError {
                urlError = "URLError Code: \(error.code)"
            }
            throw SimpleError(message: "Failed to access HuggingFace model \(repoId), error: \(error) " + urlError)
        }
    }

    func snapshotDownloader(
        modelAPI: ModelAPIDescriptor,
        repoId: String,
        repoType: RepoType,
        progressHandler: @Sendable @escaping (ExtendedProgresss) -> Void
    ) -> SnapshotDownloader? {
        guard !modelAPI.endPoint.isEmpty else {
            print("HFApi endpoint is null")
            return nil
        }

        guard let cacheDir = modelAPI.cacheDir else {
            print("HFApi cacheDir is null")
            return nil
        }

        let options = SnapshotDownloader.Options(
            repoType: repoType,
            cacheDir: cacheDir,
            endpoint: modelAPI.endPoint,
            onProgress: progressHandler
        )

        return SnapshotDownloader(repoId: repoId, options: options)
    }

    func deleteRepo(modelAPI: ModelAPIDescriptor, repoId: String) throws {
        let model = self.localModels[modelAPI.name]?.first { $0.id == repoId }
        guard let modelDir = model?.repoURL else { return }

        guard let cacheDir = modelAPI.cacheDir,
              let cacheDir = FileManager.default.securityAccessFile(url: cacheDir) else {
            let simpleError = SimpleError(message: "Could not activate security-scoped access to \(modelDir.path) in deleteRepo.")
            print("\(simpleError.localizedDescription)")
            throw simpleError
        }

        defer {
            cacheDir.stopAccessingSecurityScopedResource()
        }

        if FileManager.default.fileExists(atPath: modelDir.path) {
            try FileManager.default.removeItem(at: modelDir)
            print("Files for model '\(repoId)' have been successfully deleted.")
        }

        self.localModels[modelAPI.name]?.removeAll { $0.id == repoId }
    }

    private func parseTagConfig(from configString: String?) -> [TagPair]? {
        guard let configString else { return nil }
        return configString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { pairString -> TagPair? in
                let components = pairString.split(separator: " ", maxSplits: 1).map(String.init)
                if components.count == 2 {
                    return TagPair(start: components[0], end: components[1])
                }
                return nil
            }
    }

    private func replaceTags(
        in chunk: String,
        parameter: ModelParameter,
        internalStartTag: String = "<think>",
        internalEndTag: String = "</think>"
    ) -> String {
        
        //if parameter.thinking && !chunk.contains("<think>") {
        //    return "<think>" + chunk
        //}

        return chunk
    }

    private func cleanupStaleLocks(cacheDir: URL?) {
        guard let cacheDir,
                let cacheDir = FileManager.default.securityAccessFile(url: cacheDir) else {
            print("Error: Could not activate security-scoped access to \(String(describing: cacheDir?.path)) in cleanupStaleLocks.")
            return
        }

        defer {
            cacheDir.stopAccessingSecurityScopedResource()
        }

        do {
            let locksDir = cacheDir.appendingPathComponent(".locks")

            if FileManager.default.fileExists(atPath: locksDir.path) {
                print("App starting, cleaning up stale lock directory at: \(locksDir.path)")
                try FileManager.default.removeItem(at: locksDir)
            }
        } catch {
            print("⚠️ Failed to clean up stale locks on startup: \(error.localizedDescription)")
        }
    }
}

struct HuggingFaceModelsResponse: Decodable, Sendable {
    let models: [HuggingFaceModel]
}

extension ChatResponse {
    init(text: String,
         modelId: String,
         done: Bool,
         doneReason: String? = nil,
         generateCompletionInfo: GenerateCompletionInfo?
    ) {
        self.model = modelId
        self.createdAt = Date()
        self.message = Message(role: .assistant, parts: [.text(text)])
        self.done = done
        self.doneReason = doneReason

        var chatStatics: ChatStatics?
        if let generateCompletionInfo {
            chatStatics = ChatStatics(
                totalDuration: nil,
                loadDuration: nil,
                promptEvalCount: generateCompletionInfo.promptTokenCount,
                promptEvalDuration: generateCompletionInfo.promptTime,
                evalCount: generateCompletionInfo.generationTokenCount,
                evalDuration: generateCompletionInfo.generateTime
            )
        }
        self.chatStatics = chatStatics
    }
}

private extension HuggingFaceService {
    func probeImageSupport(at dir: URL) -> Bool {
        let indicatorFiles = [
            "vision_config.json",
            "processor_config.json",
            "preprocessor_config.json",
            "image_processor.json"
        ]
        for f in indicatorFiles {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent(f).path) { return true }
        }
        if let readme = try? String(contentsOf: dir.appendingPathComponent("README.md"), encoding: .utf8) {
            let lower = readme.lowercased()
            if ["vision","image","multimodal","multi-modal","pixtral","camera"].contains(where: { lower.contains($0) }) {
                return true
            }
        }
        return false
    }

    func activeInlineImageProbe(localModel: LocalHFModel) async -> Bool {
        if let cached = imageProbeCache[localModel.id] { return cached }
        let tinyBase64PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7lX9kAAAAASUVORK5CYII="
        let prompt = Chat.Message.user("Please analyze this image: <image data='" + tinyBase64PNG + "' />")
        do {
            let params = GenerateParameters(maxTokens: 8, temperature: 0.0, topP: 0.9, repetitionPenalty: 1.0)
            let stream = try await LLMEvaluator.shared.generate(
                dir: localModel.snapshotPath,
                chat: [prompt],
                cacheLimit: Int(Defaults[.gpuCacheLimit]) * 1024,
                seed: 0,
                enableThinking: false,
                generateParameters: params
            )
            for await _ in stream { break }
            imageProbeCache[localModel.id] = true
            return true
        } catch {
            imageProbeCache[localModel.id] = false
            return false
        }
    }

    func buildModelMeta(for localModel: LocalHFModel, cacheDir: URL?) async -> ModelMeta {
        var meta = ModelMeta()
        let dir = localModel.snapshotPath

        guard let cacheDir = FileManager.default.securityAccessFile(url: cacheDir) else {
            let simpleError = SimpleError(message: "Could not activate security-scoped access to \(String(describing: cacheDir?.path)) in buildModelMeta.")
            print("\(simpleError.localizedDescription)")
            return ModelMeta()
        }

        defer {
            cacheDir.stopAccessingSecurityScopedResource()
        }
        
        func loadData(_ name: String) -> Data? {
            let url = dir.appendingPathComponent(name)
            return try? Data(contentsOf: url, options: .mappedIfSafe)
        }
        func loadJSON<T: Decodable>(_ name: String, as type: T.Type) -> T? {
            guard let d = loadData(name) else {
                print("❌ [loadJSON] Failed to load data for file: \(name)")
                return nil
            }
            do {
                return try HFMetaParser.decoder.decode(T.self, from: d)
            } catch {
                print("❌ [loadJSON] Failed to decode \(name). Error: \(error)")
                return nil
            }
        }

        struct HFTextConfig: Decodable {
            let vocab_size: Int?
            let max_position_embeddings: Int?
            let hidden_size: Int?
            let intermediate_size: Int?
            let num_hidden_layers: Int?
            let num_attention_heads: Int?
            let num_key_value_heads: Int?
            let sliding_window: Int?
            let head_dim: Int?
            let rope_theta: Double?
            let bos_token_id: Int?
            let eos_token_id: Int?
            let pad_token_id: Int?
            let temperature: Float?
            let top_k: Int?
            let top_p: Float?
            let repetition_penalty: Float?
        }
        struct HFRichConfig: Decodable { let text_config: HFTextConfig?; let vision_config: HFConfig.VisionConfig? }

        let cfg: HFConfig? = loadJSON("config.json", as: HFConfig.self)
        let gen: HFGenerationConfig? = loadJSON("generation_config.json", as: HFGenerationConfig.self)
        let rich: HFRichConfig? = loadJSON("config.json", as: HFRichConfig.self)
        let textCfg = rich?.text_config
        
        //print("model: \(localModel.id)")
        //print("cfg: \(String(describing: cfg))")
        //print("gen: \(String(describing: gen))")
        //print("rich: \(String(describing: rich))")
        //print("textCfg: \(String(describing: textCfg))")

        if let base = cfg?.rope_scaling?.original_max_position_embeddings, let factor = cfg?.rope_scaling?.factor {
            meta.baseContextLength = base
            let expanded = Int(Double(base) * factor)
            meta.contextExtension = "yarn x\(Int(factor))"
            if let maxCtx = textCfg?.max_position_embeddings ?? cfg?.max_position_embeddings, maxCtx == expanded {
                meta.inputTokenLimit = maxCtx
            } else {
                meta.inputTokenLimit = textCfg?.max_position_embeddings ?? cfg?.max_position_embeddings ?? expanded
            }
            meta.ropeFactor = factor
        } else {
            if let maxEmbeddings = textCfg?.max_position_embeddings {
                meta.inputTokenLimit = maxEmbeddings
            } else if let maxEmbeddings = cfg?.max_position_embeddings {
                meta.inputTokenLimit = maxEmbeddings
            } else if let nCtx = cfg?.n_ctx {
                meta.inputTokenLimit = nCtx
            } else if let contextLength = cfg?.context_length {
                meta.inputTokenLimit = contextLength
            } else if let seqLength = cfg?.seq_length {
                meta.inputTokenLimit = seqLength
            } else if let ropeScalingEmbeddings = cfg?.rope_scaling?.original_max_position_embeddings {
                meta.inputTokenLimit = ropeScalingEmbeddings
            }
            meta.baseContextLength = meta.inputTokenLimit
        }

        meta.outputTokenLimit = gen?.max_new_tokens
        meta.temperature = gen?.temperature ?? textCfg?.temperature
        meta.topP = gen?.top_p ?? textCfg?.top_p
        meta.topK = gen?.top_k ?? textCfg?.top_k
        meta.repetitionPenalty = textCfg?.repetition_penalty ?? gen?.temperature
        meta.version = cfg?._commit_hash ?? localModel.lastCommit

        meta.modelSize = localModel.totalSize / (1024 * 1024)
        meta.vocabSize = textCfg?.vocab_size
        meta.dtype = nil
        meta.slidingWindow = textCfg?.sliding_window

        if cfg?.vision_tower != nil || cfg?.vision_config != nil || cfg?.image_size != nil || cfg?.processor_config != nil || rich?.vision_config != nil {
            meta.mediaSupport = true
        }
        /*if meta.mediaSupport == false {
            if probeImageSupport(at: dir) {
                meta.mediaSupport = true
            } else {
                let inlineResult = await activeInlineImageProbe(localModel: localModel)
                meta.mediaSupport = inlineResult
            }
        }*/

        meta.seed = gen?.seed != nil
        let idLower = localModel.id.lowercased()
        meta.thingking = idLower.contains("think") || idLower.contains("reason") || idLower.contains("r1")

        if let data = loadData("config.json"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let q = json["quantization"] as? [String: Any] {
            meta.quantBits = q["bits"] as? Int
            meta.quantGroupSize = q["group_size"] as? Int
            meta.quantMode = q["mode"] as? String
        }

        meta.padTokenId = textCfg?.pad_token_id
        meta.eosTokenId = textCfg?.eos_token_id
        if meta.eosTokenId == nil { meta.eosTokenId = cfg?.image_size }

        if let readme = loadData("README.md"), let text = String(data: readme, encoding: .utf8) {
            meta.description = text.split(separator: "\n\n", omittingEmptySubsequences: true).first.map { String($0.prefix(600)) }
        }
        return meta
    }
}
