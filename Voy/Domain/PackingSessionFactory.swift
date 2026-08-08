import Foundation
import SwiftData

enum PackingSessionFactory {
    @MainActor
    static func create(
        from template: PackingTemplate,
        name: String,
        startDate: Date,
        templateEntries: [PackingTemplateEntry],
        items: [InventoryItem],
        in context: ModelContext
    ) -> PackingSession {
        let session = PackingSession(
            templateID: template.id,
            name: name,
            startDate: startDate
        )
        context.insert(session)
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        for (index, templateEntry) in templateEntries
            .filter({ $0.templateID == template.id })
            .enumerated() {
            guard let item = itemsByID[templateEntry.itemID] else { continue }
            context.insert(PackingSessionEntry(
                sessionID: session.id,
                itemID: item.id,
                itemNameSnapshot: item.name,
                thumbnailSnapshot: item.thumbnailData,
                quantity: templateEntry.quantity,
                weightGramsPerUnit: item.weightGrams,
                sortOrder: index
            ))
        }
        return session
    }

    @MainActor
    static func add(
        item: InventoryItem,
        to session: PackingSession,
        sortOrder: Int,
        in context: ModelContext
    ) {
        context.insert(PackingSessionEntry(
            sessionID: session.id,
            itemID: item.id,
            itemNameSnapshot: item.name,
            thumbnailSnapshot: item.thumbnailData,
            quantity: 1,
            weightGramsPerUnit: item.weightGrams,
            sortOrder: sortOrder
        ))
        session.modifiedAt = Date()
    }
}
