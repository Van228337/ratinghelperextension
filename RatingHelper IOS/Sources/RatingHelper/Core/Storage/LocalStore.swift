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

    // MARK: - Sync Timestamps
    public func loadSyncDate(key: String) -> Date? {
        read(Date.self, from: "sync_ts_\(key).json")
    }

    public func saveSyncDate(key: String, date: Date = Date()) {
        write(date, to: "sync_ts_\(key).json")
    }

    public func formattedLastSync(key: String) -> String? {
        guard let d = loadSyncDate(key: key) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: "Asia/Yekaterinburg") ?? .current
        formatter.dateFormat = "d MMM в HH:mm"
        return formatter.string(from: d)
    }

    // MARK: - Subjects Cache
    public func loadSubjects(term: Int) -> [Subject]? {
        read([Subject].self, from: "subjects_term_\(term).json")
    }

    public func saveSubjects(_ subjects: [Subject], term: Int) {
        // Guaranteed protection: empty response never overwrites non-empty cache!
        if subjects.isEmpty {
            if let existing = loadSubjects(term: term), !existing.isEmpty {
                return
            }
        }
        write(subjects, to: "subjects_term_\(term).json")
        saveSyncDate(key: "subjects_term_\(term)")
    }

    // MARK: - Journal Cache
    public func loadJournal(disciplineId: String, term: Int) -> JournalData? {
        read(JournalData.self, from: "journal_\(disciplineId)_\(term).json")
    }

    public func saveJournal(_ journal: JournalData) {
        // Guaranteed protection: empty continuous assignments never wipe existing cached journal!
        if journal.currentControl.isEmpty && journal.labs.isEmpty && journal.courseWorksOrProjects.isEmpty {
            if let existing = loadJournal(disciplineId: journal.disciplineId, term: journal.term),
               (!existing.currentControl.isEmpty || !existing.labs.isEmpty || !existing.courseWorksOrProjects.isEmpty) {
                return
            }
        }
        write(journal, to: "journal_\(journal.disciplineId)_\(journal.term).json")
        saveSyncDate(key: "journal_\(journal.disciplineId)_\(journal.term)")
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

    // MARK: - Schedule Cache
    public func loadSchedule(groupId: String) -> [ScheduleLesson]? {
        read([ScheduleLesson].self, from: "schedule_\(groupId).json")
    }

    public func saveSchedule(groupId: String, lessons: [ScheduleLesson]) {
        // Guaranteed protection: empty lessons never wipe existing cached schedule!
        if lessons.isEmpty {
            if let existing = loadSchedule(groupId: groupId), !existing.isEmpty {
                return
            }
        }
        write(lessons, to: "schedule_\(groupId).json")
        saveSyncDate(key: "schedule_\(groupId)")
    }

    // MARK: - Moodle Events Cache
    public func loadMoodleEvents(year: Int, month: Int) -> [MoodleCalendarEvent]? {
        read([MoodleCalendarEvent].self, from: "moodle_events_\(year)_\(month).json")
    }

    public func saveMoodleEvents(_ events: [MoodleCalendarEvent], year: Int, month: Int) {
        if events.isEmpty {
            if let existing = loadMoodleEvents(year: year, month: month), !existing.isEmpty {
                return
            }
        }
        write(events, to: "moodle_events_\(year)_\(month).json")
        saveSyncDate(key: "moodle_events_\(year)_\(month)")
    }
}
