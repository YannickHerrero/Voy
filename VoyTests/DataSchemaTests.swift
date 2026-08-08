import Foundation
import SwiftData
import Testing
@testable import Voy

struct DataSchemaTests {
    @Test @MainActor func allModelsRoundTripInLocalStore() throws {
        let container = try DataSchema.inMemoryContainer()
        let context = container.mainContext
        let category = InventoryCategory(name: "Tech")
        let collection = InventoryCollection(name: "Travel")
        let item = InventoryItem(
            name: "Laptop",
            categoryID: category.id,
            quantity: 1,
            weightGrams: 1_240,
            collectionIDs: [collection.id]
        )
        context.insert(category)
        context.insert(collection)
        context.insert(item)
        try context.save()

        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        #expect(items.count == 1)
        #expect(items.first?.name == "Laptop")
        #expect(items.first?.collectionIDs == [collection.id])
    }

    @Test @MainActor func seedingIsIdempotent() throws {
        let container = try DataSchema.inMemoryContainer()
        let context = container.mainContext

        try DataSeeder.seedIfNeeded(in: context)
        try DataSeeder.seedIfNeeded(in: context)

        let categories = try context.fetch(FetchDescriptor<InventoryCategory>())
        let collections = try context.fetch(FetchDescriptor<InventoryCollection>())
        let settings = try context.fetch(FetchDescriptor<MinimalismSettings>())
        #expect(categories.count == DataSeeder.defaultCategoryNames.count)
        #expect(collections.count == DataSeeder.defaultCollectionNames.count)
        #expect(settings.count == 1)
    }
}
