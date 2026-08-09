import Foundation

enum InventoryDetailField: String, CaseIterable, Identifiable, Sendable {
    case weight
    case category
    case quantity
    case status
    case notes

    var id: Self { self }

    var title: String {
        switch self {
        case .weight: "Weight"
        case .category: "Category"
        case .quantity: "Quantity"
        case .status: "Status"
        case .notes: "Notes"
        }
    }

    var symbol: String {
        switch self {
        case .weight: "scalemass"
        case .category: "square.grid.2x2"
        case .quantity: "number"
        case .status: "checkmark.circle"
        case .notes: "note.text"
        }
    }

    func isComplete(_ item: InventoryEnrichmentInput) -> Bool {
        if item.reviewedFields.contains(self) { return true }

        switch self {
        case .weight:
            return item.weightGrams != nil
        case .category:
            return false
        case .quantity:
            return item.quantity != 1
        case .status:
            return item.status != .owned
        case .notes:
            return !(item.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }
}

struct InventoryEnrichmentInput: Equatable, Sendable {
    let id: UUID
    let name: String
    let categoryID: UUID?
    let status: ItemStatus
    let quantity: Int
    let weightGrams: Double?
    let notes: String?
    let reviewedFields: Set<InventoryDetailField>

    init(
        id: UUID,
        name: String,
        categoryID: UUID?,
        status: ItemStatus,
        quantity: Int,
        weightGrams: Double?,
        notes: String?,
        reviewedFields: some Sequence<InventoryDetailField>
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.status = status
        self.quantity = max(1, quantity)
        self.weightGrams = weightGrams
        self.notes = notes
        self.reviewedFields = Set(reviewedFields)
    }
}

struct InventoryEnrichmentSections: Equatable, Sendable {
    let incompleteIDs: [UUID]
    let completedIDs: [UUID]
}

enum InventoryEnrichment {
    static func sections(
        for items: some Sequence<InventoryEnrichmentInput>,
        field: InventoryDetailField
    ) -> InventoryEnrichmentSections {
        let ordered = items.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return InventoryEnrichmentSections(
            incompleteIDs: ordered.filter { !field.isComplete($0) }.map(\.id),
            completedIDs: ordered.filter { field.isComplete($0) }.map(\.id)
        )
    }
}

extension InventoryItem {
    var reviewedDetailFields: Set<InventoryDetailField> {
        Set(reviewedDetailRawValues.compactMap(InventoryDetailField.init(rawValue:)))
    }

    func setDetail(_ field: InventoryDetailField, reviewed: Bool = true) {
        var values = reviewedDetailFields
        if reviewed {
            values.insert(field)
        } else {
            values.remove(field)
        }
        reviewedDetailRawValues = values.map(\.rawValue).sorted()
    }

    var enrichmentInput: InventoryEnrichmentInput {
        InventoryEnrichmentInput(
            id: id,
            name: name,
            categoryID: categoryID,
            status: status,
            quantity: quantity,
            weightGrams: weightGrams,
            notes: itemDescription,
            reviewedFields: reviewedDetailFields
        )
    }
}
