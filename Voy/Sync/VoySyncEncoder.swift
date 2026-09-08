import CryptoKit
import Foundation
import SwiftData

@MainActor
enum VoySyncEncoder {
    static func makeExport(
        from context: ModelContext,
        deviceId: UUID,
        generatedAt: Date = Date()
    ) throws -> VoySyncExport {
        let storedItems = try context.fetch(FetchDescriptor<InventoryItem>()).sorted { uuidOrder($0.id, $1.id) }
        let storedSessionEntries = try context.fetch(FetchDescriptor<PackingSessionEntry>()).sorted { uuidOrder($0.id, $1.id) }
        var mediaByHash: [String: VoySyncMediaObject] = [:]
        var mediaData: [String: Data] = [:]

        func addMedia(_ data: Data?) -> String? {
            guard let data, !data.isEmpty else { return nil }
            let hash = sha256(data)
            if mediaByHash[hash] == nil {
                mediaByHash[hash] = VoySyncMediaObject(
                    hash: hash,
                    contentType: "image/jpeg",
                    byteLength: data.count
                )
                mediaData[hash] = data
            }
            return hash
        }

        let items = storedItems.map { item in
            VoySyncItem(
                id: item.id,
                name: item.name,
                imageHash: addMedia(item.imageData),
                thumbnailHash: addMedia(item.thumbnailData),
                originalImageHash: addMedia(item.originalImageData),
                categoryId: item.categoryID,
                status: item.status.rawValue,
                createdAt: item.createdAt,
                modifiedAt: item.modifiedAt,
                itemDescription: item.itemDescription,
                quantity: item.quantity,
                weightGrams: item.weightGrams,
                collectionIds: item.collectionIDs.sorted(by: uuidOrder),
                reviewedFields: item.reviewedDetailFields.map(\.rawValue).sorted(),
                sourceUrl: item.sourceURL,
                originalImageUrl: item.originalImageURL
            )
        }

        let sessionEntries = storedSessionEntries.map { entry in
            VoySyncPackingSessionEntry(
                id: entry.id,
                sessionId: entry.sessionID,
                itemId: entry.itemID,
                itemNameSnapshot: entry.itemNameSnapshot,
                thumbnailHash: addMedia(entry.thumbnailSnapshot),
                quantity: entry.quantity,
                weightGramsPerUnit: entry.weightGramsPerUnit,
                isPacked: entry.isPacked,
                sortOrder: entry.sortOrder,
                createdAt: entry.createdAt
            )
        }

        let document = VoySyncDocument(
            schemaVersion: 1,
            generatedAt: generatedAt,
            deviceId: deviceId,
            media: mediaByHash.values.sorted { $0.hash < $1.hash },
            categories: try context.fetch(FetchDescriptor<InventoryCategory>()).sorted { uuidOrder($0.id, $1.id) }.map {
                VoySyncCategory(id: $0.id, name: $0.name, sortOrder: $0.sortOrder, createdAt: $0.createdAt)
            },
            collections: try context.fetch(FetchDescriptor<InventoryCollection>()).sorted { uuidOrder($0.id, $1.id) }.map {
                VoySyncCollection(id: $0.id, name: $0.name, createdAt: $0.createdAt)
            },
            items: items,
            packingTemplates: try context.fetch(FetchDescriptor<PackingTemplate>()).sorted { uuidOrder($0.id, $1.id) }.map {
                VoySyncPackingTemplate(id: $0.id, name: $0.name, createdAt: $0.createdAt, modifiedAt: $0.modifiedAt)
            },
            packingTemplateEntries: try context.fetch(FetchDescriptor<PackingTemplateEntry>()).sorted { uuidOrder($0.id, $1.id) }.map {
                VoySyncPackingTemplateEntry(
                    id: $0.id,
                    templateId: $0.templateID,
                    itemId: $0.itemID,
                    quantity: $0.quantity,
                    createdAt: $0.createdAt
                )
            },
            packingSessions: try context.fetch(FetchDescriptor<PackingSession>()).sorted { uuidOrder($0.id, $1.id) }.map {
                VoySyncPackingSession(
                    id: $0.id,
                    templateId: $0.templateID,
                    name: $0.name,
                    startDate: $0.startDate,
                    createdAt: $0.createdAt,
                    modifiedAt: $0.modifiedAt,
                    state: $0.state.rawValue
                )
            },
            packingSessionEntries: sessionEntries,
            minimalismSettings: try context.fetch(FetchDescriptor<MinimalismSettings>()).sorted { uuidOrder($0.id, $1.id) }.map {
                VoySyncMinimalismSettings(
                    id: $0.id,
                    possessionGoal: $0.possessionGoal,
                    nomadicCollectionId: $0.nomadicCollectionID,
                    modifiedAt: $0.modifiedAt
                )
            },
            inventorySnapshots: try context.fetch(FetchDescriptor<InventorySnapshot>()).sorted { uuidOrder($0.id, $1.id) }.map {
                VoySyncInventorySnapshot(
                    id: $0.id,
                    capturedAt: $0.capturedAt,
                    ownedCount: $0.ownedCount,
                    outgoingCount: $0.outgoingCount,
                    archivedCount: $0.archivedCount
                )
            }
        )
        return VoySyncExport(document: document, mediaData: mediaData)
    }

    static func fingerprint(for document: VoySyncDocument) throws -> String {
        var canonical = document
        canonical.generatedAt = Date(timeIntervalSince1970: 0)
        return sha256(try VoySyncCoding.encoder().encode(canonical))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func uuidOrder(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

enum VoySyncCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
