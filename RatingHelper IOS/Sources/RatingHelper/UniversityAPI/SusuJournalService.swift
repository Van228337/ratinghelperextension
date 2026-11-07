import Foundation

public actor SusuJournalService {
    public static let shared = SusuJournalService()

    private let auth = SusuAuthService.shared
    private let client = HTTPClient.shared
    private let store = LocalStore.shared

    private init() {}

    private func authHeaders(token: String) -> [String: String] {
        [
            "Accept": "application/json, text/plain, */*",
            "Authorization": "Bearer \(token)",
            "Referer": "\(APIEndpoints.susuBase)/study-activity/"
        ]
    }

    public func fetchSubjects(term: Int) async throws -> [Subject] {
        var token: String
        do {
            token = try await auth.validToken()
        } catch {
            // Offline fallback
            if let cached = await store.loadSubjects(term: term), !cached.isEmpty {
                return cached
            }
            throw error
        }

        guard let url = URL(string: APIEndpoints.subjects(term: term)) else {
            throw NetworkError.invalidURL(APIEndpoints.subjects(term: term))
        }

        do {
            var rawList: [RawSubjectResponse]
            do {
                rawList = try await client.requestJSON(
                    url: url,
                    headers: authHeaders(token: token)
                )
            } catch NetworkError.unauthorized {
                // Try refresh token once
                let refreshed = try await auth.refreshToken()
                token = refreshed.accessToken
                rawList = try await client.requestJSON(
                    url: url,
                    headers: authHeaders(token: token)
                )
            }

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

    public func fetchJournal(disciplineId: String, term: Int) async throws -> JournalData {
        var token: String
        do {
            token = try await auth.validToken()
        } catch {
            // Offline fallback
            if let cached = await store.loadJournal(disciplineId: disciplineId, term: term) {
                return cached
            }
            throw error
        }

        guard let url = URL(string: APIEndpoints.journal(disciplineId: disciplineId, term: term)) else {
            throw NetworkError.invalidURL(APIEndpoints.journal(disciplineId: disciplineId, term: term))
        }

        do {
            var raw: RawJournalResponse
            do {
                raw = try await client.requestJSON(
                    url: url,
                    headers: authHeaders(token: token)
                )
            } catch NetworkError.unauthorized {
                // Try refresh token once
                let refreshed = try await auth.refreshToken()
                token = refreshed.accessToken
                raw = try await client.requestJSON(
                    url: url,
                    headers: authHeaders(token: token)
                )
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
