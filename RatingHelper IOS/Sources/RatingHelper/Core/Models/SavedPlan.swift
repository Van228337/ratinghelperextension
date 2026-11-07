import Foundation

public struct SavedPlan: Codable, Hashable, Sendable {
    public let disciplineId: String
    public let subjectName: String
    public var scores: [Double]
    public var bonus: Double
    public var isExam: Bool
    public var examScore: Double
    public var savedAt: Date

    public init(
        disciplineId: String,
        subjectName: String,
        scores: [Double],
        bonus: Double = 0.0,
        isExam: Bool = false,
        examScore: Double = 0.0,
        savedAt: Date = Date()
    ) {
        self.disciplineId = disciplineId
        self.subjectName = subjectName
        self.scores = scores
        self.bonus = bonus
        self.isExam = isExam
        self.examScore = examScore
        self.savedAt = savedAt
    }
}
