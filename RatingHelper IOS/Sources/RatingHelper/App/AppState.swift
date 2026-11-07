import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var session: UserSession?
    @Published public var isLoggedIn: Bool = false
    @Published public var selectedTerm: Int = 4
    @Published public var selectedArchiveTab: String = "active"
    @Published public var themeMode: AppThemeMode = .system
    @Published public var subjects: [Subject] = []
    @Published public var activeSubject: Subject?
    @Published public var currentJournal: JournalData?
    @Published public var settings: AppSettings = AppSettings()
    @Published public var appUser: SupabaseAppUser?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var activeDraft: SavedPlan?

    private let auth = SusuAuthService.shared
    private let journalService = SusuJournalService.shared
    private let supabase = SupabaseService.shared
    private let store = LocalStore.shared

    public init() {
        // Восстановление сохраненного семестра, вкладки архива и темы при создании
        let savedTerm = UserDefaults.standard.integer(forKey: "selected_term_id")
        if savedTerm >= 1 && savedTerm <= 12 {
            self.selectedTerm = savedTerm
        }
        if let savedTab = UserDefaults.standard.string(forKey: "selected_archive_tab"), !savedTab.isEmpty {
            self.selectedArchiveTab = savedTab
        }
        if let savedTheme = UserDefaults.standard.string(forKey: "selected_theme_mode"),
           let mode = AppThemeMode(rawValue: savedTheme) {
            self.themeMode = mode
        }

        Task {
            await initialize()
        }
    }

    public func initialize() async {
        self.settings = await store.loadSettings()
        if let restored = await auth.restoreSavedSession() {
            self.session = restored
            self.isLoggedIn = true
            await loadUserProfile()
            await loadSubjects()
        }
    }

    public func setThemeMode(_ mode: AppThemeMode) {
        self.themeMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "selected_theme_mode")
    }

    public func setArchiveTab(_ tab: String) {
        self.selectedArchiveTab = tab
        UserDefaults.standard.set(tab, forKey: "selected_archive_tab")
    }

    public func loadUserProfile() async {
        let userId = KeychainHelper.shared.readString(key: "app_user_uuid") ?? {
            let newId = UUID().uuidString
            _ = KeychainHelper.shared.saveString(key: "app_user_uuid", value: newId)
            return newId
        }()
        self.appUser = await supabase.getUserProfile(userId: userId)
    }

    public func login(loginText: String, passwordText: String, rememberMe: Bool) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let newSession = try await auth.login(login: loginText, password: passwordText, rememberMe: rememberMe)
            self.session = newSession
            self.isLoggedIn = true
            await loadUserProfile()
            await loadSubjects()
            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func logout() async {
        await auth.logout()
        self.session = nil
        self.isLoggedIn = false
        self.subjects = []
        self.currentJournal = nil
        self.activeSubject = nil
    }

    public func loadSubjects(forceRefresh: Bool = false) async {
        guard isLoggedIn else { return }
        isLoading = true
        errorMessage = nil
        do {
            self.subjects = try await journalService.fetchSubjects(term: selectedTerm)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    public func changeTerm(_ newTerm: Int) async {
        selectedTerm = newTerm
        UserDefaults.standard.set(newTerm, forKey: "selected_term_id")
        await loadSubjects()
    }

    public func toggleSubjectHidden(_ subject: Subject) async {
        let newHidden = !subject.isHidden
        await journalService.setSubjectHidden(disciplineId: subject.disciplineId, term: selectedTerm, hidden: newHidden)
        if let idx = subjects.firstIndex(where: { $0.disciplineId == subject.disciplineId }) {
            subjects[idx].isHidden = newHidden
        }
    }

    public func loadJournal(for subject: Subject) async {
        activeSubject = subject
        isLoading = true
        errorMessage = nil
        do {
            let journal = try await journalService.fetchJournal(disciplineId: subject.disciplineId, term: selectedTerm)
            self.currentJournal = journal

            // Записываем общий рейтинг выбранного семестра после получения
            // свежего журнала. SupabaseService сам подавляет одинаковые точки.
            let latestRating = journal.totalRating > 0 ? journal.totalRating : journal.currentRating
            if let subjectIndex = subjects.firstIndex(where: { $0.disciplineId == subject.disciplineId }) {
                subjects[subjectIndex].rating = latestRating
            }
            let semesterSubjects = subjects.filter { !$0.isHidden && $0.termNumber == selectedTerm }
            var ratings = semesterSubjects.map(\.rating)
            if let index = semesterSubjects.firstIndex(where: { $0.disciplineId == subject.disciplineId }) {
                ratings[index] = latestRating
            }
            if !ratings.isEmpty {
                let overall = ratings.reduce(0, +) / Double(ratings.count)
                let userId = KeychainHelper.shared.readString(key: "app_user_uuid") ?? ""
                await supabase.recordOverallRating(userId: userId, term: selectedTerm, rating: overall)
            }

            // Загрузка сохраненного плана моделирования
            let drafts = await store.loadDrafts()
            self.activeDraft = drafts[subject.disciplineId]

            // Фоновая синхронизация с Supabase
            let checkpoints = await supabase.syncSubjectData(
                subjectId: subject.disciplineId,
                subjectName: subject.disciplineName,
                teacherName: subject.instructor,
                entries: journal.currentControl
            )
            let counts = await supabase.getMaterialsCountForSubject(subjectId: subject.disciplineId)
            if !checkpoints.isEmpty {
                var updatedControl = journal.currentControl
                for i in 0..<updatedControl.count {
                    if let cp = checkpoints.first(where: { $0.title == updatedControl[i].title }) {
                        updatedControl[i].backendId = cp.id
                        if let count = counts[cp.id] {
                            updatedControl[i].materialsCount = count
                        }
                    }
                }
                self.currentJournal?.currentControl = updatedControl
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    public func savePlan(scores: [Double], bonus: Double, isExam: Bool, examScore: Double) async {
        guard let subject = activeSubject else { return }
        let plan = SavedPlan(
            disciplineId: subject.disciplineId,
            subjectName: subject.disciplineName,
            scores: scores,
            bonus: bonus,
            isExam: isExam,
            examScore: examScore
        )
        await store.saveDraft(plan)
        self.activeDraft = plan
    }

    public func revertPlan() async {
        guard let subject = activeSubject else { return }
        await store.removeDraft(disciplineId: subject.disciplineId)
        self.activeDraft = nil
    }

    public func updateSettings(_ newSettings: AppSettings) async {
        self.settings = newSettings
        await store.saveSettings(newSettings)
    }
}
