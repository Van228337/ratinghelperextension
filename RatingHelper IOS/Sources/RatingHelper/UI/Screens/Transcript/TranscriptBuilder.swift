import Foundation

/// Собирает данные выписки из уже существующих источников приложения:
/// списка дисциплин, журналов (SusuJournalService) и сохранённых планов
/// моделирования. Ничего не записывает в ЮУрГУ или Supabase.
@MainActor
public final class TranscriptBuilder {
    public static let shared = TranscriptBuilder()

    private let store = LocalStore.shared
    private let journalService = SusuJournalService.shared

    private init() {}

    public func activeSubjects(in appState: AppState) -> [Subject] {
        appState.subjects.filter { !$0.isHidden && $0.termNumber == appState.selectedTerm }
    }

    public func build(
        variant: TranscriptVariant,
        mode: TranscriptMode,
        subjectId: String?,
        appState: AppState
    ) async throws -> TranscriptDocument {
        let term = appState.selectedTerm
        var subjects = activeSubjects(in: appState)
        if subjects.isEmpty {
            await appState.loadSubjects()
            subjects = activeSubjects(in: appState)
        }
        guard !subjects.isEmpty else { throw TranscriptError.noSubjects }

        let drafts = await store.loadDrafts()
        let student = appState.session?.username ?? ""
        let profile = appState.session?.studentProfile
        let group = profile?.groupName ?? ""
        let institute = profile?.parentShortName ?? profile?.unitShortName ?? ""

        let disciplines: [TranscriptDiscipline]
        var averageRating: Double? = nil
        let effectiveMode: TranscriptMode

        switch variant {
        case .single:
            guard let subjectId, let subject = subjects.first(where: { $0.id == subjectId }) else {
                throw TranscriptError.disciplineNotFound
            }
            let journal = try? await journalService.fetchJournal(
                disciplineId: subject.disciplineId,
                term: term,
                isCourseWork: subject.isCourseWork
            )
            guard let journal else { throw TranscriptError.journalUnavailable }

            disciplines = [
                makeDiscipline(
                    subject: subject,
                    journal: journal,
                    draft: mode == .simulated ? drafts[subject.id] : nil,
                    withSimulation: mode == .simulated
                )
            ]
            effectiveMode = mode

        case .allDisciplines:
            let journals = await loadJournals(for: subjects, term: term)
            disciplines = subjects.map { subject in
                if let journal = journals[subject.id] {
                    return makeDiscipline(
                        subject: subject,
                        journal: journal,
                        draft: nil,
                        withSimulation: false
                    )
                }
                return makeFallbackDiscipline(subject: subject)
            }
            effectiveMode = .actual

        case .overall:
            disciplines = subjects.map { makeFallbackDiscipline(subject: $0) }
            let activeRatings = disciplines.map(\.factRating).filter { $0 > 0 }
            averageRating = activeRatings.isEmpty ? nil : activeRatings.reduce(0, +) / Double(activeRatings.count)
            effectiveMode = .actual
        }

        return TranscriptDocument(
            variant: variant,
            mode: effectiveMode,
            term: term,
            academicYear: Self.academicYear(),
            student: student,
            group: group,
            institute: institute,
            generatedAt: Date(),
            disciplines: disciplines,
            averageRating: averageRating
        )
    }

    // MARK: - Data loading

    private func loadJournals(for subjects: [Subject], term: Int) async -> [String: JournalData] {
        await withTaskGroup(of: (String, JournalData?).self) { group in
            for subject in subjects {
                group.addTask {
                    let journal = try? await SusuJournalService.shared.fetchJournal(
                        disciplineId: subject.disciplineId,
                        term: term,
                        isCourseWork: subject.isCourseWork
                    )
                    return (subject.id, journal)
                }
            }
            var result: [String: JournalData] = [:]
            for await (id, journal) in group {
                if let journal { result[id] = journal }
            }
            return result
        }
    }

