//
//  LLMEvaluator.swift
//  InferX
//
//  Created by mingdw on 2025/7/24.
//

import Foundation
import MLXLMCommon
import MLX
import MLXLLM
import Tokenizers

actor LLMEvaluator {
    static let shared = LLMEvaluator()

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    var loadState = LoadState.idle

    
    private func createModelContainer(dir: URL, cacheLimit: Int) async throws -> ModelContainer {
        MLX.GPU.set(cacheLimit: cacheLimit)
        let modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: ModelConfiguration(directory: dir)
        )
        return modelContainer
    }
    
    private func load(dir: URL, cacheLimit: Int) async throws -> ModelContainer {
        switch loadState {
        case .idle:
            let container = try await createModelContainer(dir: dir, cacheLimit: cacheLimit)
            loadState = .loaded(container)
            return container

        case .loaded(let modelContainer):
            if await modelContainer.configuration.modelDirectory() != dir {
                loadState = .idle
                let container = try await createModelContainer(dir: dir, cacheLimit: cacheLimit)
                loadState = .loaded(container)
                return container
            }
            return modelContainer
        }
    }

    func generate(
        dir: URL,
        chat: [Chat.Message],
        cacheLimit: Int,
        seed: Double,
        enableThinking: Bool,
        generateParameters: GenerateParameters,
        tools: [ToolSpec]? = nil
    ) async throws -> AsyncStream<Generation> {

        let userInput = UserInput(
            chat: chat,
            tools: tools,
            additionalContext: ["enable_thinking": enableThinking]
        )
        
        let modelContainer = try await load(dir: dir, cacheLimit: cacheLimit)
        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * seed))
        
        return try await modelContainer.perform {
            (context: ModelContext) -> AsyncStream<Generation> in
            
            let lmInput = try await context.processor.prepare(input: userInput)
            let generate = try MLXLMCommon.generate(
                input: lmInput, parameters: generateParameters, context: context)
            return generate
        }
    }
}
