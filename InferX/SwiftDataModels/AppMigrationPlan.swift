//
//  AppData.swift
//  InferX
//
//  Created by mingdw on 2025/6/28.
//

import SwiftData

typealias Message = SchemaV0.Message
typealias Conversation = SchemaV0.Conversation
typealias ModelAPI = SchemaV0.ModelAPI
typealias Model = SchemaV0.Model

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaV0.self
        ]
    }

    static var stages: [MigrationStage] {
        [
        ]
    }
}
