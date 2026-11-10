import Foundation

public struct RatingResult: Hashable, Sendable {
    public let currentControlRating: Double
    public let finalRating: Double
    public let grade: AcademicGrade
    public let evaluation: AcademicEvaluation
    public let subtext: String
    public let totalWeight: Double

    public init(
        currentControlRating: Double,
        finalRating: Double,
        grade: AcademicGrade,
        evaluation: AcademicEvaluation,
        subtext: String,
        totalWeight: Double
    ) {
        self.currentControlRating = currentControlRating
        self.finalRating = finalRating
        self.grade = grade
        self.evaluation = evaluation
        self.subtext = subtext
        self.totalWeight = totalWeight
    }
}

public struct RatingCalculator: Sendable {
    public static func compute(
        entries: [CheckpointItem],
        scores: [Double],
        bonus: Double = 0.0,
        isExam: Bool = false,
        examScore: Double = 0.0,
        assessmentType: AssessmentType = .unknown
    ) -> RatingResult {
        guard !entries.isEmpty else {
            let eval = AcademicEvaluation.evaluate(percentage: bonus, assessmentType: assessmentType)
            return RatingResult(
                currentControlRating: 0.0,
                finalRating: bonus,
                grade: AcademicGrade.from(percentage: bonus),
                evaluation: eval,
                subtext: eval.progressToNext ?? AcademicGrade.subtext(for: bonus, assessmentType: assessmentType),
                totalWeight: 0.0
            )
        }

        var totalWeighted = 0.0
        var totalWeight = 0.0

        for i in 0..<entries.count {
            let entry = entries[i]
            let score = i < scores.count ? scores[i] : entry.current
            let pct = entry.max > 0 ? (score / entry.max) * 100.0 : 0.0
            totalWeighted += pct * entry.weight
            totalWeight += entry.weight
        }

        let currentControl = totalWeight > 0 ? (totalWeighted / totalWeight) : 0.0

        let final: Double
        if isExam {
            final = (currentControl * 0.6) + (examScore * 0.4) + bonus
        } else {
            final = currentControl + bonus
        }

        let grade = AcademicGrade.from(percentage: final)
        let eval = AcademicEvaluation.evaluate(percentage: final, assessmentType: assessmentType)
        let subtext = eval.progressToNext ?? (eval.isPassed ? "Зачёт успешно сдан!" : "Требуется набрать баллы до зачёта.")

        return RatingResult(
            currentControlRating: currentControl,
            finalRating: final,
            grade: grade,
            evaluation: eval,
            subtext: subtext,
            totalWeight: totalWeight
        )
    }
}
