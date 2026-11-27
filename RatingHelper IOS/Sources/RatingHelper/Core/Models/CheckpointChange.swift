import Foundation

public enum CheckpointChangeType: Codable, Hashable, Sendable {
    case weightChanged(oldWeight: Double, newWeight: Double, maxScore: Double)
    case maxScoreChanged(oldMax: Double, newMax: Double)
    case scoreDecreased(oldScore: Double, newScore: Double, maxScore: Double)
}

public struct CheckpointSnapshotItem: Codable, Hashable, Sendable {
    public let title: String
    public let score: Double
    public let maxScore: Double
    public let weight: Double
    public let recordedAt: Date

    public init(title: String, score: Double, maxScore: Double, weight: Double, recordedAt: Date = Date()) {
        self.title = title
        self.score = score
        self.maxScore = maxScore
        self.weight = weight
        self.recordedAt = recordedAt
    }
}

public struct CheckpointChangeNotice: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var subjectId: String
    public var checkpointTitle: String
    public var changeType: CheckpointChangeType
    public var message: String
    public var detectedAt: Date
    public var isDismissed: Bool

    public var isWeightChange: Bool {
        switch changeType {
        case .weightChanged, .maxScoreChanged:
            return true
        case .scoreDecreased:
            return false
        }
    }

    public init(
        id: UUID = UUID(),
        subjectId: String,
        checkpointTitle: String,
        changeType: CheckpointChangeType,
        message: String,
        detectedAt: Date = Date(),
        isDismissed: Bool = false
    ) {
        self.id = id
        self.subjectId = subjectId
        self.checkpointTitle = checkpointTitle
        self.changeType = changeType
        self.message = message
        self.detectedAt = detectedAt
        self.isDismissed = isDismissed
    }
}
