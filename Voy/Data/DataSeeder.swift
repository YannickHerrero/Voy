import Foundation
import SwiftData

enum DataSeeder {
    static let defaultCategoryNames = [
        "Clothing", "Tech", "Furniture", "Running", "Toiletries",
        "Kitchen", "Documents", "Bags", "Shoes", "Other"
    ]

    static let defaultCollectionNames = ["Home", "Travel", "Work", "EDC", "Running", "Nomadic"]

    @MainActor
    static func seedIfNeeded(in context: ModelContext) throws {
        var didChange = false

        var categoryDescriptor = FetchDescriptor<InventoryCategory>()
        categoryDescriptor.fetchLimit = 1
        if try context.fetch(categoryDescriptor).isEmpty {
            for (index, name) in defaultCategoryNames.enumerated() {
                context.insert(InventoryCategory(name: name, sortOrder: index))
            }
            didChange = true
        }

        var collectionDescriptor = FetchDescriptor<InventoryCollection>()
        collectionDescriptor.fetchLimit = 1
        if try context.fetch(collectionDescriptor).isEmpty {
            for name in defaultCollectionNames {
                context.insert(InventoryCollection(name: name))
            }
            didChange = true
        }

        var settingsDescriptor = FetchDescriptor<MinimalismSettings>()
        settingsDescriptor.fetchLimit = 1
        if try context.fetch(settingsDescriptor).isEmpty {
            context.insert(MinimalismSettings())
            didChange = true
        }

        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        if try InventoryHistoryRecorder.record(items: items, in: context) {
            didChange = true
        }

        if didChange {
            try context.save()
        }
    }
}
