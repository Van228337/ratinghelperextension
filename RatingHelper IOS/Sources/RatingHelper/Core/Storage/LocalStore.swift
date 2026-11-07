import Foundation

public struct AppSettings: Codable, Hashable, Sendable {
    public var targetCalc: Bool = true
    public var rangeForecast: Bool = true
    public var quickActions: Bool = true
    public var academicGrade: Bool = true
    public var examMode: Bool = true
    public var semesterDashboard: Bool = true
    public var saveDrafts: Bool = true
    public var communityMaterials: Bool = true
    public var teacherReviews: Bool = true

    public init() {}
}

public struct SemesterHistoryItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var teacher: String
    public var subjectId: String?
    public var assessmentType: String?
    public var rating: Double
    public var updatedAt: Date

    public init(
        name: String,
        teacher: String = "",
        subjectId: String? = nil,
        assessmentType: String? = nil,
        rating: Double,
        updatedAt: Date = Date()
    ) {
        self.name = name
        self.teacher = teacher
        self.subjectId = subjectId
        self.assessmentType = assessmentType
        self.rating = rating
        self.updatedAt = updatedAt
    }
}

public actor LocalStore {
    public static let shared = LocalStore()

    private let fileManager = FileManager.default
    private let documentsURL: URL

    private init() {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        self.documentsURL = urls.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private func fileURL(for filename: String) -> URL {
        documentsURL.appendingPathComponent(filename)
    }

    private func write<T: Encodable>(_ object: T, to filename: String) {
        let url = fileURL(for: filename)
        do {
            let data = try JSONEncoder().encode(object)
            try data.write(to: url, options: .atomic)
        } catch {
            print("LocalStore write error for \(filename): \(error)")
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        let url = fileURL(for: filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("LocalStore read error for \(filename): \(error)")
            return nil
        }
    }

    // MARK: - Generic Storage
    public func writeCustom<T: Encodable>(_ object: T, to filename: String) {
        write(object, to: filename)
    }

    public func readCustom<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        read(type, from: filename)
    }

    // MARK: - Settings
    public func loadSettings() -> AppSettings {
        read(AppSettings.self, from: "settings.json") ?? AppSettings()
    }

    public func saveSettings(_ settings: AppSettings) {
        write(settings, to: "settings.json")
    }

    // MARK: - User Session
    public func loadSession() -> UserSession? {
        read(UserSession.self, from: "session.json")
    }

    public func saveSession(_ session: UserSession) {
        write(session, to: "session.json")
    }

    public func clearSession() {
        let url = fileURL(for: "session.json")
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Hidden Subjects
    public func loadHiddenSubjects() -> Set<String> {
        let array = read([String].self, from: "hidden_subjects.json") ?? []
        return Set(array)
    }

    public func saveHiddenSubjects(_ hidden: Set<String>) {
        write(Array(hidden), to: "hidden_subjects.json")
    }

    // MARK: - Subjects Cache
    public func loadSubjects(term: Int) -> [Subject]? {
        read([Subject].self, from: "subjects_term_\(term).json")
    }

    public func saveSubjects(_ subjects: [Subject], term: Int) {
        write(subjects, to: "subjects_term_\(term).json")
    }

    // MARK: - Journal Cache
    public func loadJournal(disciplineId: String, term: Int) -> JournalData? {
        read(JournalData.self, from: "journal_\(disciplineId)_\(term).json")
    }

    public func saveJournal(_ journal: JournalData) {
        write(journal, to: "journal_\(journal.disciplineId)_\(journal.term).json")
    }

    // MARK: - Simulation Drafts
    public func loadDrafts() -> [String: SavedPlan] {
        read([String: SavedPlan].self, from: "simulation_drafts.json") ?? [:]
    }

    public func saveDraft(_ plan: SavedPlan) {
        var drafts = loadDrafts()
        drafts[plan.disciplineId] = plan
        write(drafts, to: "simulation_drafts.json")
    }

    public func removeDraft(disciplineId: String) {
        var drafts = loadDrafts()
        drafts.removeValue(forKey: disciplineId)
        write(drafts, to: "simulation_drafts.json")
    }

    // MARK: - Semester History (Dashboard)
    public func loadSemesterHistory() -> [SemesterHistoryItem] {
        read([SemesterHistoryItem].self, from: "semester_history.json") ?? []
    }

    public func saveSemesterHistoryItem(_ item: SemesterHistoryItem) {
        var list = loadSemesterHistory()
        if let idx = list.firstIndex(where: { $0.name == item.name }) {
            list[idx] = item
        } else {
            list.append(item)
        }
        write(list, to: "semester_history.json")
    }

    public func removeSemesterHistoryItem(name: String) {
        var list = loadSemesterHistory()
        list.removeAll(where: { $0.name == name })
        write(list, to: "semester_history.json")
    }

    public func clearSemesterHistory() {
        write([SemesterHistoryItem](), to: "semester_history.json")
    }

    // MARK: - User Votes
    public func loadMaterialVotes() -> [String: String] {
        read([String: String].self, from: "material_votes.json") ?? [:]
    }

    public func saveMaterialVote(materialId: String, vote: String?) {
        var votes = loadMaterialVotes()
        if let vote = vote {
            votes[materialId] = vote
        } else {
            votes.removeValue(forKey: materialId)
        }
        write(votes, to: "material_votes.json")
    }

    public func loadReviewVotes() -> [String: String] {
        read([String: String].self, from: "review_votes.json") ?? [:]
    }

    public func saveReviewVote(reviewId: String, vote: String?) {
        var votes = loadReviewVotes()
        if let vote = vote {
            votes[reviewId] = vote
        } else {
            votes.removeValue(forKey: reviewId)
        }
        write(votes, to: "review_votes.json")
    }
}
