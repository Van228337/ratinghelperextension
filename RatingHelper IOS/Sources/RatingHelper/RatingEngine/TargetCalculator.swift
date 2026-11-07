import Foundation

public enum TargetGoalResult: Hashable, Sendable {
    case alreadyAchieved(current: Double)
    case unreachable(maxPossible: Double)
    case allCompleted
    case neededExam(neededScore: Double, currentControl: Double)
    case neededControl(neededAvgPct: Double, remainingCount: Int, suggestedScores: [Double])
}

public struct TargetCalculator: Sendable {
    public static func computeGoal(
        target: Double,
        entries: [CheckpointItem],
        currentScores: [Double],
        bonus: Double = 0.0,
        isExam: Bool = false
    ) -> TargetGoalResult {
        guard !entries.isEmpty else { return .allCompleted }

        let totalWeight = entries.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return .allCompleted }

        if isExam {
            var currentTotal = 0.0
            for i in 0..<entries.count {
                let score = i < currentScores.count ? currentScores[i] : entries[i].current
                let pct = entries[i].max > 0 ? (score / entries[i].max) * 100.0 : 0.0
                currentTotal += pct * entries[i].weight
            }
            let currentControl = currentTotal / totalWeight

            // Target = currentControl * 0.6 + exam * 0.4 + bonus
            let neededExam = (target - bonus - (currentControl * 0.6)) / 0.4

            if neededExam <= 0 {
                return .alreadyAchieved(current: (currentControl * 0.6) + bonus)
            } else if neededExam > 100.0 {
                let maxPossible = (currentControl * 0.6) + 40.0 + bonus
                return .unreachable(maxPossible: maxPossible)
            } else {
                return .neededExam(neededScore: neededExam, currentControl: currentControl)
            }
        }

        var lockedWeighted = 0.0
        var remainingWeight = 0.0
        var remainingIndices: [Int] = []

        for i in 0..<entries.count {
            if entries[i].current == 0 {
                remainingWeight += entries[i].weight
                remainingIndices.append(i)
            } else {
                let score = i < currentScores.count ? currentScores[i] : entries[i].current
                let pct = entries[i].max > 0 ? (score / entries[i].max) * 100.0 : 0.0
                lockedWeighted += pct * entries[i].weight
            }
        }

        let maxPossible = ((lockedWeighted + (remainingWeight * 100.0)) / totalWeight) + bonus

        var currTotal = 0.0
        for i in 0..<entries.count {
            let score = i < currentScores.count ? currentScores[i] : entries[i].current
            let pct = entries[i].max > 0 ? (score / entries[i].max) * 100.0 : 0.0
            currTotal += pct * entries[i].weight
        }
        let currentRating = (currTotal / totalWeight) + bonus

        if currentRating >= target {
            return .alreadyAchieved(current: currentRating)
        }

        if target > maxPossible {
            return .unreachable(maxPossible: maxPossible)
        }

        if remainingIndices.isEmpty {
            return .allCompleted
        }

        let neededWeighted = ((target - bonus) * totalWeight) - lockedWeighted
        let neededAvgPct = neededWeighted / remainingWeight

        var suggested = currentScores
        for idx in remainingIndices {
            let entry = entries[idx]
            let calc = (entry.max * (neededAvgPct / 100.0) * 10.0).rounded() / 10.0
            suggested[idx] = min(entry.max, max(0.0, calc))
        }

        return .neededControl(
            neededAvgPct: neededAvgPct,
            remainingCount: remainingIndices.count,
            suggestedScores: suggested
        )
    }
}
