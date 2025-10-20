//
//  HFApi.swift
//  HuggingfaceHub
//
//  Created by John Mai on 2024/11/7.
//

import Foundation

struct HuggingFaceModel: Decodable, Sendable, Identifiable {
    let _id: String
    let id: String
    let likes: Int
    let trendingScore: Int?
    let `private`: Bool
    let modelId: String
    let downloads: Int
    let tags: [String]
    let pipeline_tag: String?
    let library_name: String?
    let createdAt: Date
    let lastModified: Date?
    let sha: String
    let siblings: [HuggingFaceSibling]?
    var filesMeta: [String : HFFileMeta]?

    struct HuggingFaceSibling: Decodable, Sendable {
        let rfilename: String
    }
}

actor HFApi {
    let endpoint: String
    let token: String?
    let libraryName: String?
    let libraryVersion: String?
    let userAgent: [String: String]?
    let headers: [String: String]?
    let httpClient: OKHTTPClient

    init(
        endpoint: String? = nil,
        token: String? = nil,
        libraryName: String? = nil,
        libraryVersion: String? = nil,
        userAgent: [String: String]? = nil,
        headers: [String: String]? = nil,
        httpClient: OKHTTPClient = .shared
    ) {
        self.endpoint = endpoint ?? Constants.endpoint
        self.token = token
        self.libraryName = libraryName
        self.libraryVersion = libraryVersion
        self.userAgent = userAgent
        self.headers = headers
        self.httpClient = httpClient
    }

    func buildHFHeaders(
        token: String? = nil,
        libraryName: String? = nil,
        libraryVersion: String? = nil,
        userAgent: [String: String]? = nil,
        headers: [String: String]? = nil
    ) -> [String: String] {
        var hfHeaders: [String: String] = [
            "user-agent": buildUserAgent(
                libraryName: libraryName ?? self.libraryName,
                libraryVersion: libraryVersion ?? self.libraryVersion,
                userAgent: userAgent
            )
        ]
        if let token {
            hfHeaders["authorization"] = "Bearer \(token)"
        } else if let token = self.token, !token.isEmpty {
            hfHeaders["authorization"] = "Bearer \(token)"
        }

        if let headers {
            hfHeaders.merge(headers) { _, new in new }
        }

        return hfHeaders
    }

    func buildUserAgent(
        libraryName: String? = nil,
        libraryVersion: String? = nil,
        userAgent: [String: String]? = nil
    ) -> String {
        var ua = "unknown/None"
        if let libraryName {
            ua = "\(libraryName)/\(libraryVersion ?? "")"
        }
        ua += "; hf_hub/\(Constants.version)"
        ua += "; swift/6.0"

        if let userAgent {
            for (key, value) in userAgent {
                ua += "; \(key)/\(value)"
            }
        }

        return deduplicateUserAgent(ua)
    }

    func deduplicateUserAgent(_ ua: String) -> String {
        let components = ua.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        return (NSOrderedSet(array: components).array as! [String]).joined(separator: "; ")
    }
}

extension HFApi {
    enum Error: Swift.Error, LocalizedError, Equatable {
        case invalidResponse
        case authenticationError
        case httpStatusCode(Int)
        case invalidExpandOptions

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "Invalid response received"
            case .authenticationError:
                "Authentication failed"
            case .httpStatusCode(let code):
                "HTTP error with status code: \(code)"
            case .invalidExpandOptions:
                "`expand` cannot be used if `securityStatus` or `files_metadata` are set."
            }
        }
    }
}

extension HFApi {
    func listModels(
        search: String? = nil,
        sort: String = "",
        limit: String = "20",
        direction: String = "-1",
        filter: String = "mlx",
    ) async throws -> (models: [HuggingFaceModel], nextUrl: URL?) {
        var urlComponents = URLComponents(string: "\(self.endpoint)/api/models")!
        var queryItems = [
            URLQueryItem(name: "limit", value: limit),
            //URLQueryItem(name: "author", value: "mlx-community"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "direction", value: direction),
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "full", value: "full"),
            //URLQueryItem(name: "config", value: "config")
        ]
        if let search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        urlComponents.queryItems = queryItems

        let request = try buildRequest(url: urlComponents.url!)
        let (models, response) = try await httpClient.send(request: request, with: [HuggingFaceModel].self)

        var nextUrl: URL? = nil
        if let httpResponse = response as? HTTPURLResponse,
           let linkHeader = httpResponse.value(forHTTPHeaderField: "Link") {
            nextUrl = parseNextLink(from: linkHeader)
        }

        return (models, nextUrl)

        //let updatedModels = try await updateModelsMeta(models: models)

