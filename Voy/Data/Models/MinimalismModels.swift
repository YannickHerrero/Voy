import Foundation
import SwiftData

@Model
final class MinimalismSettings {
    var id: UUID = UUID()
    var possessionGoal: Int?
    var nomadicCollectionID: UUID?
    var modifiedAt: Date = Date()

    init(
        id: UUID = UUID(),
        possessionGoal: Int? = nil,
        nomadicCollectionID: UUID? = nil,
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.possessionGoal = possessionGoal
        self.nomadicCollectionID = nomadicCollectionID
        self.modifiedAt = modifiedAt
    }
}

@Model
final class InventorySnapshot {
    var id: UUID = UUID()
    var capturedAt: Date = Date()
    var ownedCount: Int = 0
    var outgoingCount: Int = 0
    var archivedCount: Int = 0

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        ownedCount: Int,
        outgoingCount: Int,
        archivedCount: Int
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.ownedCount = ownedCount
        self.outgoingCount = outgoingCount
        self.archivedCount = archivedCount
    }
}
