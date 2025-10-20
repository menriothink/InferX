import Foundation
import SwiftData

enum SchemaV0: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(0, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SchemaV0.Conversation.self, SchemaV0.Message.self, SchemaV0.Model.self, SchemaV0.ModelAPI.self]
    }
}
