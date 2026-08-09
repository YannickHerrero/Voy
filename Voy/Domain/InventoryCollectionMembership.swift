import Foundation

struct InventoryCollectionMembershipChanges: Equatable, Sendable {
    let addedIDs: Set<UUID>
    let removedIDs: Set<UUID>

    var isEmpty: Bool {
        addedIDs.isEmpty && removedIDs.isEmpty
    }
}

enum InventoryCollectionMembership {
    static func changes(
        availableItemIDs: some Sequence<UUID>,
        currentMemberIDs: some Sequence<UUID>,
        selectedIDs: some Sequence<UUID>
    ) -> InventoryCollectionMembershipChanges {
        let available = Set(availableItemIDs)
        let current = Set(currentMemberIDs).intersection(available)
        let selected = Set(selectedIDs).intersection(available)
        return InventoryCollectionMembershipChanges(
            addedIDs: selected.subtracting(current),
            removedIDs: current.subtracting(selected)
        )
    }
}
