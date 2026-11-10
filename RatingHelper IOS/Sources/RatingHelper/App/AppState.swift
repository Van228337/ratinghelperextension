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
    @Published public var isOfflineMode: Bool = false
    @Published public var lastSyncDescription: String? = nil
    @Published public var errorMessage: String?
    @Published public var activeDraft: SavedPlan?

    private let auth = SusuAuthService.shared
    private let journalService = SusuJournalService.shared
    private let supabase = SupabaseService.shared
    private let store = LocalStore.shared

    public var effectiveUserId: String {
        if let u = appUser, !u.userId.isEmpty {
            return u.userId
        }
        if let saved = KeychainHelper.shared.readString(key: "rating_helper_user_uuid"), !saved.isEmpty {
            return saved
        }
        return session?.externalUserId ?? session?.username ?? ""
    }

    public var isBanned: Bool {
        appUser?.isBanned == true
    }

    public init() {
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
        guard let s = session else { return }
        let extUserId = s.externalUserId ?? s.username
        let profile = s.studentProfile

        let resolved = await supabase.resolveOrRegisterUser(
            externalUserId: extUserId,
            externalIdentity: s.identity,
            username: s.username,
            fullName: s.fullName,
            email: s.email,
            susuEmail: s.susuEmail,
            groupId: profile?.groupId,
            groupName: profile?.groupName,
            specialityCode: profile?.specialityCode,
            specialityName: profile?.specialityName,
            unitName: profile?.unitName,
            educationLevel: profile?.educationLevel,
            educationForm: profile?.educationForm,
            studyYears: profile?.studyYears,
            appVersion: "2.1.0",
            deviceInfo: "iPhone / iOS Native"
        )

        self.appUser = resolved
        _ = KeychainHelper.shared.saveString(key: "rating_helper_user_uuid", value: resolved.userId)
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
        self.appUser = nil
    }

    public func loadSubjects(forceRefresh: Bool = false) async {
        if appUser?.isBanned == true {
            errorMessage = "Ваша учётная запись заблокирована: \(appUser?.banReason ?? "нарушение правил")."
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let list = try await journalService.fetchSubjects(term: selectedTerm)
            self.subjects = list
            self.lastSyncDescription = await store.formattedLastSync(key: "subjects_term_\(selectedTerm)")
            self.isOfflineMode = false
            isLoading = false
        } catch {
            if let cached = await store.loadSubjects(term: selectedTerm), !cached.isEmpty {
                self.subjects = cached
                self.isOfflineMode = true
                self.lastSyncDescription = await store.formattedLastSync(key: "subjects_term_\(selectedTerm)")
            } else {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    public func toggleSubjectHidden(_ subject: Subject) async {
        let newHidden = !subject.isHidden
        await journalService.setSubjectHidden(disciplineId: subject.disciplineId, term: selectedTerm, hidden: newHidden)
        if let idx = subjects.firstIndex(where: { $0.disciplineId == subject.disciplineId }) {
            subjects[idx].isHidden = newHidden
        }
    }

    private var termLoadTask: Task<Void, Never>?

    public func selectTerm(_ term: Int) async {
        termLoadTask?.cancel()
        self.selectedTerm = term
        UserDefaults.standard.set(term, forKey: "selected_term_id")
        self.currentJournal = nil
        self.activeSubject = nil
        self.subjects = [] // Immediate reset: don't show old semester subjects as new!
        self.isLoading = true
        self.errorMessage = nil

        let task = Task { [weak self, term] in
            guard let self = self else { return }
            do {
                let list = try await self.journalService.fetchSubjects(term: term)
                guard !Task.isCancelled else { return }
                let syncText = await self.store.formattedLastSync(key: "subjects_term_\(term)")
                await MainActor.run {
                    if self.selectedTerm == term {
                        self.subjects = list
                        self.lastSyncDescription = syncText
                        self.isOfflineMode = false
                        self.isLoading = false
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                let cached = await self.store.loadSubjects(term: term)
                let syncText = await self.store.formattedLastSync(key: "subjects_term_\(term)")
                await MainActor.run {
                    if self.selectedTerm == term {
                        if let cached = cached, !cached.isEmpty {
                            self.subjects = cached
                            self.isOfflineMode = true
                            self.lastSyncDescription = syncText
                        } else {
                            self.errorMessage = error.localizedDescription
                        }
                        self.isLoading = false
                    }
                }
            }
        }
        termLoadTask = task
        await task.value
    }

    public func changeTerm(_ term: Int) async {
        await selectTerm(term)
    }

    public func loadJournal(for subject: Subject) async {
        if appUser?.isBanned == true {
            errorMessage = "Ваша учётная запись заблокирована: \(appUser?.banReason ?? "обратитесь к администратору")."
            return
        }

        self.activeSubject = subject
        self.currentJournal = nil
        isLoading = true
        errorMessage = nil
        let isCw = (subject.assessmentType == .coursework || subject.assessmentType == .courseProject)
        do {
            let journal = try await journalService.fetchJournal(disciplineId: subject.disciplineId, term: selectedTerm, isCourseWork: isCw)
            self.currentJournal = journal

            let latestRating = journal.totalRating > 0 ? journal.totalRating : journal.currentRating
            if let subjectIndex = subjects.firstIndex(where: { $0.disciplineId == subject.disciplineId }) {
                subjects[subjectIndex].rating = latestRating
            }
            let semesterSubjects = subjects.filter { !$0.isHidden && $0.termNumber == selectedTerm }
            var ratings = semesterSubjects.map(\.rating)
            if let index = semesterSubjects.firstIndex(where: { $0.disciplineId == subject.disciplineId }) {
                ratings[index] = latestRating
            }

            let uId = effectiveUserId
            if !uId.isEmpty {
                // 1. Запись истории конкретной дисциплины
                if UUID(uuidString: subject.disciplineId) != nil {
                    await supabase.recordRatingPoint(userId: uId, term: selectedTerm, subjectId: subject.disciplineId, rating: latestRating)
                }

                // 2. Запись общего рейтинга семестра
                if !ratings.isEmpty {
                    let overall = ratings.reduce(0, +) / Double(ratings.count)
                    await supabase.recordOverallRating(userId: uId, term: selectedTerm, rating: overall)
                }
            }

            // Загрузка сохраненного плана моделирования
            let drafts = await store.loadDrafts()
            self.activeDraft = drafts[subject.disciplineId]

            // Фоновая синхронизация с Supabase (все типы контрольных точек: контроль, лабы, курсовые)
            let allEntries = journal.allContinuousAssignments
            let checkpoints = await supabase.syncSubjectData(
                subjectId: subject.disciplineId,
                subjectName: subject.disciplineName,
                teacherName: subject.instructor,
                entries: allEntries
            )
            let counts = await supabase.getMaterialsCountForSubject(subjectId: subject.disciplineId)
            if !checkpoints.isEmpty {
                func updateItems(_ list: inout [CheckpointItem]) {
                    for i in 0..<list.count {
                        if let cp = checkpoints.first(where: { $0.title == list[i].title }) {
                            list[i].backendId = cp.id
                            if let count = counts[cp.id] {
                                list[i].materialsCount = count
                            }
                        }
                    }
                }
                var updatedControl = journal.currentControl
                var updatedLabs = journal.labs
                var updatedCw = journal.courseWorksOrProjects
                updateItems(&updatedControl)
                updateItems(&updatedLabs)
                updateItems(&updatedCw)
                self.currentJournal?.currentControl = updatedControl
                self.currentJournal?.labs = updatedLabs
                self.currentJournal?.courseWorksOrProjects = updatedCw
            }

            isLoading = false
        } catch {
            if let cached = await store.loadJournal(disciplineId: subject.disciplineId, term: selectedTerm) {
                self.currentJournal = cached
                self.isOfflineMode = true
                let drafts = await store.loadDrafts()
                self.activeDraft = drafts[subject.disciplineId]
            } else {
                errorMessage = error.localizedDescription
            }
            isLoading = false
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
