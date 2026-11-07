import Foundation

public struct RangeForecastResult: Hashable, Sendable {
    public let minRating: Double
    public let currentRating: Double
    public let maxRating: Double

    public init(minRating: Double, currentRating: Double, maxRating: Double) {
        self.minRating = minRating
        self.currentRating = currentRating
        self.maxRating = maxRating
    }
}

public struct RangeForecaster: Sendable {
    public static func computeForecast(
        entries: [CheckpointItem],
        currentRating: Double,
        bonus: Double = 0.0
    ) -> RangeForecastResult {
        let totalWeight = entries.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return RangeForecastResult(minRating: bonus, currentRating: currentRating, maxRating: bonus)
        }

        var lockedWeighted = 0.0
        var remainingWeight = 0.0

        for entry in entries {
            if entry.current == 0 {
                remainingWeight += entry.weight
            } else {
                let pct = entry.max > 0 ? (entry.current / entry.max) * 100.0 : 0.0
                lockedWeighted += pct * entry.weight
            }
        }

        let minRating = (lockedWeighted / totalWeight) + bonus
        let maxRating = ((lockedWeighted + (remainingWeight * 100.0)) / totalWeight) + bonus

        return RangeForecastResult(
            minRating: minRating,
            currentRating: currentRating,
            maxRating: maxRating
        )
    }
}
