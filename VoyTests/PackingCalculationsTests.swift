import Testing
@testable import Voy

struct PackingCalculationsTests {
    @Test func progressUsesQuantitiesAndKnownWeights() {
        let entries = [
            PackingMetricInput(quantity: 3, weightGramsPerUnit: 180, isPacked: true),
            PackingMetricInput(quantity: 1, weightGramsPerUnit: 1_250, isPacked: false),
            PackingMetricInput(quantity: 2, weightGramsPerUnit: nil, isPacked: true)
        ]

        let progress = PackingCalculations.progress(for: entries)

        #expect(progress.packedUnits == 5)
        #expect(progress.totalUnits == 6)
        #expect(progress.packedWeightGrams == 540)
        #expect(progress.knownTotalWeightGrams == 1_790)
        #expect(progress.entriesWithoutWeight == 1)
    }

    @Test func emptyProgressHasZeroFraction() {
        let progress = PackingCalculations.progress(for: [] as [PackingMetricInput])
        #expect(progress.fractionComplete == 0)
    }
}
