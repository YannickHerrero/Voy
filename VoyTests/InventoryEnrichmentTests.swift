import Foundation
import Testing
@testable import Voy

struct InventoryEnrichmentTests {
    @Test func detectsExplicitAndInferredCompletion() {
        let untouched = input(name: "Untouched")
        #expect(!InventoryDetailField.weight.isComplete(untouched))
        #expect(!InventoryDetailField.category.isComplete(untouched))
        #expect(!InventoryDetailField.quantity.isComplete(untouched))
        #expect(!InventoryDetailField.status.isComplete(untouched))
        #expect(!InventoryDetailField.notes.isComplete(untouched))

        let entered = input(
            name: "Entered",
            status: .outgoing,
            quantity: 2,
            weightGrams: 425,
            notes: "Travel charger"
        )
        #expect(InventoryDetailField.weight.isComplete(entered))
        #expect(!InventoryDetailField.category.isComplete(entered))
        #expect(InventoryDetailField.quantity.isComplete(entered))
        #expect(InventoryDetailField.status.isComplete(entered))
        #expect(InventoryDetailField.notes.isComplete(entered))
    }

    @Test func reviewedFieldsConfirmLegitimateDefaultsAndEmptyValues() {
        let reviewed = input(
            name: "Reviewed",
            reviewedFields: InventoryDetailField.allCases
        )

        for field in InventoryDetailField.allCases {
            #expect(field.isComplete(reviewed))
        }
    }

    @Test func sectionsPutIncompleteItemsFirstAndSortEachGroupByName() {
        let completedB = input(name: "Bottle", weightGrams: 300)
        let incompleteZ = input(name: "Zipper pouch")
        let completedA = input(name: "Adapter", weightGrams: 90)
        let incompleteA = input(name: "Cap")

        let sections = InventoryEnrichment.sections(
            for: [completedB, incompleteZ, completedA, incompleteA],
            field: .weight
        )

        #expect(sections.incompleteIDs == [incompleteA.id, incompleteZ.id])
        #expect(sections.completedIDs == [completedA.id, completedB.id])
    }

    @Test @MainActor func modelStoresOnlyKnownReviewedFieldValues() {
        let item = InventoryItem(
            name: "Daypack",
            reviewedDetailRawValues: ["quantity", "future-field"]
        )

        #expect(item.reviewedDetailFields == [.quantity])
        item.setDetail(.status)
        #expect(item.reviewedDetailRawValues == ["quantity", "status"])
        item.setDetail(.quantity, reviewed: false)
        #expect(item.reviewedDetailRawValues == ["status"])
    }

    private func input(
        name: String,
        status: ItemStatus = .owned,
        quantity: Int = 1,
        weightGrams: Double? = nil,
        notes: String? = nil,
        reviewedFields: [InventoryDetailField] = []
    ) -> InventoryEnrichmentInput {
        InventoryEnrichmentInput(
            id: UUID(),
            name: name,
            categoryID: UUID(),
            status: status,
            quantity: quantity,
            weightGrams: weightGrams,
            notes: notes,
            reviewedFields: reviewedFields
        )
    }
}