    // MARK: - Discipline building

    private func makeDiscipline(
        subject: Subject,
        journal: JournalData,
        draft: SavedPlan?,
        withSimulation: Bool
    ) -> TranscriptDiscipline {
        let entries = journal.allContinuousAssignments
        let factBonus = officialBonus(for: journal)
        let fact = RatingCalculator.compute(
            entries: entries,
            scores: entries.map(\.current),
            bonus: factBonus,
            isExam: false,
            examScore: 0,
            assessmentType: subject.assessmentType
        )

        let validDraft: SavedPlan? = {
            guard withSimulation,
                  let draft,
                  draft.scores.count == entries.count,
                  hasSimulationChanges(draft: draft, entries: entries, journal: journal, factBonus: factBonus)
            else { return nil }
            return draft
        }()

        let planned: RatingResult? = validDraft.map { draft in
            RatingCalculator.compute(
                entries: entries,
                scores: draft.scores,
                bonus: simulationBonus(for: draft, journal: journal),
                isExam: draft.isExam,
                examScore: draft.examScore,
                assessmentType: subject.assessmentType
            )
        }

        let checkpoints = entries.enumerated().map { index, entry in
            TranscriptCheckpoint(
                index: index,
                title: entry.title,
                fact: entry.current,
                maxScore: entry.max,
                planned: validDraft.map { $0.scores[index] }
            )
        }

        return TranscriptDiscipline(
            id: subject.id,
            name: subject.disciplineName,
            assessmentType: subject.assessmentType,
            instructor: subject.instructor,
            checkpoints: checkpoints,
            factRating: fact.finalRating,
            factGrade: fact.grade,
            plannedRating: planned?.finalRating,
            plannedGrade: planned?.grade,
            checkpointsUnavailable: false
        )
    }

    private func makeFallbackDiscipline(subject: Subject) -> TranscriptDiscipline {
        let rating = subject.rating
        return TranscriptDiscipline(
            id: subject.id,
            name: subject.disciplineName,
            assessmentType: subject.assessmentType,
            instructor: subject.instructor,
            checkpoints: [],
            factRating: rating,
            factGrade: AcademicGrade.from(percentage: rating),
            plannedRating: nil,
            plannedGrade: nil,
            checkpointsUnavailable: true
        )
    }

    // MARK: - Rating helpers (та же логика, что и в журнале)

    /// Официальные бонусы журнала — ровно так, как их учитывает JournalView
    /// при первом открытии дисциплины.
    private func officialBonus(for journal: JournalData) -> Double {
        guard journal.bonusInfo.detectedPoints > 0 else { return 0 }
        return journal.bonusInfo.known
            ? journal.bonusInfo.detectedPoints * journal.bonusInfo.percentPerPoint
            : journal.bonusInfo.detectedPoints
    }

    /// Бонус сохранённого плана — так же, как его восстанавливает симулятор.
    private func simulationBonus(for draft: SavedPlan, journal: JournalData) -> Double {
        guard draft.bonus > 0 else { return 0 }
        return journal.bonusInfo.known
            ? draft.bonus * journal.bonusInfo.percentPerPoint
            : draft.bonus
    }

    private func hasSimulationChanges(
        draft: SavedPlan,
        entries: [CheckpointItem],
        journal: JournalData,
        factBonus: Double
    ) -> Bool {
        if draft.isExam { return true }
        if abs(simulationBonus(for: draft, journal: journal) - factBonus) > 0.001 { return true }
        for (index, entry) in entries.enumerated()
        where abs(draft.scores[index] - entry.current) > 0.001 {
            return true
        }
        return false
    }

    // MARK: - Dates

    static func academicYear(reference: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let year = calendar.component(.year, from: reference)
        let month = calendar.component(.month, from: reference)
        return month >= 9 ? "\(year)/\(year + 1)" : "\(year - 1)/\(year)"
    }
}
