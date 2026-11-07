import Foundation

public struct JournalData: Codable, Hashable, Sendable {
    public var disciplineId: String
    public var disciplineName: String
    public var term: Int
    public var currentRating: Double
    public var totalRating: Double
    public var currentControl: [CheckpointItem]
    public var bonuses: [CheckpointItem]
    public var attestation: [CheckpointItem]
    public var bonusInfo: BonusInfo
    public var lastUpdated: Date

    public init(
        disciplineId: String,
        disciplineName: String,
        term: Int,
        currentRating: Double,
        totalRating: Double,
        currentControl: [CheckpointItem],
        bonuses: [CheckpointItem],
        attestation: [CheckpointItem],
        bonusInfo: BonusInfo = BonusInfo(),
        lastUpdated: Date = Date()
    ) {
        self.disciplineId = disciplineId
        self.disciplineName = disciplineName
        self.term = term
        self.currentRating = currentRating
        self.totalRating = totalRating
        self.currentControl = currentControl
        self.bonuses = bonuses
        self.attestation = attestation
        self.bonusInfo = bonusInfo
        self.lastUpdated = lastUpdated
    }

    public static func from(raw: RawJournalResponse, disciplineId: String, term: Int) -> JournalData {
        let name = Subject.cleanName(raw.disciplineName ?? "Предмет")
        
        func mapRows(_ rows: [RawJournalRow]?) -> [CheckpointItem] {
            guard let rows = rows else { return [] }
            return rows.compactMap { r -> CheckpointItem? in
                guard let title = r.name?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
                    return nil
                }
                return CheckpointItem(
                    title: title,
                    current: r.point ?? 0.0,
                    max: r.maxPoint ?? 0.0,
                    weight: r.weight ?? 0.0,
                    rating: r.rating ?? 0.0
                )
            }
        }

        let currentControl = mapRows(raw.currentControl)
        let bonuses = mapRows(raw.bonuses)
        let attestation = mapRows(raw.attestation)

        // Bonus calculation logic from website app.py
        var bonusPoints = 0.0
        var bonusRating = 0.0
        var ratios: [Double] = []

        for b in bonuses {
            bonusPoints += b.current
            bonusRating += b.rating
            if b.current > 0 && b.rating > 0 {
                ratios.append(b.rating / b.current)
            }
        }

        let percentPerPoint = ratios.isEmpty ? 0.0 : (ratios.reduce(0, +) / Double(ratios.count))
        let bonusInfo = BonusInfo(
            known: percentPerPoint > 0,
            percentPerPoint: percentPerPoint,
            detectedPoints: bonusPoints,
            detectedRating: bonusRating
        )

        return JournalData(
            disciplineId: disciplineId,
            disciplineName: name,
            term: term,
            currentRating: raw.currentRating ?? 0.0,
            totalRating: raw.totalRating ?? 0.0,
            currentControl: currentControl,
            bonuses: bonuses,
            attestation: attestation,
            bonusInfo: bonusInfo
        )
    }
}
