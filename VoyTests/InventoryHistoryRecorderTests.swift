import Foundation
import SwiftData
import Testing
@testable import Voy

struct InventoryHistoryRecorderTests {
    @Test @MainActor func updatesSameDayAndCreatesNewDaySnapshot() throws {
        let container = try DataSchema.inMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let firstDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 9)))
        let laterSameDay = try #require(calendar.date(byAdding: .hour, value: 4, to: firstDay))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let item = InventoryItem(name: "T-shirts", quantity: 3)

        #expect(try InventoryHistoryRecorder.record(items: [item], in: context, at: firstDay, calendar: calendar))
        item.status = .outgoing
        #expect(try InventoryHistoryRecorder.record(items: [item], in: context, at: laterSameDay, calendar: calendar))
        #expect(!(try InventoryHistoryRecorder.record(items: [item], in: context, at: laterSameDay, calendar: calendar)))
        item.status = .archived
        #expect(try InventoryHistoryRecorder.record(items: [item], in: context, at: nextDay, calendar: calendar))
        try context.save()

        let snapshots = try context.fetch(FetchDescriptor<InventorySnapshot>())
            .sorted { $0.capturedAt < $1.capturedAt }
        #expect(snapshots.count == 2)
        #expect(snapshots[0].ownedCount == 0)
        #expect(snapshots[0].outgoingCount == 3)
        #expect(snapshots[1].archivedCount == 3)
    }
}
