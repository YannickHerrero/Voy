import SwiftData
import Testing
@testable import Voy

struct PackingSessionFactoryTests {
    @Test @MainActor func sessionChangesDoNotModifyTemplateEntries() throws {
        let container = try DataSchema.inMemoryContainer()
        let context = container.mainContext
        let item = InventoryItem(name: "T-shirt", quantity: 5, weightGrams: 180)
        let template = PackingTemplate(name: "One Week")
        let templateEntry = PackingTemplateEntry(templateID: template.id, itemID: item.id, quantity: 3)
        context.insert(item)
        context.insert(template)
        context.insert(templateEntry)

        let session = PackingSessionFactory.create(
            from: template,
            name: "Japan",
            startDate: .now,
            templateEntries: [templateEntry],
            items: [item],
            in: context
        )
        try context.save()
        let sessionEntries = try context.fetch(FetchDescriptor<PackingSessionEntry>())
        let sessionEntry = try #require(sessionEntries.first)
        sessionEntry.isPacked = true
        sessionEntry.quantity = 1
        try context.save()

        #expect(session.templateID == template.id)
        #expect(templateEntry.quantity == 3)
        #expect(sessionEntry.quantity == 1)
        #expect(sessionEntry.itemNameSnapshot == "T-shirt")
        #expect(sessionEntry.weightGramsPerUnit == 180)
    }

    @Test @MainActor func snapshotRemainsMeaningfulAfterItemChanges() throws {
        let container = try DataSchema.inMemoryContainer()
        let context = container.mainContext
        let item = InventoryItem(name: "Laptop", weightGrams: 1_240)
        let template = PackingTemplate(name: "Work")
        let templateEntry = PackingTemplateEntry(templateID: template.id, itemID: item.id)

        let session = PackingSessionFactory.create(
            from: template,
            name: "Conference",
            startDate: .now,
            templateEntries: [templateEntry],
            items: [item],
            in: context
        )
        item.name = "Renamed Laptop"
        item.status = .archived

        let snapshots = try context.fetch(FetchDescriptor<PackingSessionEntry>())
        let snapshot = try #require(snapshots.first { $0.sessionID == session.id })
        #expect(snapshot.itemNameSnapshot == "Laptop")
        #expect(snapshot.weightGramsPerUnit == 1_240)
    }
}
