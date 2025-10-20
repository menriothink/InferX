//
//  SwiftDataService.swift
//  InferX
//
//  Created by mingdw on 2025/4/20.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataProvider {
    var container: ModelContainer
    var messageService: MessageService

    static let share = SwiftDataProvider()

    init() {
        self.container = {
            do {
                let schema = Schema(versionedSchema: SchemaV0.self)
                return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()

        self.messageService = MessageService(modelContainer: container)
    }
}

extension ModelContext {
    func saveChanges() throws {
        if self.hasChanges {
            try self.save()
        }
    }
}
