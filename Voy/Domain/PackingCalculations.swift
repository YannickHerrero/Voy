import Foundation

struct PackingMetricInput: Equatable, Sendable {
    let quantity: Int
    let weightGramsPerUnit: Double?
    let isPacked: Bool

    init(quantity: Int, weightGramsPerUnit: Double?, isPacked: Bool) {
        self.quantity = max(1, quantity)
        self.weightGramsPerUnit = weightGramsPerUnit
        self.isPacked = isPacked
    }
}

struct PackingProgress: Equatable, Sendable {
    let packedUnits: Int
    let totalUnits: Int
    let packedWeightGrams: Double
    let knownTotalWeightGrams: Double
    let entriesWithoutWeight: Int

    var fractionComplete: Double {
        guard totalUnits > 0 else { return 0 }
        return Double(packedUnits) / Double(totalUnits)
    }
}

enum PackingCalculations {
    static func progress(for entries: some Sequence<PackingMetricInput>) -> PackingProgress {
        var packedUnits = 0
        var totalUnits = 0
        var packedWeight = 0.0
        var totalWeight = 0.0
        var entriesWithoutWeight = 0

        for entry in entries {
            totalUnits += entry.quantity
            if entry.isPacked {
                packedUnits += entry.quantity
            }

            if let unitWeight = entry.weightGramsPerUnit {
                let entryWeight = unitWeight * Double(entry.quantity)
                totalWeight += entryWeight
                if entry.isPacked {
                    packedWeight += entryWeight
                }
            } else {
                entriesWithoutWeight += 1
            }
        }

        return PackingProgress(
            packedUnits: packedUnits,
            totalUnits: totalUnits,
            packedWeightGrams: packedWeight,
            knownTotalWeightGrams: totalWeight,
            entriesWithoutWeight: entriesWithoutWeight
        )
    }
}

extension PackingSessionEntry {
    var metricInput: PackingMetricInput {
        PackingMetricInput(
            quantity: quantity,
            weightGramsPerUnit: weightGramsPerUnit,
            isPacked: isPacked
        )
    }
}
