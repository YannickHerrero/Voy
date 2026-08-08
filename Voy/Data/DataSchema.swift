import SwiftData

enum DataSchema {
    static let schema = Schema([
        InventoryItem.self,
        InventoryCategory.self,
        InventoryCollection.self,
        PackingTemplate.self,
        PackingTemplateEntry.self,
        PackingSession.self,
        PackingSessionEntry.self,
        MinimalismSettings.self,
        InventorySnapshot.self
    ])

    static func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "VoyPreview",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
