import Foundation
import SwiftData

@Model
final class PackingTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

@Model
final class PackingTemplateEntry {
    var id: UUID = UUID()
    var templateID: UUID = UUID()
    var itemID: UUID = UUID()
    var quantity: Int = 1
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        templateID: UUID,
        itemID: UUID,
        quantity: Int = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.templateID = templateID
        self.itemID = itemID
        self.quantity = max(1, quantity)
        self.createdAt = createdAt
    }
}

enum PackingSessionState: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case completed
    case archived

    var id: Self { self }

    var title: String {
        switch self {
        case .active: "Active"
        case .completed: "Completed"
        case .archived: "Archived"
        }
    }
}

@Model
final class PackingSession {
    var id: UUID = UUID()
    var templateID: UUID?
    var name: String = ""
    var startDate: Date = Date()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var stateRawValue: String = PackingSessionState.active.rawValue

    init(
        id: UUID = UUID(),
        templateID: UUID? = nil,
        name: String,
        startDate: Date = Date(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        state: PackingSessionState = .active
    ) {
        self.id = id
        self.templateID = templateID
        self.name = name
        self.startDate = startDate
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        stateRawValue = state.rawValue
    }

    var state: PackingSessionState {
        get { PackingSessionState(rawValue: stateRawValue) ?? .active }
        set { stateRawValue = newValue.rawValue }
    }
}

@Model
final class PackingSessionEntry {
    var id: UUID = UUID()
    var sessionID: UUID = UUID()
    var itemID: UUID?
    var itemNameSnapshot: String = ""
    @Attribute(.externalStorage) var thumbnailSnapshot: Data?
    var quantity: Int = 1
    var weightGramsPerUnit: Double?
    var isPacked: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        itemID: UUID?,
        itemNameSnapshot: String,
        thumbnailSnapshot: Data? = nil,
        quantity: Int = 1,
        weightGramsPerUnit: Double? = nil,
        isPacked: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.itemID = itemID
        self.itemNameSnapshot = itemNameSnapshot
        self.thumbnailSnapshot = thumbnailSnapshot
        self.quantity = max(1, quantity)
        self.weightGramsPerUnit = weightGramsPerUnit
        self.isPacked = isPacked
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
