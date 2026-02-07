//
//  CopilotService.swift
//  InferX
//
//  GitHub Copilot OAuth integration and chat service
//  Each ModelAPI has its own independent authentication
//

import Foundation
#if os(macOS)
import AppKit
#endif

actor CopilotService {
    static let shared = CopilotService()
    
    // MARK: - OAuth Configuration
    
    /// GitHub OAuth device flow endpoints
    private let deviceCodeURL = "https://github.com/login/device/code"
    private let accessTokenURL = "https://github.com/login/oauth/access_token"
    
    /// Copilot API endpoints
    private let copilotTokenURL = "https://api.github.com/copilot_internal/v2/token"
    
    /// Default Copilot API base URL (individual accounts)
    /// The actual URL may be derived from the token's proxy-ep field
    private let defaultCopilotBaseURL = "https://api.individual.githubcopilot.com"
    
    /// GitHub OAuth Client ID for Copilot (VS Code's client ID)
    private let clientId = "Iv1.b507a08c87ecfe98"
    
    /// Required scopes for Copilot access
    private let scope = "read:user"

    // MARK: - Copilot Client Headers (Zed-style, mimics IDE plugin authorization)

    private let copilotUserAgent = "GithubCopilot/1.200.0"
    private let copilotEditorVersion = "vscode/1.103.2"  // lowercase 'v' like Zed
    private let copilotEditorPluginVersion = "copilot-chat/1.0"
    private let copilotIntegrationId = "vscode-chat"     // Zed uses this
    private let githubApiVersion = "2025-05-01"          // Required API version header
    
    // MARK: - Token Storage Key Generators
    
    private func accessTokenKey(for apiId: UUID) -> String {
        "copilot_access_token_\(apiId.uuidString)"
    }
    
    private func copilotTokenKey(for apiId: UUID) -> String {
        "copilot_api_token_\(apiId.uuidString)"
    }
    
    private func copilotTokenExpiresKey(for apiId: UUID) -> String {
        "copilot_token_expires_\(apiId.uuidString)"
    }
    
    private func copilotBaseURLKey(for apiId: UUID) -> String {
        "copilot_base_url_\(apiId.uuidString)"
    }
    
    // MARK: - Cached Tokens (per API)
    
    private var cachedCopilotTokens: [UUID: String] = [:]
    private var tokenExpiresAtMap: [UUID: Date] = [:]
    private var cachedBaseURLs: [UUID: String] = [:]
    
    // MARK: - OAuth Device Flow
    
    /// Start OAuth device flow - returns user code and verification URL
    func startDeviceFlow() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: URL(string: deviceCodeURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(copilotEditorVersion, forHTTPHeaderField: "Editor-Version")
        request.setValue(copilotEditorPluginVersion, forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue(copilotUserAgent, forHTTPHeaderField: "User-Agent")
        
        let body = "client_id=\(clientId)&scope=\(scope)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CopilotError.deviceFlowFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(DeviceCodeResponse.self, from: data)
    }
    
    /// Poll for access token after user authorizes (for specific API)
    func pollForAccessToken(deviceCode: String, interval: Int, apiId: UUID) async throws -> String {
        var pollInterval = TimeInterval(interval)
        
        print("[CopilotService] Starting poll for access token, apiId: \(apiId.uuidString)")
        
        while true {
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            
            var request = URLRequest(url: URL(string: accessTokenURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue(copilotEditorVersion, forHTTPHeaderField: "Editor-Version")
            request.setValue(copilotEditorPluginVersion, forHTTPHeaderField: "Editor-Plugin-Version")
            request.setValue(copilotUserAgent, forHTTPHeaderField: "User-Agent")
            
            let body = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            request.httpBody = body.data(using: .utf8)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CopilotError.networkError
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            if httpResponse.statusCode == 200 {
                if let tokenResponse = try? decoder.decode(AccessTokenResponse.self, from: data) {
                    if let accessToken = tokenResponse.accessToken {
                        // Save to keychain with API-specific key
                        let key = accessTokenKey(for: apiId)
                        print("[CopilotService] Saving access token to keychain with key: \(key)")
                        KeychainHelper.save(key: key, value: accessToken)
                        
                        // Verify save
                        if let saved = KeychainHelper.load(key: key) {
                            print("[CopilotService] Token saved successfully, length: \(saved.count)")
                        } else {
                            print("[CopilotService] WARNING: Token save failed!")
                        }
                        
                        return accessToken
                    }
                    
                    if let error = tokenResponse.error {
                        switch error {
                        case "authorization_pending":
                            continue
                        case "slow_down":
                            pollInterval += 5
                            continue
                        case "expired_token":
                            throw CopilotError.tokenExpired
                        case "access_denied":
                            throw CopilotError.accessDenied
                        default:
                            throw CopilotError.unknownError(error)
                        }
                    }
                }
            }
        }
    }
    
    /// Get Copilot API token using GitHub access token (for specific API)
    func getCopilotToken(accessToken: String, apiId: UUID) async throws -> (token: String, baseURL: String) {
        // Check cached token for this API
        if let cached = cachedCopilotTokens[apiId],
           let expires = tokenExpiresAtMap[apiId],
           Date() < expires,
           let baseURL = cachedBaseURLs[apiId] {
            return (cached, baseURL)
        }
        
        var request = URLRequest(url: URL(string: copilotTokenURL)!)
        request.httpMethod = "GET"
        request.setValue("token \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(copilotEditorPluginVersion, forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue(copilotEditorVersion, forHTTPHeaderField: "Editor-Version")
        request.setValue(copilotUserAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotError.networkError
        }
        
        if httpResponse.statusCode == 401 {
            throw CopilotError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            // Log the error response for debugging
            if let errorBody = String(data: data, encoding: .utf8) {
                print("[CopilotService] Token fetch error body: \(errorBody)")
            }
            throw CopilotError.tokenFetchFailed(httpResponse.statusCode)
        }
        
        // Debug: Print raw response for troubleshooting
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("[CopilotService] Token response: \(rawResponse.prefix(500))...")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tokenResponse = try decoder.decode(CopilotTokenResponse.self, from: data)
        
        // Prefer endpoints.api from response, then try proxy-ep from token, finally use default
        let baseURL: String
        if let apiEndpoint = tokenResponse.endpoints?.api, !apiEndpoint.isEmpty {
            baseURL = apiEndpoint
            print("[CopilotService] Using endpoint from response: \(baseURL)")
        } else {
            baseURL = deriveCopilotApiBaseURL(from: tokenResponse.token)
            print("[CopilotService] Derived endpoint from token: \(baseURL)")
        }
        
        // Cache the token and baseURL for this API
        cachedCopilotTokens[apiId] = tokenResponse.token
        tokenExpiresAtMap[apiId] = Date(timeIntervalSince1970: TimeInterval(tokenResponse.expiresAt))
        cachedBaseURLs[apiId] = baseURL
        
        // Save to keychain with API-specific keys
        KeychainHelper.save(key: copilotTokenKey(for: apiId), value: tokenResponse.token)
        KeychainHelper.save(key: copilotTokenExpiresKey(for: apiId), value: String(tokenResponse.expiresAt))
        KeychainHelper.save(key: copilotBaseURLKey(for: apiId), value: baseURL)
        
        print("[CopilotService] Copilot token acquired, baseURL: \(baseURL)")
        
        return (tokenResponse.token, baseURL)
    }
    
    /// Derive the Copilot API base URL from the token's proxy-ep field
    /// The token is a semicolon-delimited set of key/value pairs
    private func deriveCopilotApiBaseURL(from token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return defaultCopilotBaseURL
        }
        
        // Look for proxy-ep= in the token
        // Format: key1=value1;key2=value2;proxy-ep=https://proxy.xxx.com;...
        if let range = trimmed.range(of: "(?:^|;)\\s*proxy-ep=([^;\\s]+)", options: .regularExpression),
           let match = trimmed.range(of: "proxy-ep=", range: range) {
            let startIndex = trimmed.index(match.upperBound, offsetBy: 0)
            var endIndex = trimmed.endIndex
            
            // Find the end of the value (semicolon or end of string)
            if let semicolonIndex = trimmed[startIndex...].firstIndex(of: ";") {
                endIndex = semicolonIndex
            }
            
            let proxyEp = String(trimmed[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
            if !proxyEp.isEmpty {
                // Convert proxy.* to api.* (as per OpenClaw's implementation)
                var host = proxyEp
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                
                if host.hasPrefix("proxy.") {
                    host = "api." + host.dropFirst(6)
                }
                
                let baseURL = "https://\(host)"
                print("[CopilotService] Derived baseURL from token: \(baseURL)")
                return baseURL
            }
        }
        
        return defaultCopilotBaseURL
    }
    
    // MARK: - Authentication Status (per API)
    
    func isAuthenticated(apiId: UUID) -> Bool {
        let key = accessTokenKey(for: apiId)
        let result = KeychainHelper.load(key: key) != nil
        print("[CopilotService] isAuthenticated check for key '\(key)': \(result)")
        return result
    }
    
    func getStoredAccessToken(apiId: UUID) -> String? {
        let key = accessTokenKey(for: apiId)
        let token = KeychainHelper.load(key: key)
        print("[CopilotService] getStoredAccessToken for key '\(key)': \(token != nil ? "found" : "nil")")
        return token
    }
    
    func logout(apiId: UUID) {
        KeychainHelper.delete(key: accessTokenKey(for: apiId))
        KeychainHelper.delete(key: copilotTokenKey(for: apiId))
        KeychainHelper.delete(key: copilotTokenExpiresKey(for: apiId))
        KeychainHelper.delete(key: copilotBaseURLKey(for: apiId))
        cachedCopilotTokens.removeValue(forKey: apiId)
        tokenExpiresAtMap.removeValue(forKey: apiId)
        cachedBaseURLs.removeValue(forKey: apiId)
    }
    
    // MARK: - Model Service Implementation
    
    private func isInvalidConfig(modelAPI: ModelAPIDescriptor) async -> SimpleError? {
        print("[CopilotService] isInvalidConfig check for modelAPI.id: \(modelAPI.id.uuidString)")
        guard isAuthenticated(apiId: modelAPI.id) else {
            print("[CopilotService] Not authenticated for modelAPI.id: \(modelAPI.id.uuidString)")
            return SimpleError(message: "GitHub Copilot not authenticated. Please sign in first.")
        }
        return nil
    }
    
    func getModels(
        modelAPI: ModelAPIDescriptor,
        handler: @escaping @Sendable (ModelsCompletion) async -> Void
    ) async {
        // For Copilot, if not authenticated, return failure to prompt login
        if let simpleError = await isInvalidConfig(modelAPI: modelAPI) {
            await handler(.failure(simpleError))
            return
        }
        
        // Even if token fetch fails, return default models so user can still use the service
        do {
            guard let accessToken = getStoredAccessToken(apiId: modelAPI.id) else {
                // Not authenticated, return default models anyway
                print("[CopilotService] No access token found, returning default models")
                let defaultModels = getDefaultModels()
                await handler(.finished(defaultModels))
                return
            }
            
            // Try to get Copilot token and baseURL
            let (copilotToken, baseURL): (String, String)
            do {
                (copilotToken, baseURL) = try await getCopilotToken(accessToken: accessToken, apiId: modelAPI.id)
            } catch {
                // Token fetch failed, but we can still return default models
                print("[CopilotService] Failed to get Copilot token: \(error.localizedDescription)")
                let defaultModels = getDefaultModels()
                await handler(.finished(defaultModels))
                return
            }
            
            let modelsURL = "\(baseURL)/models"
            var request = URLRequest(url: URL(string: modelsURL)!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(copilotToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(copilotIntegrationId, forHTTPHeaderField: "Copilot-Integration-Id")
            request.setValue(copilotEditorPluginVersion, forHTTPHeaderField: "Editor-Plugin-Version")
            request.setValue(copilotEditorVersion, forHTTPHeaderField: "Editor-Version")
            request.setValue(copilotUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue(githubApiVersion, forHTTPHeaderField: "x-github-api-version")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[CopilotService] Invalid response, returning default models")
                let defaultModels = getDefaultModels()
                await handler(.finished(defaultModels))
                return
            }
            
            print("[CopilotService] Models API response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                // Fallback to default models if API fails
                print("[CopilotService] Models API failed with status \(httpResponse.statusCode), returning default models")
                let defaultModels = getDefaultModels()
                await handler(.finished(defaultModels))
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let modelsResponse = try decoder.decode(CopilotModelsResponse.self, from: data)
            
            // Build models with vision support detection (name-based for speed)
            let models = modelsResponse.data.map { model in
                var meta = ModelMeta()
                meta.description = "GitHub Copilot - \(model.id)"
                // Use name-based detection for speed
                // Unknown models default to true (most modern models support vision)
                meta.mediaSupport = Self.supportsVision(modelId: model.id)
                return RemoteModel(
                    name: model.id,
                    modelProvider: .copilot,
                    modelMeta: meta
                )
            }
            
            print("[CopilotService] Got \(models.count) models from API")
            await handler(.finished(models.isEmpty ? getDefaultModels() : models))
        } catch {
            // Return default models on error
            print("[CopilotService] Error getting models: \(error.localizedDescription)")
            let defaultModels = getDefaultModels()
            await handler(.finished(defaultModels))
        }
    }
    
    private func getDefaultModels() -> [RemoteModel] {
        let defaultModelNames = [
            "gpt-4o",
            "gpt-4o-mini",
            "gpt-4-turbo",
            "gpt-4",
            "gpt-3.5-turbo",
            "gpt-5",
            "claude-3.5-sonnet",
            "claude-3-opus",
            "claude-3-sonnet",
            "claude-3-haiku",
            "o1-preview",
            "o1-mini",
            "o3-mini"
        ]
        
        return defaultModelNames.map { name in
            var meta = ModelMeta()
            meta.description = "GitHub Copilot - \(name)"
            meta.mediaSupport = Self.supportsVision(modelId: name)
            return RemoteModel(
                name: name,
                modelProvider: .copilot,
                modelMeta: meta
            )
        }
    }
    
    /// Check if a model supports vision/image input
    private static func supportsVision(modelId: String) -> Bool {
        let id = modelId.lowercased()
        
        // GPT-4 series with vision support
        if id.contains("gpt-4o") || id.contains("gpt-4-turbo") || id.contains("gpt-4-vision") {
            return true
        }
        
        // GPT-5 and newer typically support vision
        if id.contains("gpt-5") || id.contains("gpt-6") {
            return true
        }
        
        // Claude 3 models support vision
        if id.contains("claude-3") {
            return true
        }
        
        // o1/o3/o4 models with vision
        if id.contains("o1") || id.contains("o3") || id.contains("o4") {
            return true
        }
        
        // Gemini models support vision
        if id.contains("gemini") {
            return true
        }
        
        // Models that explicitly don't support vision
        if id.contains("gpt-3.5") || id == "gpt-4" {
            return false
        }
        
        // Default to true for unknown models (most modern models support vision)
        return true
    }
    
    /// Probe if a model actually supports vision by sending a tiny test image
    /// This is more accurate than name-based detection but takes a few seconds
    @available(*, deprecated, message: "Use supportsVision for faster name-based detection")
    private func probeVisionSupport(
        modelName: String,
        copilotToken: String
    ) async -> Bool {
        // 1x1 transparent PNG in base64
        let tinyPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="

        let baseURL = deriveCopilotApiBaseURL(from: copilotToken)
        let chatURL = "\(baseURL)/chat/completions"
        var request = URLRequest(url: URL(string: chatURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(copilotToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(copilotIntegrationId, forHTTPHeaderField: "Copilot-Integration-Id")
        request.setValue(copilotEditorPluginVersion, forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue(copilotEditorVersion, forHTTPHeaderField: "Editor-Version")
        request.setValue(copilotUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("true", forHTTPHeaderField: "Copilot-Vision-Request")
        request.timeoutInterval = 10
        
        // Build a minimal vision request
        let messageContent: [[String: Any]] = [
            ["type": "text", "text": "What color is this?"],
            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(tinyPNG)", "detail": "low"]]
        ]
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [["role": "user", "content": messageContent]],
            "stream": false,
            "max_tokens": 10
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            // 200 = success, model supports vision
            // 400 with "vision" error = model doesn't support vision
            if httpResponse.statusCode == 200 {
                print("[CopilotService] Model \(modelName) supports vision ✅")
                return true
            } else {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("[CopilotService] Vision probe for \(modelName) failed: \(errorBody)")
                }
                return false
            }
        } catch {
            print("[CopilotService] Vision probe error for \(modelName): \(error.localizedDescription)")
            return false
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
            guard let accessToken = getStoredAccessToken(apiId: modelAPI.id) else {
                throw CopilotError.unauthorized
            }
            
            let (copilotToken, baseURL) = try await getCopilotToken(accessToken: accessToken, apiId: modelAPI.id)
            
            let chatURL = "\(baseURL)/chat/completions"
            var request = URLRequest(url: URL(string: chatURL)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(copilotToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(copilotIntegrationId, forHTTPHeaderField: "Copilot-Integration-Id")
            request.setValue(copilotEditorPluginVersion, forHTTPHeaderField: "Editor-Plugin-Version")
            request.setValue(copilotEditorVersion, forHTTPHeaderField: "Editor-Version")
            request.setValue(copilotUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue(githubApiVersion, forHTTPHeaderField: "x-github-api-version")
            request.setValue("user", forHTTPHeaderField: "X-Initiator")  // Zed-style initiator
            request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
            
            let requestData = CopilotChatRequestData(from: chatRequest)
            
            // Add vision header if request contains images
            if requestData.hasImages {
                request.setValue("true", forHTTPHeaderField: "Copilot-Vision-Request")
                print("[CopilotService] Vision request detected, adding Copilot-Vision-Request header")
            }
            
            let jsonData = try JSONEncoder().encode(requestData)
            request.httpBody = jsonData
            
            // Debug: Print request body for troubleshooting
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let truncated = jsonString.count > 500 ? String(jsonString.prefix(500)) + "..." : jsonString
                print("[CopilotService] Request body: \(truncated)")
            }
            
            print("[CopilotService] Sending chat request to: \(chatURL)")
            print("[CopilotService] Model: \(chatRequest.modelName)")
            
            // First, check if the request succeeds before streaming
            let session = URLSession.shared
            let (responseData, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CopilotError.networkError
            }
            
            print("[CopilotService] Response status code: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                // Log the error response body for debugging
                if let errorBody = String(data: responseData, encoding: .utf8) {
                    print("[CopilotService] Error response body: \(errorBody)")
                }
                
                switch httpResponse.statusCode {
                case 401:
                    throw CopilotError.unauthorized
                case 403:
                    throw CopilotError.accessDenied
                default:
                    let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                    throw CopilotError.unknownError("HTTP \(httpResponse.statusCode): \(errorBody)")
                }
            }
            
            // Parse SSE response manually since we already have the data
            let responseString = String(data: responseData, encoding: .utf8) ?? ""
            let lines = responseString.components(separatedBy: "\n")
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                guard trimmedLine.hasPrefix("data:") else { continue }
                
                let jsonPart = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                guard jsonPart != "[DONE]", !jsonPart.isEmpty else { continue }
                
                if let jsonData = jsonPart.data(using: .utf8) {
                    do {
                        let element = try JSONDecoder().decode(CopilotChatResponse.self, from: jsonData)
                        let chatResponse = ChatResponse(from: element, modelName: chatRequest.modelName)
                        await handler(ChatCompletion.receiving(chatResponse))
                    } catch {
                        print("[CopilotService] Failed to decode chunk: \(jsonPart)")
                    }
                }
            }
            
            await handler(ChatCompletion.finished)
        } catch {
            print("[CopilotService] Chat error: \(error)")
            let errorMessage = "Copilot chat error: \(error.localizedDescription)"
            await handler(ChatCompletion.failure(SimpleError(message: errorMessage)))
        }
    }
}

// MARK: - Data Structures

extension CopilotService {
    struct DeviceCodeResponse: Decodable, Sendable {
        let deviceCode: String
        let userCode: String
        let verificationUri: String
        let expiresIn: Int
        let interval: Int
    }
    
    struct AccessTokenResponse: Decodable {
        let accessToken: String?
        let tokenType: String?
        let scope: String?
        let error: String?
        let errorDescription: String?
    }
    
    struct CopilotTokenResponse: Decodable {
        let token: String
        let expiresAt: Int
        let endpoints: Endpoints?
        
        struct Endpoints: Decodable {
            let api: String?
        }
    }
    
    struct CopilotModelsResponse: Decodable {
        let data: [CopilotModel]
        
        struct CopilotModel: Decodable {
            let id: String
            let object: String?
        }
    }
    
    /// Copilot chat streaming response - more lenient than OpenAI
    struct CopilotChatResponse: Decodable {
        let id: String?
        let object: String?
        let created: Int?
        let model: String?  // Optional - may not be present in streaming chunks
        let choices: [Choice]?
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
    
    struct CopilotChatRequestData: Encodable {
        let model: String
        let messages: [Message]
        let stream: Bool
        let temperature: Float?
        let maxTokens: Int?
        let topP: Float?
        
        /// Indicates if this request contains images (for vision header)
        let hasImages: Bool
        
        /// OpenAI-compatible message with support for multimodal content (text + images)
        struct Message: Encodable {
            let role: String
            let content: MessageContent
            
            /// Content can be either a simple string or an array of content parts (for multimodal)
            enum MessageContent: Encodable {
                case text(String)
                case parts([ContentPart])
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
                    case .text(let text):
                        try container.encode(text)
                    case .parts(let parts):
                        try container.encode(parts)
                    }
                }
            }
            
            /// A content part can be text or an image URL
            struct ContentPart: Encodable {
                let type: String
                let text: String?
                let imageUrl: ImageURL?
                
                struct ImageURL: Encodable {
                    let url: String  // data:image/jpeg;base64,{base64_data} or https://...
                    let detail: String?  // "auto", "low", "high"
                    
                    private enum CodingKeys: String, CodingKey {
                        case url, detail
                    }
                }
                
                private enum CodingKeys: String, CodingKey {
                    case type, text
                    case imageUrl = "image_url"
                }
                
                static func text(_ text: String) -> ContentPart {
                    ContentPart(type: "text", text: text, imageUrl: nil)
                }
                
                static func imageUrl(_ url: String, detail: String? = "auto") -> ContentPart {
                    ContentPart(type: "image_url", text: nil, imageUrl: ImageURL(url: url, detail: detail))
                }
            }
            
            init(role: String, content: String) {
                self.role = role
                self.content = .text(content)
            }
            
            init(role: String, parts: [ContentPart]) {
                self.role = role
                self.content = .parts(parts)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case model, messages, stream, temperature
            case maxTokens = "max_tokens"
            case topP = "top_p"
            // hasImages is not encoded - it's only used internally
        }
        
        init(from chatRequest: ChatRequest) {
            self.model = chatRequest.modelName
            self.stream = true
            self.temperature = chatRequest.modelParameter.enableTemperature ? chatRequest.modelParameter.temperature : nil
            self.maxTokens = chatRequest.modelParameter.enableOutputTokens ? chatRequest.modelParameter.outputTokens : nil
            self.topP = chatRequest.modelParameter.enableTopP ? chatRequest.modelParameter.topP : nil
            
            var allMessages: [Message] = []
            var containsImages = false
            if chatRequest.modelParameter.enableSystemPrompt, !chatRequest.modelParameter.systemPrompt.isEmpty {
                allMessages.append(Message(role: "system", content: chatRequest.modelParameter.systemPrompt))
            }
            
            // Add conversation messages
            for message in chatRequest.messages {
                var textContent = ""
                var imageBase64Strings: [String] = []
                
                for part in message.parts {
                    switch part {
                    case .text(let text):
                        textContent += text
                        
                    case .attachmentsData(let attachmentsData):
                        guard let attachmentsData, !attachmentsData.isEmpty else { continue }
                        
                        // Extract base64 encoded images from attachments
                        for (_, attachment) in attachmentsData {
                            if let base64String = Self.extractImageBase64(from: attachment) {
                                imageBase64Strings.append(base64String)
                                containsImages = true
                            }
                        }
                    }
                }
                
                // Build message with or without images
                if imageBase64Strings.isEmpty {
                    // Text only message
                    if !textContent.isEmpty {
                        allMessages.append(Message(role: message.role.rawValue, content: textContent))
                    }
                } else {
                    // Multimodal message with images
                    var contentParts: [Message.ContentPart] = []
                    
                    // Add text part first if present
                    if !textContent.isEmpty {
                        contentParts.append(.text(textContent))
                    }
                    
                    // Add image parts
                    for base64String in imageBase64Strings {
                        let dataUrl = "data:image/jpeg;base64,\(base64String)"
                        contentParts.append(.imageUrl(dataUrl, detail: "auto"))
                    }
                    
                    if !contentParts.isEmpty {
                        allMessages.append(Message(role: message.role.rawValue, parts: contentParts))
                    }
                }
            }
            
            self.messages = allMessages
            self.hasImages = containsImages
        }
        
        /// Extract base64 encoded image data from an attachment
        private static func extractImageBase64(from attachment: AttachmentData) -> String? {
            #if os(macOS)
            // Try to get image data from bookmark
            let imageData: Data? = FileManager.default.accessFile(from: attachment.bookmark) { url -> Data in
                // Check if file is an image type
                guard let uti = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                      uti.conforms(to: .image) else {
                    throw SimpleError(message: "Not an image file")
                }
                
                // Load image data
                guard let imageData = try? Data(contentsOf: url) else {
                    throw SimpleError(message: "Cannot load image data")
                }
                
                // Convert to JPEG if needed for optimal API compatibility
                if let nsImage = NSImage(data: imageData),
                   let tiffData = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                    return jpegData
                }
                
                return imageData
            }
            
            return imageData?.base64EncodedString()
            #else
            // iOS implementation - use thumbnail if available
            if let thumbnailData = attachment.thumbnail {
                return thumbnailData.base64EncodedString()
            }
            return nil
            #endif
        }
    }
}

// MARK: - Errors

enum CopilotError: Error, LocalizedError {
    case deviceFlowFailed
    case networkError
    case tokenExpired
    case accessDenied
    case unauthorized
    case tokenFetchFailed(Int)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .deviceFlowFailed:
            return "Failed to start device authorization flow"
        case .networkError:
            return "Network error occurred"
        case .tokenExpired:
            return "Authorization token expired. Please sign in again."
        case .accessDenied:
            return "Access was denied. Please authorize the application."
        case .unauthorized:
            return "Not authorized. Please sign in to GitHub Copilot."
        case .tokenFetchFailed(let code):
            return "Failed to fetch Copilot token (HTTP \(code))"
        case .unknownError(let msg):
            return "Unknown error: \(msg)"
        }
    }
}

// MARK: - ChatResponse Extension for Copilot

extension ChatResponse {
    /// Initialize ChatResponse from CopilotChatResponse for streaming compatibility
    init(from copilotResponse: CopilotService.CopilotChatResponse, modelName: String) {
        // Use provided modelName as fallback since Copilot streaming may not include model
        self.model = copilotResponse.model ?? modelName
        
        // Convert Unix timestamp to Date, or use current date
        if let created = copilotResponse.created {
            self.createdAt = Date(timeIntervalSince1970: TimeInterval(created))
        } else {
            self.createdAt = Date()
        }
        
        // Check if this is the final chunk
        let isFinished = copilotResponse.choices?.first?.finishReason != nil
        self.done = isFinished
        self.doneReason = copilotResponse.choices?.first?.finishReason
        
        // Extract content from streaming delta or complete message
        var textContent: String = ""
        if let choice = copilotResponse.choices?.first {
            // For streaming, content is in delta
            if let delta = choice.delta, let content = delta.content {
                textContent = content
            }
            // For non-streaming, content is in message
            else if let message = choice.message, let content = message.content {
                textContent = content
            }
        }
        
        // Build the message with extracted content
        if !textContent.isEmpty {
            self.message = ChatResponse.Message(
                role: .assistant,
                parts: [.text(textContent)]
            )
        } else {
            self.message = nil
        }
        
        // Convert usage statistics if available
        if let usage = copilotResponse.usage {
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
