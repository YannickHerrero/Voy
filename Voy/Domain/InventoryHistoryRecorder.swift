import Foundation
import SwiftData

enum InventoryHistoryRecorder {
    @MainActor
    static func record(
        items: [InventoryItem],
        in context: ModelContext,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        let metrics = InventoryCalculations.metrics(
            for: items.map(\.summaryInput),
            nomadicCollectionID: nil
        )
        let day = calendar.startOfDay(for: date)
        let snapshots = try context.fetch(
            FetchDescriptor<InventorySnapshot>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        )

        if let existing = snapshots.first(where: { calendar.isDate($0.capturedAt, inSameDayAs: day) }) {
            let changed = existing.ownedCount != metrics.ownedCount
                || existing.outgoingCount != metrics.outgoingCount
                || existing.archivedCount != metrics.archivedCount
            guard changed else { return false }
            existing.capturedAt = date
            existing.ownedCount = metrics.ownedCount
            existing.outgoingCount = metrics.outgoingCount
            existing.archivedCount = metrics.archivedCount
            return true
        } else {
            context.insert(InventorySnapshot(
                capturedAt: date,
                ownedCount: metrics.ownedCount,
                outgoingCount: metrics.outgoingCount,
                archivedCount: metrics.archivedCount
            ))
            return true
        }
    }
}
