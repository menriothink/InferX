//
//  ModelManagerModel.swift
//  InferX
//
//  Created by mingdw on 2025/4/15.
//

import SwiftUI
import SwiftData
import Defaults

struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
@Observable
final class ModelManagerModel {
    enum SidebarItemID: String, Identifiable {
        case modelAPIDetail = "Model API Detail"
        case modelDetail = "Model Detail"
        case mlxView = "MLX View"
        case hfModelListView = "HuggingFace List View"

        var id: String { rawValue }
    }

    var selectedItem: SidebarItemID = .modelAPIDetail

    var activeModel: Model?
    var activeModelAPI: ModelAPI?

    var remoteModels: [String: [RemoteModel]] = [:]
    var localModels: [String: [Model]] = [:]
    var modelAPIs: [ModelAPI] = []
    var modelContext: ModelContext?

    let hfModelListModel = HFModelListModel()
    let modelService = ModelService()

    func generateUniqueDefaultAPIName(for provider: ModelProvider) -> String {
        let prefix = "\(provider.rawValue)-"

        let relevantAPINames = modelAPIs.filter {
            $0.name.starts(with: prefix)
        }

        let maxNumber = relevantAPINames
            .compactMap { api in
                let numberString = api.name.dropFirst(prefix.count)
                return Int(numberString)
            }
            .max() ?? 0

        let newNumber = maxNumber + 1

        return "\(prefix)\(newNumber)"
    }

    func getModelMeta(for model: Model?) -> ModelMeta? {
        guard let model = model else { return nil }
        return remoteModels[model.apiName]?.first {
            $0.name == model.name
        }?.modelMeta
    }

    func getModelAPI(modelAPIName: String) -> ModelAPI? {
        return modelAPIs.first {
            $0.name == modelAPIName
        }
    }

    func createModelAPI(
        name: String,
        modelProvider: ModelProvider,
        endPoint: String = "",
        apiKey: String = ""
    ) throws -> ModelAPI {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            throw ModelAPI.ModelAPIError.emptyNameNotAllowed
        }

        if modelAPIs.contains(where: { $0.name == trimmedName}) {
            throw ModelAPI.ModelAPIError.nameAlreadyExists(trimmedName)
        }

        let newAPI = ModelAPI(
            name: trimmedName,
            modelProvider: modelProvider,
            endPoint: endPoint,
            apiKey: apiKey
        )

        modelContext?.insert(newAPI)

        modelAPIs.append(newAPI)

        activeModelAPI = newAPI

