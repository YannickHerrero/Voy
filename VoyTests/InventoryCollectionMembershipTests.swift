import Foundation
import Testing
@testable import Voy

struct InventoryCollectionMembershipTests {
    @Test func reportsOnlyActualMembershipChanges() {
        let retained = UUID()
        let removed = UUID()
        let added = UUID()

        let changes = InventoryCollectionMembership.changes(
            availableItemIDs: [retained, removed, added],
            currentMemberIDs: [retained, removed],
            selectedIDs: [retained, added]
        )

        #expect(changes.addedIDs == [added])
        #expect(changes.removedIDs == [removed])
        #expect(!changes.isEmpty)
    }

    @Test func ignoresIdentifiersForItemsThatNoLongerExist() {
        let available = UUID()
        let deleted = UUID()

        let changes = InventoryCollectionMembership.changes(
            availableItemIDs: [available],
            currentMemberIDs: [available, deleted],
            selectedIDs: [available, deleted]
        )

        #expect(changes.isEmpty)
    }
}
