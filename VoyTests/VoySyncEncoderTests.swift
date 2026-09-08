import Foundation
import SwiftData
import Testing
@testable import Voy

struct VoySyncEncoderTests {
    @Test @MainActor func exportsCompleteDeterministicSnapshotAndDeduplicatesMedia() throws {
        let container = try DataSchema.inMemoryContainer()
        let context = container.mainContext
        let category = InventoryCategory(name: "Technology", sortOrder: 1)
        let collection = InventoryCollection(name: "Nomadic")
        let displayData = Data("shared-photo".utf8)
        let originalData = Data("original-photo".utf8)
        let item = InventoryItem(
            name: "Laptop",
            imageData: displayData,
            thumbnailData: displayData,
            originalImageData: originalData,
            categoryID: category.id,
            itemDescription: "Daily computer",
            weightGrams: 1_240,
            collectionIDs: [collection.id],
            reviewedDetailRawValues: [InventoryDetailField.weight.rawValue],
            sourceURL: URL(string: "https://example.com/laptop")
        )
        let template = PackingTemplate(name: "Work")
        let templateEntry = PackingTemplateEntry(templateID: template.id, itemID: item.id)
        let session = PackingSession(templateID: template.id, name: "Conference")
        let sessionEntry = PackingSessionEntry(
            sessionID: session.id,
            itemID: item.id,
            itemNameSnapshot: item.name,
            thumbnailSnapshot: displayData,
            weightGramsPerUnit: item.weightGrams,
            isPacked: true
        )
        let settings = MinimalismSettings(possessionGoal: 100, nomadicCollectionID: collection.id)
        let history = InventorySnapshot(ownedCount: 1, outgoingCount: 0, archivedCount: 0)

        context.insert(category)
        context.insert(collection)
        context.insert(item)
        context.insert(template)
        context.insert(templateEntry)
        context.insert(session)
        context.insert(sessionEntry)
        context.insert(settings)
        context.insert(history)
        try context.save()

        let generatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let deviceId = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let syncExport = try VoySyncEncoder.makeExport(
            from: context,
            deviceId: deviceId,
            generatedAt: generatedAt
        )

        #expect(syncExport.document.schemaVersion == 1)
        #expect(syncExport.document.deviceId == deviceId)
        #expect(syncExport.document.items.count == 1)
        #expect(syncExport.document.packingTemplateEntries.count == 1)
        #expect(syncExport.document.packingSessionEntries.count == 1)
        #expect(syncExport.document.minimalismSettings.count == 1)
        #expect(syncExport.document.inventorySnapshots.count == 1)
        #expect(syncExport.document.media.count == 2)
        #expect(syncExport.mediaData.count == 2)
        #expect(syncExport.document.items[0].imageHash == syncExport.document.items[0].thumbnailHash)
        #expect(syncExport.document.packingSessionEntries[0].thumbnailHash == syncExport.document.items[0].imageHash)

        let encoded = try VoySyncCoding.encoder().encode(syncExport.document)
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let items = try #require(json["items"] as? [[String: Any]])
        #expect(items[0]["description"] as? String == "Daily computer")
        #expect(items[0]["categoryId"] as? String == category.id.uuidString)
    }

    @Test @MainActor func fingerprintIgnoresSnapshotGenerationTime() throws {
        let container = try DataSchema.inMemoryContainer()
        let context = container.mainContext
        context.insert(InventoryItem(name: "Coat"))
        try context.save()
        let deviceId = UUID()
        let first = try VoySyncEncoder.makeExport(
            from: context,
            deviceId: deviceId,
            generatedAt: Date(timeIntervalSince1970: 100)
        ).document
        var second = first
        second.generatedAt = Date(timeIntervalSince1970: 200)

        let firstFingerprint = try VoySyncEncoder.fingerprint(for: first)
        let secondFingerprint = try VoySyncEncoder.fingerprint(for: second)
        #expect(firstFingerprint == secondFingerprint)
    }
}
