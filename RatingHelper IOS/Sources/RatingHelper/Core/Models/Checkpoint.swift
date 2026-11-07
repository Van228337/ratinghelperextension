import Foundation

public struct CheckpointItem: Identifiable, Codable, Hashable, Sendable {
    /// UUID of the corresponding Supabase row. Journal rows received from the
    /// university do not contain a database id, so this is optional until the
    /// metadata sync resolves the row.
    public var backendId: String?
    public var id: String { backendId ?? localKey }
    /// Compatibility alias used by task/history features.
    public var checkpointId: String? {
        get { backendId }
        set { backendId = newValue }
    }
    public var title: String
    public var current: Double
    public var max: Double
    public var weight: Double
    public var rating: Double
    public var materialsCount: Int

    public var percentage: Double {
        max > 0 ? (current / max) * 100.0 : 0.0
    }

    public var isComplete: Bool {
        current > 0
    }

    public init(
        backendId: String? = nil,
        title: String,
        current: Double,
        max: Double,
        weight: Double,
        rating: Double = 0.0,
        materialsCount: Int = 0
    ) {
        self.backendId = backendId
        self.title = title
        self.current = current
        self.max = max
        self.weight = weight
        self.rating = rating
        self.materialsCount = materialsCount
    }

    private var localKey: String {
        "local:\(title)|\(String(format: "%.4f", weight))|\(String(format: "%.4f", max))"
    }

    enum CodingKeys: String, CodingKey {
        case backendId
        case title, current, max, weight, rating, materialsCount
    }
}

public struct RawJournalRow: Codable, Sendable {
    public let name: String?
    public let point: Double?
    public let maxPoint: Double?
    public let weight: Double?
    public let rating: Double?
}

public struct RawJournalResponse: Codable, Sendable {
    public let disciplineName: String?
    public let currentRating: Double?
    public let totalRating: Double?
    public let currentControl: [RawJournalRow]?
    public let bonuses: [RawJournalRow]?
    public let attestation: [RawJournalRow]?
}

public struct BonusInfo: Codable, Hashable, Sendable {
    public var known: Bool
    public var percentPerPoint: Double
    public var detectedPoints: Double
    public var detectedRating: Double

    public init(
        known: Bool = false,
        percentPerPoint: Double = 0.0,
        detectedPoints: Double = 0.0,
        detectedRating: Double = 0.0
    ) {
        self.known = known
        self.percentPerPoint = percentPerPoint
        self.detectedPoints = detectedPoints
        self.detectedRating = detectedRating
    }
}
