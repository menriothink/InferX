//
//  OKHttpClient.swift
//  InferX
//
//  Created by mingdw on 2025/5/24.
//

import Foundation

actor OKHTTPClient {
    private let decoder: JSONDecoder = .default
    static let shared = OKHTTPClient()
    private var proxiedUrlConfiguration: URLSessionConfiguration? = nil
    private let directUrlConfiguration: URLSessionConfiguration  = .default
    private var ignorHostList: [String] = []

    // MARK: - Upload Session Properties
    private var activeUploads = [Int: (progressHandler: ((Progress) -> Void)?, continuation: CheckedContinuation<Data, Error>)]()

    func setProxy(proxyHost: String? = nil, proxyPort: UInt32? = nil) {
        if let host = proxyHost, let port = proxyPort, !host.isEmpty {
            print("🔧 Configuring URLSession configuration with proxy: \(host):\(port)")
            self.proxiedUrlConfiguration = .default
            self.proxiedUrlConfiguration?.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: 1,
                kCFNetworkProxiesHTTPProxy: host,
                kCFNetworkProxiesHTTPPort: port,
                kCFNetworkProxiesHTTPSEnable: 1,
                kCFNetworkProxiesHTTPSProxy: host,
                kCFNetworkProxiesHTTPSPort: port
            ]
        } else {
            self.proxiedUrlConfiguration = nil
            print("🔧 Configuring URLSession configuration without proxy.")
        }
    }

    func setIgnorHost(ignorHost: String) {
        let separators = CharacterSet(charactersIn: ", ")
        let substrings = ignorHost.components(separatedBy: separators)

        self.ignorHostList = substrings
                .filter { !$0.isEmpty }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func session(
        for request: URLRequest,
        delegate: URLSessionDelegate? = nil,
        delegateQueue: OperationQueue? = nil
    ) -> URLSession {
        return URLSession(
            configuration: configuration(for: request),
            delegate: delegate,
            delegateQueue: delegateQueue
        )
    }

    func configuration(for request: URLRequest) -> URLSessionConfiguration {
        let host = request.url?.host ?? ""
        if self.proxiedUrlConfiguration == nil || self.ignorHostList.contains(host) {
            self.directUrlConfiguration.timeoutIntervalForRequest = 30
            return self.directUrlConfiguration
        }

        self.proxiedUrlConfiguration?.timeoutIntervalForRequest = 30
        return self.proxiedUrlConfiguration!
    }
}

extension OKHTTPClient {
    static let retryCount = 2
    static let retryIntervar = 5
    func send(request: URLRequest) async throws -> Void {
        for attempt in 1...OKHTTPClient.retryCount {
            do {
                let sessionToUse = session(for: request)
                let (_, response) = try await sessionToUse.data(for: request)
                try validate(response: response)
            } catch {
                if attempt == OKHTTPClient.retryCount {
                    //print("🚨 Request failed after \(attempt) attempts. Error: \(error)")
                    throw error
                }
                try await Task.sleep(for: .seconds(OKHTTPClient.retryIntervar))
            }
        }
    }

    func send<T: Decodable>(request: URLRequest, with responseType: T.Type) async throws -> T {
        for attempt in 1...OKHTTPClient.retryCount {
            do {
                let sessionToUse = session(for: request)
                let (data, response) = try await sessionToUse.data(for: request)
                try validate(response: response)
                return try decoder.decode(T.self, from: data)
            } catch {
                if attempt == OKHTTPClient.retryCount {
                    throw error
                }
                try await Task.sleep(for: .seconds(OKHTTPClient.retryIntervar))
            }
        }
        throw URLError(.unknown, userInfo: ["message": "Retry logic failed unexpectedly after all attempts."])
    }

    func send<T: Decodable>(request: URLRequest, with responseType: T.Type) async throws -> (T, URLResponse) {
        for attempt in 1...OKHTTPClient.retryCount {
            do {
                let sessionToUse = session(for: request)
                let (data, response) = try await sessionToUse.data(for: request)
                try validate(response: response)
                let decodedObject = try decoder.decode(T.self, from: data)
                return (decodedObject, response)
            } catch {
                if attempt == OKHTTPClient.retryCount {
                    throw error
                }
                try await Task.sleep(for: .seconds(OKHTTPClient.retryIntervar))
            }
        }
        throw URLError(.unknown, userInfo: ["message": "Retry logic failed unexpectedly after all attempts."])
    }

    func send(request: URLRequest) async throws -> (Data, URLResponse) {
        for attempt in 1...OKHTTPClient.retryCount {
            do {
                let sessionToUse = session(for: request)
                let (data, response) = try await sessionToUse.data(for: request)
                try validate(response: response)
                return (data, response)
            } catch {
                if attempt == OKHTTPClient.retryCount {
                    //print("🚨 Request failed after \(attempt) attempts. Error: \(error)")
                    throw error
                }
                try await Task.sleep(for: .seconds(OKHTTPClient.retryIntervar))
            }
        }
        throw URLError(.unknown, userInfo: ["message": "Retry logic failed unexpectedly after all attempts."])
    }

