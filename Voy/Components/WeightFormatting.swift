import Foundation

enum WeightFormatting {
    static func string(grams: Double) -> String {
        if grams < 1_000 {
            return "\(grams.formatted(.number.precision(.fractionLength(0)))) g"
        }
        return "\((grams / 1_000).formatted(.number.precision(.fractionLength(0...2)))) kg"
    }
}
