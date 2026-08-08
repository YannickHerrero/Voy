#if DEBUG
import SwiftData
import UIKit

enum DebugSampleData {
    @MainActor
    static func seedIfRequested(in context: ModelContext) throws {
        guard ProcessInfo.processInfo.arguments.contains("-SampleData") else { return }
        guard try context.fetch(FetchDescriptor<InventoryItem>()).isEmpty else { return }

        let categories = try context.fetch(
            FetchDescriptor<InventoryCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        let collections = try context.fetch(FetchDescriptor<InventoryCollection>())
        guard !categories.isEmpty else { return }

        let names = [
            "Merino T-shirt", "MacBook Air", "Trail Shoes", "Travel Adapter", "Linen Shirt",
            "Running Shorts", "Passport Wallet", "Noise-Cancelling Headphones", "Daypack", "Water Bottle",
            "Rain Jacket", "Toiletry Pouch", "USB-C Cable", "Notebook", "Sunglasses", "Packing Cubes"
        ]
        let thumbnails = (0..<8).map(makeThumbnail)
        var items: [InventoryItem] = []

        for index in 0..<128 {
            let category = categories[index % categories.count]
            let item = InventoryItem(
                name: index < names.count ? names[index] : "\(names[index % names.count]) \(index + 1)",
                imageData: thumbnails[index % thumbnails.count],
                thumbnailData: thumbnails[index % thumbnails.count],
                categoryID: category.id,
                status: index.isMultiple(of: 29) ? .archived : (index.isMultiple(of: 13) ? .outgoing : .owned),
                createdAt: Calendar.current.date(byAdding: .day, value: -index * 2, to: .now) ?? .now,
                quantity: index.isMultiple(of: 11) ? 3 : 1,
                weightGrams: index.isMultiple(of: 5) ? nil : Double(90 + (index % 18) * 115),
                collectionIDs: sampleCollectionIDs(index: index, collections: collections)
            )
            context.insert(item)
            items.append(item)
        }

        let template = PackingTemplate(name: "One Week Travel")
        context.insert(template)
        for (index, item) in items.filter({ $0.status == .owned }).prefix(18).enumerated() {
            context.insert(PackingTemplateEntry(
                templateID: template.id,
                itemID: item.id,
                quantity: min(item.quantity, index.isMultiple(of: 6) ? 2 : 1)
            ))
        }

        let templateEntries = try context.fetch(FetchDescriptor<PackingTemplateEntry>())
        let activeSession = PackingSessionFactory.create(
            from: template,
            name: "Japan — October 2026",
            startDate: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 4)) ?? .now,
            templateEntries: templateEntries,
            items: items,
            in: context
        )
        let activeEntries = try context.fetch(FetchDescriptor<PackingSessionEntry>())
            .filter { $0.sessionID == activeSession.id }
        for (index, entry) in activeEntries.enumerated() where index < 11 {
            entry.isPacked = true
        }

        let pastSession = PackingSession(
            templateID: template.id,
            name: "Marathon Weekend — April 2026",
            startDate: Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 18)) ?? .now,
            state: .completed
        )
        context.insert(pastSession)

        if let settings = try context.fetch(FetchDescriptor<MinimalismSettings>()).first {
            settings.possessionGoal = 60
            settings.nomadicCollectionID = collections.first {
                $0.name.localizedCaseInsensitiveCompare("Nomadic") == .orderedSame
            }?.id
        }

        let currentMetrics = InventoryCalculations.metrics(
            for: items.map(\.summaryInput),
            nomadicCollectionID: nil
        )
        for monthsAgo in stride(from: 5, through: 1, by: -1) {
            guard let date = Calendar.current.date(byAdding: .month, value: -monthsAgo, to: .now) else { continue }
            context.insert(InventorySnapshot(
                capturedAt: date,
                ownedCount: currentMetrics.ownedCount + monthsAgo * 7,
                outgoingCount: max(0, currentMetrics.outgoingCount - monthsAgo),
                archivedCount: max(0, currentMetrics.archivedCount - monthsAgo * 2)
            ))
        }
        _ = try InventoryHistoryRecorder.record(items: items, in: context)
        try context.save()
    }

    private static func sampleCollectionIDs(
        index: Int,
        collections: [InventoryCollection]
    ) -> [UUID] {
        var result: [UUID] = []
        for collection in collections {
            let shouldInclude: Bool
            switch collection.name.lowercased() {
            case "nomadic": shouldInclude = index % 3 != 0
            case "travel": shouldInclude = index % 2 == 0
            case "work": shouldInclude = index % 7 == 0
            case "running": shouldInclude = index % 9 == 0
            case "edc": shouldInclude = index % 11 == 0
            default: shouldInclude = index % 4 == 0
            }
            if shouldInclude { result.append(collection.id) }
        }
        return result
    }

    private static func makeThumbnail(index: Int) -> Data {
        let colors: [UIColor] = [
            .systemIndigo, .systemTeal, .systemOrange, .systemBrown,
            .systemBlue, .systemGreen, .systemPurple, .systemGray
        ]
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 480), format: format).image { context in
            UIColor.secondarySystemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 480, height: 480))
            colors[index % colors.count].withAlphaComponent(0.82).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 90, y: 85, width: 300, height: 310))
            UIColor.white.withAlphaComponent(0.8).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 175, y: 165, width: 130, height: 140))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
#endif
