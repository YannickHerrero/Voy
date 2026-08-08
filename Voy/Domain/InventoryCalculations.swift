import Foundation

struct InventorySummaryInput: Equatable, Sendable {
    let id: UUID
    let name: String
    let categoryID: UUID?
    let collectionIDs: Set<UUID>
    let status: ItemStatus
    let quantity: Int

    init(
        id: UUID,
        name: String,
        categoryID: UUID?,
        collectionIDs: some Sequence<UUID>,
        status: ItemStatus,
        quantity: Int
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.collectionIDs = Set(collectionIDs)
        self.status = status
        self.quantity = max(1, quantity)
    }
}

struct InventoryMetrics: Equatable, Sendable {
    let ownedCount: Int
    let outgoingCount: Int
    let archivedCount: Int
    let nomadicCount: Int
    let toRemoveCount: Int
    let categoryCounts: [UUID: Int]
}

struct InventoryFilter: Equatable, Sendable {
    var searchText = ""
    var categoryID: UUID?
    var collectionID: UUID?
    var status: ItemStatus?
    var excludesCollectionID: UUID?

    func includes(_ item: InventorySummaryInput) -> Bool {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesSearch = normalizedSearch.isEmpty || item.name.localizedCaseInsensitiveContains(normalizedSearch)
        let matchesCategory = categoryID == nil || item.categoryID == categoryID
        let matchesCollection = collectionID == nil || item.collectionIDs.contains(collectionID!)
        let matchesStatus = status == nil || item.status == status
        let matchesExclusion = excludesCollectionID == nil || !item.collectionIDs.contains(excludesCollectionID!)
        return matchesSearch && matchesCategory && matchesCollection && matchesStatus && matchesExclusion
    }
}

enum InventoryCalculations {
    static func metrics(
        for items: some Sequence<InventorySummaryInput>,
        nomadicCollectionID: UUID?
    ) -> InventoryMetrics {
        var owned = 0
        var outgoing = 0
        var archived = 0
        var nomadic = 0
        var toRemove = 0
        var categoryCounts: [UUID: Int] = [:]

        for item in items {
            switch item.status {
            case .owned:
                owned += item.quantity
                if let categoryID = item.categoryID {
                    categoryCounts[categoryID, default: 0] += item.quantity
                }
                if let nomadicCollectionID, item.collectionIDs.contains(nomadicCollectionID) {
                    nomadic += item.quantity
                } else if nomadicCollectionID != nil {
                    toRemove += item.quantity
                }
            case .outgoing:
                outgoing += item.quantity
            case .archived:
                archived += item.quantity
            }
        }

        return InventoryMetrics(
            ownedCount: owned,
            outgoingCount: outgoing,
            archivedCount: archived,
            nomadicCount: nomadic,
            toRemoveCount: toRemove,
            categoryCounts: categoryCounts
        )
    }
}

extension InventoryItem {
    var summaryInput: InventorySummaryInput {
        InventorySummaryInput(
            id: id,
            name: name,
            categoryID: categoryID,
            collectionIDs: collectionIDs,
            status: status,
            quantity: quantity
        )
    }
}
