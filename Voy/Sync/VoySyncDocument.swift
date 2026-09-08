import Foundation

struct VoySyncMediaObject: Codable, Equatable, Sendable {
    let hash: String
    let contentType: String
    let byteLength: Int
}

struct VoySyncCategory: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let sortOrder: Int
    let createdAt: Date
}

struct VoySyncCollection: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
}

struct VoySyncItem: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let imageHash: String?
    let thumbnailHash: String?
    let originalImageHash: String?
    let categoryId: UUID?
    let status: String
    let createdAt: Date
    let modifiedAt: Date
    let itemDescription: String?
    let quantity: Int
    let weightGrams: Double?
    let collectionIds: [UUID]
    let reviewedFields: [String]
    let sourceUrl: URL?
    let originalImageUrl: URL?

    private enum CodingKeys: String, CodingKey {
        case id, name, imageHash, thumbnailHash, originalImageHash, categoryId, status
        case createdAt, modifiedAt, quantity, weightGrams, collectionIds, reviewedFields
        case sourceUrl, originalImageUrl
        case itemDescription = "description"
    }
}

struct VoySyncPackingTemplate: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
    let modifiedAt: Date
}

struct VoySyncPackingTemplateEntry: Codable, Equatable, Sendable {
    let id: UUID
    let templateId: UUID
    let itemId: UUID
    let quantity: Int
    let createdAt: Date
}

struct VoySyncPackingSession: Codable, Equatable, Sendable {
    let id: UUID
    let templateId: UUID?
    let name: String
    let startDate: Date
    let createdAt: Date
    let modifiedAt: Date
    let state: String
}

struct VoySyncPackingSessionEntry: Codable, Equatable, Sendable {
    let id: UUID
    let sessionId: UUID
    let itemId: UUID?
    let itemNameSnapshot: String
    let thumbnailHash: String?
    let quantity: Int
    let weightGramsPerUnit: Double?
    let isPacked: Bool
    let sortOrder: Int
    let createdAt: Date
}

struct VoySyncMinimalismSettings: Codable, Equatable, Sendable {
    let id: UUID
    let possessionGoal: Int?
    let nomadicCollectionId: UUID?
    let modifiedAt: Date
}

struct VoySyncInventorySnapshot: Codable, Equatable, Sendable {
    let id: UUID
    let capturedAt: Date
    let ownedCount: Int
    let outgoingCount: Int
    let archivedCount: Int
}

struct VoySyncDocument: Codable, Equatable, Sendable {
    let schemaVersion: Int
    var generatedAt: Date
    let deviceId: UUID
    let media: [VoySyncMediaObject]
    let categories: [VoySyncCategory]
    let collections: [VoySyncCollection]
    let items: [VoySyncItem]
    let packingTemplates: [VoySyncPackingTemplate]
    let packingTemplateEntries: [VoySyncPackingTemplateEntry]
    let packingSessions: [VoySyncPackingSession]
    let packingSessionEntries: [VoySyncPackingSessionEntry]
    let minimalismSettings: [VoySyncMinimalismSettings]
    let inventorySnapshots: [VoySyncInventorySnapshot]
}

struct VoySyncExport: Sendable {
    let document: VoySyncDocument
    let mediaData: [String: Data]
}
