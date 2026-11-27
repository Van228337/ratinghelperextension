import Foundation

public struct AppBackupData: Codable, Sendable {
    public var version: String = "2.1.0"
    public var exportedAt: Date = Date()
    public var settings: AppSettings
    public var drafts: [String: SavedPlan]
    public var hiddenSubjects: [String]
    public var semesterHistory: [SemesterHistoryItem]
    public var materialVotes: [String: String]
    public var reviewVotes: [String: String]
    public var tasks: [StudyTask]?

    public init(
        version: String = "2.1.0",
        exportedAt: Date = Date(),
        settings: AppSettings,
        drafts: [String: SavedPlan],
        hiddenSubjects: [String],
        semesterHistory: [SemesterHistoryItem],
        materialVotes: [String: String],
        reviewVotes: [String: String],
        tasks: [StudyTask]? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.settings = settings
        self.drafts = drafts
        self.hiddenSubjects = hiddenSubjects
        self.semesterHistory = semesterHistory
        self.materialVotes = materialVotes
        self.reviewVotes = reviewVotes
        self.tasks = tasks
    }
}

public final class BackupService: Sendable {
    public static let shared = BackupService()

    private init() {}

    public func createBackup() async -> URL? {
        let store = LocalStore.shared
        let settings = await store.loadSettings()
        let drafts = await store.loadDrafts()
        let hidden = await store.loadHiddenSubjects()
        let history = await store.loadSemesterHistory()
        let matVotes = await store.loadMaterialVotes()
        let revVotes = await store.loadReviewVotes()
        let tasks = await store.readCustom([StudyTask].self, from: "study_tasks.json") ?? []

        let backup = AppBackupData(
            settings: settings,
            drafts: drafts,
            hiddenSubjects: Array(hidden),
            semesterHistory: history,
            materialVotes: matVotes,
            reviewVotes: revVotes,
            tasks: tasks
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(backup)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let dateStr = formatter.string(from: Date())
            let filename = "RatingHelper_Backup_\(dateStr).json"

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            print("Backup creation error: \(error)")
            return nil
        }
    }

    public func restore(from fileURL: URL) async throws -> Bool {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AppBackupData.self, from: data)

        let store = LocalStore.shared
        await store.saveSettings(backup.settings)
        for (_, draft) in backup.drafts {
            await store.saveDraft(draft)
        }
        await store.saveHiddenSubjects(Set(backup.hiddenSubjects))
        for item in backup.semesterHistory {
            await store.saveSemesterHistoryItem(item)
        }
        for (matId, vote) in backup.materialVotes {
            await store.saveMaterialVote(materialId: matId, vote: vote)
        }
        for (revId, vote) in backup.reviewVotes {
            await store.saveReviewVote(reviewId: revId, vote: vote)
        }
        if let tasks = backup.tasks {
            await store.writeCustom(tasks, to: "study_tasks.json")
            await TaskManager.shared.loadTasks()
        }
        return true
    }
}
