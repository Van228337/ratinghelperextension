import Foundation

public actor SusuScheduleService {
    public static let shared = SusuScheduleService()

    private let auth = SusuAuthService.shared
    private let client = HTTPClient.shared
    private let store = LocalStore.shared
    private var lastFetchTimes: [String: Date] = [:]

    private init() {}

    public static var susuCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Yekaterinburg") ?? TimeZone(secondsFromGMT: 5 * 3600)!
        cal.locale = Locale(identifier: "ru_RU")
        return cal
    }

    public static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Yekaterinburg") ?? TimeZone(secondsFromGMT: 5 * 3600)!
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: Date())
    }

    public static func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Yekaterinburg") ?? TimeZone(secondsFromGMT: 5 * 3600)!
        return formatter.string(from: date)
    }

    public func fetchSchedule(groupId: String, forceRefresh: Bool = false) async throws -> [ScheduleLesson] {
        let cleanGroupId = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanGroupId.isEmpty else {
            throw NetworkError.invalidURL("Не указан идентификатор академической группы (groupId).")
        }

        if !forceRefresh,
           let lastFetch = lastFetchTimes[cleanGroupId],
           Date().timeIntervalSince(lastFetch) < 1800,
           let cached = await store.loadSchedule(groupId: cleanGroupId), !cached.isEmpty {
            return cached
        }

        let token = try await auth.validToken()
        let urlString = APIEndpoints.groupSchedule(groupId: cleanGroupId)
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let headers = [
            "Authorization": "Bearer \(token)",
            "Accept": "application/json, text/plain, */*",
            "Origin": APIEndpoints.susuBase
        ]

        do {
            let lessons: [ScheduleLesson] = try await client.requestJSON(url: url, headers: headers)
            lastFetchTimes[cleanGroupId] = Date()
            await store.saveSchedule(groupId: cleanGroupId, lessons: lessons)
            return lessons
        } catch {
            if let offlineCached = await store.loadSchedule(groupId: cleanGroupId), !offlineCached.isEmpty {
                return offlineCached
            }
            throw error
        }
    }

    public static func matchLessons(lessons: [ScheduleLesson], with subjects: [Subject]) -> [ScheduleLesson] {
        guard !subjects.isEmpty else { return lessons }
        var result = lessons
        for i in 0..<result.count {
            let lessonSubjectClean = normalize(result[i].subject)
            if let matched = subjects.first(where: {
                let subNameClean = normalize($0.disciplineName)
                return subNameClean == lessonSubjectClean ||
                       subNameClean.contains(lessonSubjectClean) ||
                       lessonSubjectClean.contains(subNameClean)
            }) {
                result[i].matchedSubjectId = matched.disciplineId
            }
        }
        return result
    }

    private static func normalize(_ str: String) -> String {
        str.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
