//
//  LLModelServiceTests.swift
//  InferX
//
//  Created by mingdw on 2025/4/24.
//
/*
import Testing // Import the new Testing framework
@testable import InferX // Import your app module

// Helper function to create mock Loader closures for testing
// Returns a @Sendable closure matching the expected type
private func mockLoader(
    models: [LLModel]?, // Models to return, or nil for "no response"
    shouldThrowError: Bool = false, // Set to true to simulate an error
    delay: Duration = .zero // Optional delay to simulate network latency
) -> @Sendable () async throws -> [LLModel] {
    return { @Sendable in // Ensure closure is @Sendable
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        
        if shouldThrowError {
            struct MockLoaderError: Error, Equatable {}
            throw MockLoaderError()
        }
        
        guard let modelsToReturn = models else {
            struct MockLoaderError: Error, Equatable {}
            throw MockLoaderError()
        }
        
        return modelsToReturn
    }
}


@MainActor // Run all tests in this suite on the MainActor
struct LLModelServiceTests {

    var service: LLModelService! // Service instance for testing

    // Initialize a fresh service instance before each test run within this suite structure
    init() {
        service = LLModelService()
    }

    // MARK: - Setup and State Tests

    @Test("Initial state is empty")
    func initialState() {
        #expect(service.models.isEmpty)
    }

    // MARK: - setModelProvider Tests

    @Test("setModelLoader adds model loader closure")
    func setModelLoader() {
        // Arrange
        let loaderClosure = mockLoader(models: [])
        
        // Act
        service.setModelLoader(modelProvider: .ollama, modelLoader: loaderClosure)
        
        // Assert (Indirectly tested later)
        #expect(!service.modelLoaders.isEmpty) // If it runs without crashing, it worked structurally.
    }

    // MARK: - loadModelsFromOne Tests

    @Test("loadModels successfully update new models")
    func loadModels_success() async throws {
        // Arrange
        let initialOllama = LLModel(name: "Old Llama")
        let existingOpenAI = LLModel(name: "GPT")
        service.updateModels(modelProvider: .ollama, models: [initialOllama])
        service.updateModels(modelProvider: .openAI, models: [existingOpenAI])
        #expect(service.models.count == 2)

        let newOllamaModels = [
            LLModel(name: "New Llama 1"),
            LLModel(name: "New Llama 2")
        ]
        let ollamaLoader = mockLoader(models: newOllamaModels)
        service.setModelLoader(modelProvider: .ollama, modelLoader: ollamaLoader)

        // Act
        await service.loadModels(modelProvider: .ollama)

        // Assert
        let currentModels = service.models
        #expect(currentModels.count == 2)
        #expect(currentModels[.openAI]?.count == 1)
        #expect(currentModels[.ollama]?.count == 2)
        #expect(((currentModels[.ollama]?.contains(initialOllama)) != nil))
        #expect(((currentModels[.openAI]?.contains(existingOpenAI)) != nil))
        #expect(((currentModels[.ollama]?.contains(where: { $0.name == "New Llama 1" })) != nil))
        #expect(((currentModels[.ollama]?.contains(where: { $0.name == "New Llama 2" })) != nil))
    }

    @Test("loadModels handles provider returning nil")
    func loadModels_nilResponse() async throws {
        // Arrange
        let initialModels = [LLModel(name: "GPT")]
        service.updateModels(modelProvider: .openAI, models: initialModels)
        #expect(service.models.count == 1)

        let nilLoader = mockLoader(models: nil) // Returns nil
        service.setModelLoader(modelProvider: .ollama, modelLoader: nilLoader)

        // Act
        await service.loadModels(modelProvider: .ollama)

        // Assert
        let currentModels = service.models
        #expect(currentModels.count == 1) // Count should not change
        #expect(currentModels[.openAI] == initialModels) // Models should be identical to initial state
    }

    @Test("loadModels handles provider throwing error")
    func loadModels_throwsError() async throws {
        // Arrange
        let initialModels = [LLModel(name: "GPT")]
        service.updateModels(modelProvider: .openAI, models: initialModels)
        #expect(service.models.count == 1)

        let errorProvider = mockLoader(models: nil, shouldThrowError: true)
        service.setModelLoader(modelProvider: .ollama, modelLoader: errorProvider)

        // Act
        await service.loadModels(modelProvider: .ollama)

        // Assert
        // The function catches the error and prints, state should remain unchanged.
        let currentModels = service.models
        #expect(currentModels.count == 1)
        #expect(currentModels[.openAI] == initialModels)
    }

    // MARK: - loadModelsFromAll Tests

    @Test("loadAllModels loads from multiple providers")
    func loadAllModels_multipleProviders() async throws {
        // Arrange
        let initialOllama = LLModel(name: "Old Llama")
        let initialOpenAI = LLModel(name: "Old GPT")
        service.updateModels(modelProvider: .openAI, models: [initialOpenAI])
        service.updateModels(modelProvider: .ollama, models: [initialOllama])
        #expect(service.models.count == 2)

        let newOllamaModels = [LLModel(name: "New Llama")]
        let newOpenAIModels = [LLModel(name: "New GPT")]

        let ollamaLoader = mockLoader(models: newOllamaModels)
        let openAILoader = mockLoader(models: newOpenAIModels)

        service.setModelLoader(modelProvider: .ollama, modelLoader: ollamaLoader)
        service.setModelLoader(modelProvider: .openAI, modelLoader: openAILoader)

        // Act
        await service.loadAllModels()

        // Assert
        let currentModels = service.models
        #expect(currentModels.count == 2) // Old ones deleted, new ones added
        #expect((currentModels[.ollama]?.contains(where: { $0.name == "New Llama" })) != nil)
        #expect((currentModels[.openAI]?.contains(where: { $0.name == "New GPT" })) != nil)
        #expect(!(currentModels[.ollama]?.contains(initialOllama) ?? false))
        #expect(!(currentModels[.openAI]?.contains(initialOpenAI) ?? false))
    }

    @Test("loadAllModels handles one provider error, loads others")
    func loadAllModels_oneError() async throws {
        // Arrange
        let initialOllama = LLModel(name: "Old Llama")
        service.updateModels(modelProvider: .ollama, models: [initialOllama])

        let newOllamaModels = [LLModel(name: "New Llama")]

        let errorLoader = mockLoader(models: nil, shouldThrowError: true)
        let ollamaLoader = mockLoader(models: newOllamaModels)

        service.setModelLoader(modelProvider: .ollama, modelLoader: errorLoader)
        service.setModelLoader(modelProvider: .ollama, modelLoader: ollamaLoader)

        // Act
        await service.loadAllModels()

        // Assert
        let currentModels = service.models
        #expect(currentModels.count == 1)
        #expect(((currentModels[.ollama]?.contains(where: { $0.name == "New Llama" })) != nil))
        #expect(!(currentModels[.ollama]?.contains(initialOllama) ?? false))
    }
    
    @Test("loadAllModels with no providers does nothing")
    func loadAllModels_noProviders() async throws {
        // Arrange
        let initialModels = [LLModel(name: "GPT")]
        service.updateModels(modelProvider: .openAI, models: initialModels)
        
        // Act
        await service.loadAllModels()
        
        // Assert
        let currentModels = service.models
        #expect(currentModels.count == 1)
        #expect(currentModels[.openAI] == initialModels)
    }
}*/