    func stream<T: Decodable & Sendable>(
        request: URLRequest,
        with responseType: T.Type
    ) -> AsyncThrowingStream<T, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let streamConfig = self.configuration(for: request)
                    
                    streamConfig.timeoutIntervalForRequest = 300
                    streamConfig.timeoutIntervalForResource = 600

                    let sessionToUse = URLSession(configuration: streamConfig)
                    
                    let (bytes, response) = try await sessionToUse.bytes(for: request)
                    try self.validate(response: response)

                    continuation.onTermination = { terminationState in
                        if case .cancelled = terminationState {
                            bytes.task.cancel()
                        }
                    }

                    var buffer = Data()

                    for try await byte in bytes {
                        buffer.append(byte)

                        while let chunk = self.extractNextJSON(from: &buffer) {
                            do {
                                let decodedObject = try self.decoder.decode(T.self, from: chunk)
                                continuation.yield(decodedObject)
                            } catch {
                                continuation.finish(throwing: error)
                                return
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

private extension OKHTTPClient {
    func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func extractNextJSON(from buffer: inout Data) -> Data? {
        var isEscaped = false
        var isWithinString = false
        var nestingDepth = 0
        var objectStartIndex = buffer.startIndex

        for (index, byte) in buffer.enumerated() {
            let character = Character(UnicodeScalar(byte))

            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                isWithinString.toggle()
            } else if !isWithinString {
                switch character {
                case "{":
                    nestingDepth += 1
                    if nestingDepth == 1 {
                        objectStartIndex = index
                    }
                case "}":
                    nestingDepth -= 1
                    if nestingDepth == 0 {
                        let range = objectStartIndex..<buffer.index(after: index)
                        let jsonObject = buffer.subdata(in: range)
                        buffer.removeSubrange(range)

                        return jsonObject
                    }
                default:
                    break
                }
            }
        }

        return nil
    }
}

extension OKHTTPClient {
    func upload<T: Decodable>(
        request: URLRequest,
        fromFile fileURL: URL,
        progressHandler: @escaping @Sendable (Progress) async -> Void
    ) async throws -> T {
        let responseData = try await _upload(
            request: request,
            fromFile: fileURL,
            progressHandler: progressHandler
        )
        return try decoder.decode(T.self, from: responseData)
    }
    
    private func _upload(
        request: URLRequest,
        fromFile fileURL: URL,
        progressHandler: @escaping @Sendable (Progress) async -> Void
    ) async throws -> Data {
        
        let taskHolder = TaskHolder()
        
        return try await withTaskCancellationHandler {
            
            try await withCheckedThrowingContinuation { continuation in
                
                let uploadSessionDelegate = UploadSessionDelegate(onProgress: progressHandler)
                
                let sessionToUse = self.session(for: request, delegate: uploadSessionDelegate)
                
                let task = sessionToUse.uploadTask(with: request, fromFile: fileURL) { (responseData, response, error) in
                    
                    if let error = error {
                        if (error as? URLError)?.code == .cancelled {
                            continuation.resume(throwing: CancellationError())
                        } else {
                            continuation.resume(throwing: error)
                        }
                        return
                    }

                    if let httpResponse = response as? HTTPURLResponse {
                        if !(200...299).contains(httpResponse.statusCode) {
                            continuation.resume(throwing: SimpleError(message: "httpResponse \(httpResponse), request \(request), error: \(String(describing: error?.localizedDescription))"))
                            return
                        }
                    } else {
                        continuation.resume(throwing: SimpleError(message: "httpResponse nil, request \(request), error: \(String(describing: error?.localizedDescription))"))
                        return
                    }

                    guard let responseData = responseData else {
                        continuation.resume(throwing: SimpleError(message: "Response data was nil, request \(request), error: \(String(describing: error?.localizedDescription))"))
                        return
                    }
                    
                    continuation.resume(returning: responseData)
                }

                Task { await taskHolder.setTask(task) }
                task.resume()
            }
        } onCancel: {
            Task {
                await taskHolder.cancel()
            }
        }
    }
}

private actor TaskHolder {
    private var task: URLSessionUploadTask?

    func setTask(_ task: URLSessionUploadTask) {
        self.task = task
    }

    func cancel() {
        print("Cancellation detected, cancelling URLSessionUploadTask...")
        task?.cancel()
        task = nil
    }
}

private final class UploadSessionDelegate: NSObject, URLSessionTaskDelegate {
    private let onProgress: @Sendable (Progress) async -> Void
    
    init(onProgress: @escaping @Sendable (Progress) async -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        Task {
            let progress = Progress(totalUnitCount: totalBytesExpectedToSend)
            progress.completedUnitCount = totalBytesSent
            await self.onProgress(progress)
        }
    }
}
