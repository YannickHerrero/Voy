import Foundation
import Testing
@testable import Voy

struct InventoryCalculationsTests {
    @Test func countsQuantitiesByStatusAndNomadicMembership() {
        let nomadicID = UUID()
        let techID = UUID()
        let inputs = [
            InventorySummaryInput(
                id: UUID(), name: "Laptop", categoryID: techID,
                collectionIDs: [nomadicID], status: .owned, quantity: 1
            ),
            InventorySummaryInput(
                id: UUID(), name: "T-shirts", categoryID: UUID(),
                collectionIDs: [], status: .owned, quantity: 3
            ),
            InventorySummaryInput(
                id: UUID(), name: "Chair", categoryID: UUID(),
                collectionIDs: [], status: .outgoing, quantity: 1
            ),
            InventorySummaryInput(
                id: UUID(), name: "Old phone", categoryID: techID,
                collectionIDs: [], status: .archived, quantity: 2
            )
        ]

        let metrics = InventoryCalculations.metrics(for: inputs, nomadicCollectionID: nomadicID)

        #expect(metrics.ownedCount == 4)
        #expect(metrics.outgoingCount == 1)
        #expect(metrics.archivedCount == 2)
        #expect(metrics.nomadicCount == 1)
        #expect(metrics.toRemoveCount == 3)
        #expect(metrics.categoryCounts[techID] == 1)
    }

    @Test func filteringCombinesSearchCategoryCollectionAndStatus() {
        let categoryID = UUID()
        let travelID = UUID()
        let item = InventorySummaryInput(
            id: UUID(), name: "MacBook Air", categoryID: categoryID,
            collectionIDs: [travelID], status: .owned, quantity: 1
        )

        #expect(InventoryFilter(searchText: "book", categoryID: categoryID, collectionID: travelID, status: .owned).includes(item))
        #expect(!InventoryFilter(searchText: "phone").includes(item))
        #expect(!InventoryFilter(excludesCollectionID: travelID).includes(item))
    }
}