        return newAPI
    }

    func deleteModelAPI(modelAPI: ModelAPI) {
        if let models = self.localModels[modelAPI.name] {
            for model in models {
                deleteModel(model: model)
            }
        }

        self.localModels[modelAPI.name] = nil

        modelAPIs.removeAll { $0.id == modelAPI.id }
        modelContext?.delete(modelAPI)
        if activeModelAPI == modelAPI {
            activeModelAPI = modelAPIs.first
        }
    }

    func getModel(
        modelID: UUID? = nil,
        apiName: String? = nil,
        modelName: String? = nil
    ) -> Model? {

        if let apiName = apiName, let modelName = modelName {
            return localModels[apiName]?.first(where: { $0.name == modelName })
        }

        if let modelID = modelID {
            return localModels.values.joined().map { $0 }.first(where: { $0.id == modelID })
        }

        if let apiName = apiName {
            return localModels[apiName]?.first
        }

        return nil
    }

    func createModel(
        name: String = "",
        modelAPI: ModelAPI
    ) throws -> Model {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            throw Model.ModelError.emptyNameNotAllowed
        }

        if let localModels = localModels[modelAPI.name],
               localModels.contains(where: { $0.name == trimmedName}) {
            throw Model.ModelError.nameAlreadyExists(trimmedName)
        }

        let newModel = Model(
            name: trimmedName,
            apiName: modelAPI.name,
            modelProvider: modelAPI.modelProvider
        )
        
        try updateModelParameter(model: newModel)
        
        newModel.isAvailable = true

        modelContext?.insert(newModel)

        if localModels[modelAPI.name] == nil {
            localModels[modelAPI.name] = [newModel]
        } else {
            localModels[modelAPI.name]?.append(newModel)
        }

        return newModel
    }

    func deleteModel(model: Model) {
        localModels[model.apiName]?.removeAll { $0.id == model.id }
        modelContext?.delete(model)
    }

    private func updateModelParameter(model: Model) throws {
        let meta = getModelMeta(for: model)
        
        if Defaults[.gpuCacheLimitEnable] &&
            Double(meta?.modelSize ?? 0) * 1.5 > Defaults[.gpuCacheLimit] {
            throw Model.ModelError.modelSizeExceedLimits(model.name, Double(meta?.modelSize ?? 0) * 1.5)
        }
        
        var parameter = ModelParameter()
        
        parameter.enableTemperature = true
        if let temperature = meta?.temperature {
            parameter.temperature = temperature
        }
        
        parameter.enableTopP = true
        if let topP = meta?.topP {
            parameter.topP = topP
        }
        
        parameter.enableTopK = meta?.topK != nil
        if let topK = meta?.topK {
            parameter.topK = topK
        }

        parameter.enableInputTokens = meta?.inputTokenLimit != nil
        if let inputTokenLimit = meta?.inputTokenLimit {
            parameter.inputTokens = inputTokenLimit
        }
        
        parameter.enableOutputTokens = meta?.outputTokenLimit != nil
        if let outputTokenLimit = meta?.outputTokenLimit {
            parameter.outputTokens = outputTokenLimit
        }
        
        parameter.enableRepetitionPenalty = meta?.repetitionPenalty != nil
        if let repetitionPenalty = meta?.repetitionPenalty {
            parameter.repetitionPenalty = repetitionPenalty
        }
        
        parameter.thinking = meta?.thingking ?? false

        parameter.enableSeed = meta?.seed ?? false
        
        parameter.modelSize = meta?.modelSize ?? 0
        
        model.applyParameter(parameter)
    }
    
    func updateAllModelsStatus() async {
        guard !modelAPIs.isEmpty else {
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for modelAPI in modelAPIs {
                let apiName = modelAPI.name
                group.addTask {
                    do {
                        try await self.updateModelStatus(for: apiName)
                    } catch {
                        print("Model API: \(apiName), Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func updateModelStatus(for apiName: String) async throws {
        guard let modelAPI = self.modelAPIs.first(where: { $0.name == apiName }) else {
            throw SimpleError(message: "Cannot find model API with name '\(apiName)'")
        }

        do {
            let modelsFromRemote = try await fetchRemoteModels(for: apiName)

            self.remoteModels[apiName] = modelsFromRemote
            modelAPI.isAvailable = !modelsFromRemote.isEmpty

            let remoteModelNames = Set(modelsFromRemote.map { $0.name })

            for localModel in localModels[apiName] ?? [] {
                localModel.isAvailable = remoteModelNames.contains(localModel.name)
                //updateModelParameter(model: localModel)
            }

        } catch {
            self.remoteModels[apiName] = nil
            modelAPI.isAvailable = false
            for localModel in localModels[apiName] ?? [] {
                localModel.isAvailable = false
            }

            let errors = "Failed to update status for Model API: \(apiName). Error: \(error.localizedDescription)"
            throw SimpleError(message: errors)
        }
    }

    func fetchAllRemoteModels() async {
        guard !modelAPIs.isEmpty else {
            return
        }

        await withTaskGroup(of: (String, [RemoteModel]?).self) { group in
            for modelAPI in modelAPIs {
                let apiName = modelAPI.name
                group.addTask {
                    do {
                        let models = try await self.fetchRemoteModels(for: apiName)
                        return (apiName, models)
                    } catch {
                        print("Model API: \(apiName) cannot get remote models! Error: \(error.localizedDescription)")
                        return (apiName, nil)
                    }
                }
            }

            for await (apiName, models) in group {
                await MainActor.run {
                    if let models = models {
                        self.remoteModels[apiName] = models
                    } else {
                        self.remoteModels[apiName] = nil
                    }
                }
            }
        }
    }

    private func fetchRemoteModels(for apiName: String) async throws -> [RemoteModel] {
        guard let modelAPI = self.modelAPIs.first(where: { $0.name == apiName }) else {
            throw SimpleError(message: "Cannot find model API with name '\(apiName)'")
        }

        let modelService = ModelService()

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let handler: @Sendable (ModelsCompletion) async -> Void = { completion in
                    switch completion {
                    case .finished(let modelsFromAPI):
                        continuation.resume(returning: modelsFromAPI)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                await modelService.loadModels(
                    for: ModelAPIDescriptor(from: modelAPI),
                    handler: handler
                )
            }
        }
    }

    func resetAvailabilityAndCleanModels() {
        let validAPINames = Set(modelAPIs.map { $0.name })

        let apiNamesToRemove = localModels.keys.filter { apiName in
            !validAPINames.contains(apiName)
        }

        for apiNameToRemove in apiNamesToRemove {
            if let modelsToRemove = localModels.removeValue(forKey: apiNameToRemove) {
                for model in modelsToRemove {
                    deleteModel(model: model)
                }
            }
        }

        for modelAPI in modelAPIs {
            modelAPI.isAvailable = false
        }

        for model in localModels.values.flatMap({ $0 }) {
            model.isAvailable = false
        }
    }
}