        //return (updatedModels, nextUrl)
    }

    func listModels(nextPageUrl: URL) async throws -> (models: [HuggingFaceModel], nextUrl: URL?) {
        let request = try buildRequest(url: nextPageUrl)
        let (models, response) = try await httpClient.send(request: request, with: [HuggingFaceModel].self)

        var nextUrl: URL? = nil
        if let httpResponse = response as? HTTPURLResponse,
           let linkHeader = httpResponse.value(forHTTPHeaderField: "Link") {
            nextUrl = parseNextLink(from: linkHeader)
        }

        return (models, nextUrl)
    }

    func getRemoteModel(repoId: String) async throws -> HuggingFaceModel {
        let urlComponents = URLComponents(string: "\(self.endpoint)/api/models/\(repoId)")!
        let request = try buildRequest(url: urlComponents.url!)
        return try await httpClient.send(request: request, with: HuggingFaceModel.self)
    }
    
    func getRemoteModelInfo(repoId: String) async throws -> HuggingFaceModel {
        var model: HuggingFaceModel = try await self.getRemoteModel(repoId: repoId)

        try await withThrowingTaskGroup(of: (filename: String, meta: HFFileMeta).self) { group in
            if let siblings = model.siblings {
                let modelId = model.id
                for sibling in siblings {
                    let filename = sibling.rfilename
                    
                    group.addTask {
                        let fileMeta = try await self.getFileMetadata(repoId: modelId, filename: filename)
                        return (filename: filename, meta: fileMeta)
                    }
                }
            }

            for try await result in group {
                if model.filesMeta == nil {
                    model.filesMeta = [:]
                }
                model.filesMeta?[result.filename] = result.meta
            }
        }

        return model
    }
    
    func getFileMetadata(
        repoId: String,
        filename: String,
        repoType: RepoType = .model,
        revision: String = "main"
    ) async throws -> HFFileMeta {
        let url = HFUtility.hfHubURL(
            repoId: repoId,
            filename: filename,
            repoType: repoType,
            revision: revision,
            endpoint: endpoint
        )
        let request = try buildRequest(url: url, method: "HEAD")

        let sessionToUse = await httpClient.session(for: request)
        let (_, response) = try await sessionToUse.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        let commitHash = httpResponse.value(
            forHTTPHeaderField: Constants.huggingFaceHeaderXRepoCommit
        )

        guard let etag = normalizeEtag(
                    httpResponse.value(
                        forHTTPHeaderField: Constants.huggingFaceHeaderXLinkedEtag
                    ) ?? httpResponse.value(forHTTPHeaderField: "Etag")
                ) else { throw FileDownloader.FileDownloaderError.distantResourceNoEtag }

        let size = (
                httpResponse.value(
                    forHTTPHeaderField: Constants.huggingFaceHeaderXLinkedSize
                ) ?? httpResponse.value(forHTTPHeaderField: "Content-Length")
            )
            .flatMap(Int64.init)

        let location = httpResponse.url ?? url

        return HFFileMeta(commitHash: commitHash, etag: etag, location: location, size: size)
    }

    private func normalizeEtag(_ etag: String?) -> String? {
        guard let etag else {
            return nil
        }

        let normalized =
            etag
            .replacingOccurrences(
                of: "^W/",
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        return normalized
    }

    private func buildRequest(url: URL, method: String = "GET") throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = buildHFHeaders()
        return request
    }

    private func parseNextLink(from linkHeader: String) -> URL? {
        let links = linkHeader.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for link in links {
            let components = link.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count == 2 && components[1] == "rel=\"next\"" {
                let urlString = components[0].trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                return URL(string: urlString)
            }
        }
        return nil
    }

    private func updateModelsMeta(models: [HuggingFaceModel]) async throws -> [HuggingFaceModel] {
        var allFileMetas: [String: [String: HFFileMeta]] = [:]
        try await withThrowingTaskGroup(
            of: (modelId: String, filename: String, meta: HFFileMeta).self
        ) { group in
            for model in models {
                if let siblings = model.siblings {
                    for sibling in siblings {
                        group.addTask {
                            let fileMeta = try await self.getFileMetadata(
                                                            repoId: model.id,
                                                            filename: sibling.rfilename
                                                        )
                            return (modelId: model.id, filename: sibling.rfilename, meta: fileMeta)
                        }
                    }
                }
            }

            for try await result in group {
                allFileMetas[result.modelId, default: [:]][result.filename] = result.meta
            }
        }

        let updatedModels = models.map { model in
            var newModel = model
            if let metas = allFileMetas[model.id] {
                newModel.filesMeta = metas
            }
            return newModel
        }

        return updatedModels
    }
}
