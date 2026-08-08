import Foundation
import SwiftData

enum ItemStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case owned
    case outgoing
    case archived

    var id: Self { self }

    var title: String {
        switch self {
        case .owned: "Owned"
        case .outgoing: "Outgoing"
        case .archived: "Archived"
        }
    }

    var symbol: String {
        switch self {
        case .owned: "checkmark.circle"
        case .outgoing: "arrow.up.right.circle"
        case .archived: "archivebox"
        }
    }
}

@Model
final class InventoryItem {
    var id: UUID = UUID()
    var name: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    @Attribute(.externalStorage) var originalImageData: Data?
    var categoryID: UUID?
    var statusRawValue: String = ItemStatus.owned.rawValue
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var itemDescription: String?
    var quantity: Int = 1
    var weightGrams: Double?
    var collectionIDs: [UUID] = []
    var sourceURLString: String?
    var originalImageURLString: String?

    init(
        id: UUID = UUID(),
        name: String,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        originalImageData: Data? = nil,
        categoryID: UUID? = nil,
        status: ItemStatus = .owned,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        itemDescription: String? = nil,
        quantity: Int = 1,
        weightGrams: Double? = nil,
        collectionIDs: [UUID] = [],
        sourceURL: URL? = nil,
        originalImageURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.originalImageData = originalImageData
        self.categoryID = categoryID
        statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.itemDescription = itemDescription
        self.quantity = max(1, quantity)
        self.weightGrams = weightGrams
        self.collectionIDs = collectionIDs
        sourceURLString = sourceURL?.absoluteString
        originalImageURLString = originalImageURL?.absoluteString
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRawValue) ?? .owned }
        set { statusRawValue = newValue.rawValue }
    }

    var sourceURL: URL? {
        get { sourceURLString.flatMap(URL.init(string:)) }
        set { sourceURLString = newValue?.absoluteString }
    }

    var originalImageURL: URL? {
        get { originalImageURLString.flatMap(URL.init(string:)) }
        set { originalImageURLString = newValue?.absoluteString }
    }

    func touch(at date: Date = Date()) {
        modifiedAt = date
        quantity = max(1, quantity)
    }
}

@Model
final class InventoryCategory {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

@Model
final class InventoryCollection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
