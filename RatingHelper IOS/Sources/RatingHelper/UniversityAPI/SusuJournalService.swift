import Foundation

public actor SusuJournalService {
    public static let shared = SusuJournalService()

    private let auth = SusuAuthService.shared
    private let client = HTTPClient.shared
    private let store = LocalStore.shared

    private init() {}

    private func defaultHeaders() -> [String: String] {
        [
            "Accept": "application/json, text/plain, */*",
            "Referer": "\(APIEndpoints.susuBase)/study-activity/"
        ]
    }

    public func fetchSubjects(term: Int) async throws -> [Subject] {
        guard let url = URL(string: APIEndpoints.subjects(term: term)) else {
            throw NetworkError.invalidURL(APIEndpoints.subjects(term: term))
        }

        do {
            let rawList: [RawSubjectResponse] = try await auth.performAuthorizedRequest(
                url: url,
                headers: defaultHeaders()
            )

            let hiddenSet = await store.loadHiddenSubjects()

            let normalized = rawList
                .filter { ($0.termNumber ?? term) == term }
                .map { raw in
                    let isHidden = hiddenSet.contains("\(term):\(raw.disciplineId)")
                    return Subject.from(raw: raw, term: term, isHidden: isHidden)
                }

            await store.saveSubjects(normalized, term: term)
            return normalized
        } catch {
            // Offline fallback if network error
            if let cached = await store.loadSubjects(term: term), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    public func fetchJournal(disciplineId: String, term: Int, isCourseWork: Bool = false) async throws -> JournalData {
        func requestJournal(isCw: Bool) async throws -> RawJournalResponse {
            guard let url = URL(string: APIEndpoints.journal(disciplineId: disciplineId, term: term, isCourseWork: isCw)) else {
                throw NetworkError.invalidURL(APIEndpoints.journal(disciplineId: disciplineId, term: term, isCourseWork: isCw))
            }
            return try await auth.performAuthorizedRequest(url: url, headers: defaultHeaders())
        }

        do {
            var raw: RawJournalResponse
            do {
                raw = try await requestJournal(isCw: isCourseWork)
            } catch {
                // If primary request failed, try opposite isCourseWork flag
                if let fallback = try? await requestJournal(isCw: !isCourseWork) {
                    raw = fallback
                } else {
                    throw error
                }
            }

            let journal = JournalData.from(raw: raw, disciplineId: disciplineId, term: term)
            await store.saveJournal(journal)

            // Save to semester history for dashboard
            let historyItem = SemesterHistoryItem(
                name: journal.disciplineName,
                subjectId: disciplineId,
                rating: journal.totalRating > 0 ? journal.totalRating : journal.currentRating
            )
            await store.saveSemesterHistoryItem(historyItem)

            return journal
        } catch {
            // Offline fallback if network error
            if let cached = await store.loadJournal(disciplineId: disciplineId, term: term) {
                return cached
            }
            throw error
        }
    }

    public func setSubjectHidden(disciplineId: String, term: Int, hidden: Bool) async {
        let key = "\(term):\(disciplineId)"
        var hiddenSet = await store.loadHiddenSubjects()
        if hidden {
            hiddenSet.insert(key)
        } else {
            hiddenSet.remove(key)
        }
        await store.saveHiddenSubjects(hiddenSet)

        // Update cached subjects
        if var list = await store.loadSubjects(term: term) {
            for i in 0..<list.count {
                if list[i].disciplineId == disciplineId {
                    list[i].isHidden = hidden
                }
            }
            await store.saveSubjects(list, term: term)
        }
    }
}
