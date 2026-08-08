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

        let existingCollections = try context.fetch(FetchDescriptor<InventoryCollection>())
        var nomadicCollectionID = existingCollections.first {
            $0.name.localizedCaseInsensitiveCompare("Nomadic") == .orderedSame
        }?.id
        if existingCollections.isEmpty {
            for name in defaultCollectionNames {
                let collection = InventoryCollection(name: name)
                context.insert(collection)
                if name == "Nomadic" {
                    nomadicCollectionID = collection.id
                }
            }
            didChange = true
        }

        var settingsDescriptor = FetchDescriptor<MinimalismSettings>()
        settingsDescriptor.fetchLimit = 1
        if try context.fetch(settingsDescriptor).isEmpty {
            context.insert(MinimalismSettings(nomadicCollectionID: nomadicCollectionID))
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
