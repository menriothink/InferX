//
//  OllamaServiceTests.swift
//  InferX
//
//  Created by mingdw on 2025/4/24.
//

import Foundation
import OllamaKit
@testable import InferX

struct MockModelResponse: ModelResponseProvider {
    var models: [OKModelResponse.Model]

    init(models: [OKModelResponse.Model]) {
        self.models = models
    }
}

struct MockOllamaError: Error, Equatable, LocalizedError {
    var errorDescription: String? = "Mock Ollama Error"
}

extension OKModelResponse.Model: Codable {}
extension OKModelResponse.Model.ModelDetails: Codable {}

private struct OKModelWrapper: Codable {
    let models: [OKModelResponse.Model]

    init(models: [OKModelResponse.Model]) {
        self.models = models
    }
}

final class MockOllamaKit: OllamaKitProtocol {
    let modelsResult: Result<ModelResponseProvider, Error> = .failure(MockOllamaError())
    let reachableResult: Bool = false

    func models() async throws -> OKModelResponse {
        switch modelsResult {
        case .success(let responseProvider):
            let wrapper = ["models": responseProvider.models]
            let data = try JSONEncoder().encode(wrapper)
            return try JSONDecoder().decode(OKModelResponse.self, from: data)
        case .failure(let error):
            throw error
        }
    }
    
    func reachable() async -> Bool {
        print("MockOllamaKit: reachable() 被调用。将返回预设结果: \(reachableResult)。")
        return reachableResult
    }
}

struct MockDataFactory {
    static func createOKModelResponse(models: [OKModelResponse.Model]) -> MockModelResponse {
        return MockModelResponse(models: models)
    }

    static let llamaModel = OKModelResponse.Model(
        name: "llama3:8b",
        digest: "digest-llama",
        size: 123456789,
        modifiedAt: Date(), // Use a real date
        details: OKModelResponse.Model.ModelDetails( // Use nested type initializer
            format: "gguf",
            family: "llama",
            parameterSize: "8B",
            quantizationLevel: "Q4_0",
            families: ["llama"] // families is not nil, but doesn't contain "clip"
        )
    )

    static let llavaModel = OKModelResponse.Model(
        name: "llava:latest",
        digest: "digest-llava",
        size: 987654321,
        modifiedAt: Date().addingTimeInterval(-3600), // Different date
        details: OKModelResponse.Model.ModelDetails(
            format: "gguf",
            family: "llama",
            parameterSize: "7B",
            quantizationLevel: "Q5_K_M",
            families: ["llama", "clip"] // Contains "clip" -> imageSupport = true
        )
    )

    static let mistralModel = OKModelResponse.Model(
        name: "mistral:7b",
        digest: "digest-mistral",
        size: 555555555,
        modifiedAt: Date().addingTimeInterval(-7200), // Another different date
        details: OKModelResponse.Model.ModelDetails(
            format: "gguf",
            family: "mistral",
            parameterSize: "7B",
            quantizationLevel: "Q4_0",
            families: nil // families is nil -> imageSupport = false
        )
    )

    // --- Predefined Mock Responses ---
    /// A response containing multiple models with varying properties.
    static let successResponse = createOKModelResponse(models: [llamaModel, llavaModel, mistralModel])
    
    /// A response containing only one model.
    static let singleModelResponse = createOKModelResponse(models: [llamaModel])

    /// An empty response.
    static let emptyResponse = createOKModelResponse(models: [])
}
