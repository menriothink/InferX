import Foundation
import SwiftData

extension ModelAPI {
    var localModelsDir: URL? {
        get {
            guard var modelsDirBookmark = self.modelsDirBookmark else { return nil }
            let url = FileManager.default.getResolvedURL(from: &modelsDirBookmark)
            self.modelsDirBookmark = modelsDirBookmark
            return url
        }
        set {
            self.modelsDirBookmark = nil
            if let modelDir = newValue {
                if let url = FileManager.default.securityAccessFile(url: modelDir) {
                    self.modelsDirBookmark = FileManager.default.getBookmark(for: url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }

    var modelProvider: ModelProvider {
        get {
            ModelProvider(rawValue: providerRaw) ?? .none
        }
        set {
            providerRaw = newValue.rawValue
        }
    }

    convenience init(
        name: String,
        modelProvider: ModelProvider,
        endPoint: String,
        apiKey: String = "",
        localModelsDir: URL? = nil
    ) {
        var modelDirBookmark: Data? = nil
        if let modelDir = localModelsDir {
            modelDirBookmark = FileManager.default.getBookmark(for: modelDir)
        }

        self.init(
            name: name,
            providerRaw: modelProvider.rawValue,
            endPoint: endPoint,
            apiKey: apiKey,
            modelsDirBookmark: modelDirBookmark,
            isAvailable: false
        )
    }

    enum ModelAPIError: Error, LocalizedError {
        case nameAlreadyExists(String)
        case emptyNameNotAllowed

        var errorDescription: String? {
            switch self {
            case .nameAlreadyExists(let name):
                return "Name '\(name)' already exists, please use another name."
            case .emptyNameNotAllowed:
                return "Name cannot be empty."
            }
        }
    }
}
