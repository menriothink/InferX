import Foundation
import SwiftData

extension SchemaV0 {
    @Model
    final class ModelAPI: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
        var name: String = ""
        var providerRaw: String = ""
        var createdAt: Date = Date()
        var endPoint: String = ""
        var modelsDirBookmark: Data? = nil
        var isAvailable: Bool = false

        var apiKey: String {
            get {
                if let key = KeychainHelper.load(key: "apiKey:\(id.uuidString)") {
                    return key
                }
                return ""
            }
            set {
                KeychainHelper.save(key: "apiKey:\(id.uuidString)", value: newValue)
            }
        }

        #Index<ModelAPI>(
            [\.id],
            [\.name]
        )

        init(
            name: String,
            providerRaw: String,
            endPoint: String,
            apiKey: String,
            modelsDirBookmark: Data?,
            isAvailable: Bool
        ) {
            self.name = name
            self.providerRaw = providerRaw
            self.endPoint = endPoint
            self.modelsDirBookmark = modelsDirBookmark
            self.isAvailable = isAvailable
            self.apiKey = apiKey
        }
    }
}
