import Foundation

public struct MoodleCalendarEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let courseId: Int?
    public let courseName: String?
    public let timestart: Int64
    public let component: String?
    public let eventtype: String?
    public let url: String?
    public let instance: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, component, eventtype, url, instance
        case timestart
        case course
    }

    struct MoodleCourseInfo: Codable {
        let id: Int?
        let fullname: String?
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Дедлайн"
        component = try? c.decodeIfPresent(String.self, forKey: .component)
        eventtype = try? c.decodeIfPresent(String.self, forKey: .eventtype)
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        instance = try? c.decodeIfPresent(Int.self, forKey: .instance)
        timestart = (try? c.decode(Int64.self, forKey: .timestart)) ?? 0

        if let courseObj = try? c.decodeIfPresent(MoodleCourseInfo.self, forKey: .course) {
            courseId = courseObj.id
            courseName = courseObj.fullname
        } else {
            courseId = nil
            courseName = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(component, forKey: .component)
        try c.encodeIfPresent(eventtype, forKey: .eventtype)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(instance, forKey: .instance)
        try c.encode(timestart, forKey: .timestart)
        if courseId != nil || courseName != nil {
            try c.encode(MoodleCourseInfo(id: courseId, fullname: courseName), forKey: .course)
        }
    }

    public var deadlineDate: Date {
        Date(timeIntervalSince1970: TimeInterval(timestart))
    }

    public var isAssignmentDeadline: Bool {
        component == "mod_assign" && eventtype == "due"
    }

    public var isQuizClose: Bool {
        component == "mod_quiz" && eventtype == "close"
    }

    public func toStudyTask() -> StudyTask {
        StudyTask(
            title: name,
            notes: "Импортировано из Moodle (edu.susu.ru). Курс: \(courseName ?? "Учебный курс").",
            disciplineName: courseName,
            sourceDeadline: deadlineDate,
            customDeadline: deadlineDate,
            dueDate: deadlineDate,
            externalSource: .moodle,
            externalId: "moodle_\(id)",
            priority: .high
        )
    }
}

public actor MoodleCalendarService {
    public static let shared = MoodleCalendarService()

    private let client = HTTPClient.shared
    private let keychain = KeychainHelper.shared

    private init() {}

    public func saveMoodleCredentials(moodleSession: String, sesskey: String) {
        _ = keychain.saveString(key: "moodle_session_cookie", value: moodleSession.trimmingCharacters(in: .whitespacesAndNewlines))
        _ = keychain.saveString(key: "moodle_sesskey", value: sesskey.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public func loadMoodleCredentials() -> (session: String, sesskey: String)? {
        guard let s = keychain.readString(key: "moodle_session_cookie"), !s.isEmpty,
              let k = keychain.readString(key: "moodle_sesskey"), !k.isEmpty else {
            return nil
        }
        return (session: s, sesskey: k)
    }

    public func hasActiveMoodleSession() -> Bool {
        loadMoodleCredentials() != nil
    }

    public func clearMoodleSession() {
        _ = keychain.delete(key: "moodle_session_cookie")
        _ = keychain.delete(key: "moodle_sesskey")
    }

    public func performMoodleLogin(username: String? = nil, password: String? = nil) async throws -> (session: String, sesskey: String) {
        let u = username ?? keychain.readString(key: "susu_username")
        let p = password ?? keychain.readString(key: "susu_password")
        guard let u = u, !u.isEmpty, let p = p, !p.isEmpty else {
            throw NetworkError.unauthorized("Для входа в Moodle (edu.susu.ru) требуются логин и пароль ЮУрГУ.")
        }

        guard let loginPageUrl = URL(string: "https://edu.susu.ru/login/index.php") else {
            throw NetworkError.invalidURL("https://edu.susu.ru/login/index.php")
        }

        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        let sessionUrl = URLSession(configuration: config)

        var getReq = URLRequest(url: loginPageUrl)
        getReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        getReq.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (htmlData, getResp) = try await sessionUrl.data(for: getReq)
        guard let httpGetResp = getResp as? HTTPURLResponse else {
            throw NetworkError.serverError(0, "Неверный ответ шлюза Moodle")
        }

        let htmlString = String(data: htmlData, encoding: .utf8) ?? ""
        var tempMoodleSession = ""

        if let setCookie = httpGetResp.value(forHTTPHeaderField: "Set-Cookie") {
            tempMoodleSession = extractCookieValue(from: setCookie, cookieName: "MoodleSession")
        }

        var loginToken = ""
        let pattern = #"name=["']logintoken["']\s+value=["']([a-zA-Z0-9]+)["']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString)),
           let tokenRange = Range(match.range(at: 1), in: htmlString) {
            loginToken = String(htmlString[tokenRange])
        } else {
            let altPattern = #"value=["']([a-zA-Z0-9]+)["']\s+name=["']logintoken["']"#
            if let altRegex = try? NSRegularExpression(pattern: altPattern, options: .caseInsensitive),
               let match = altRegex.firstMatch(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString)),
               let tokenRange = Range(match.range(at: 1), in: htmlString) {
                loginToken = String(htmlString[tokenRange])
            }
        }

        var postReq = URLRequest(url: loginPageUrl)
        postReq.httpMethod = "POST"
        postReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        postReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        postReq.setValue("https://edu.susu.ru", forHTTPHeaderField: "Origin")
        postReq.setValue("https://edu.susu.ru/login/index.php", forHTTPHeaderField: "Referer")
        if !tempMoodleSession.isEmpty {
            postReq.setValue("MoodleSession=\(tempMoodleSession)", forHTTPHeaderField: "Cookie")
        }

        let uEncoded = u.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? u
        let pEncoded = p.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? p
        let postBodyString = "anchor=&logintoken=\(loginToken)&username=\(uEncoded)&password=\(pEncoded)"
        postReq.httpBody = postBodyString.data(using: .utf8)

        let (postData, postResp) = try await sessionUrl.data(for: postReq)
        guard let httpPostResp = postResp as? HTTPURLResponse else {
            throw NetworkError.serverError(0, "Неверный ответ на авторизацию Moodle")
        }

        var authMoodleSession = tempMoodleSession
        if let postSetCookie = httpPostResp.value(forHTTPHeaderField: "Set-Cookie") {
            let extracted = extractCookieValue(from: postSetCookie, cookieName: "MoodleSession")
            if !extracted.isEmpty {
                authMoodleSession = extracted
            }
        }

        let postHtml = String(data: postData, encoding: .utf8) ?? ""
        if postHtml.contains("Неверный логин или пароль") || postHtml.contains("Invalid login") {
            throw NetworkError.unauthorized("Неверный логин или пароль для входа в Moodle (edu.susu.ru).")
        }

        guard let homeUrl = URL(string: "https://edu.susu.ru/") else {
            throw NetworkError.invalidURL("https://edu.susu.ru/")
        }
        var homeReq = URLRequest(url: homeUrl)
        homeReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        homeReq.setValue("MoodleSession=\(authMoodleSession)", forHTTPHeaderField: "Cookie")

        let (homeData, _) = try await sessionUrl.data(for: homeReq)
        let homeHtml = String(data: homeData, encoding: .utf8) ?? ""

        var sesskey = ""
        let sesskeyPattern = #"["']sesskey["']\s*:\s*["']([a-zA-Z0-9]{10})["']"#
        if let regex = try? NSRegularExpression(pattern: sesskeyPattern),
           let match = regex.firstMatch(in: homeHtml, range: NSRange(homeHtml.startIndex..., in: homeHtml)),
           let range = Range(match.range(at: 1), in: homeHtml) {
            sesskey = String(homeHtml[range])
        } else {
            let sesskeyUrlPattern = #"sesskey=([a-zA-Z0-9]{10})"#
            if let regex = try? NSRegularExpression(pattern: sesskeyUrlPattern),
               let match = regex.firstMatch(in: homeHtml, range: NSRange(homeHtml.startIndex..., in: homeHtml)),
               let range = Range(match.range(at: 1), in: homeHtml) {
                sesskey = String(homeHtml[range])
            }
        }

        guard !sesskey.isEmpty else {
            throw NetworkError.unauthorized("Не удалось извлечь sesskey из сессии Moodle.")
        }

        saveMoodleCredentials(moodleSession: authMoodleSession, sesskey: sesskey)
        return (session: authMoodleSession, sesskey: sesskey)
    }

    private func extractCookieValue(from header: String, cookieName: String) -> String {
        for part in header.components(separatedBy: ",") {
            for item in part.components(separatedBy: ";") {
                let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("\(cookieName)=") {
                    return String(trimmed.dropFirst("\(cookieName)=".count))
                }
            }
        }
        return ""
    }

    public func fetchMonthlyEvents(year: Int, month: Int) async throws -> [MoodleCalendarEvent] {
        var creds = loadMoodleCredentials()
        if creds == nil {
            // Automatic login if credentials exist in Keychain
            creds = try? await performMoodleLogin()
        }

        guard let currentCreds = creds else {
            throw NetworkError.unauthorized("Требуется вход в Moodle (edu.susu.ru).")
        }

        func sendRequest(session: String, sesskey: String) async throws -> (Data, URLResponse) {
            let urlString = "https://edu.susu.ru/lib/ajax/service.php?sesskey=\(sesskey)&info=core_calendar_get_calendar_monthly_view"
            guard let url = URL(string: urlString) else {
                throw NetworkError.invalidURL(urlString)
            }

            let payload: [[String: Any]] = [[
                "index": 0,
                "methodname": "core_calendar_get_calendar_monthly_view",
                "args": [
                    "year": year,
                    "month": month,
                    "courseid": 1,
                    "categoryid": 0,
                    "includenavigation": true,
                    "mini": false,
                    "day": 1
                ]
            ]]

            let bodyData = try JSONSerialization.data(withJSONObject: payload)

            let headers = [
                "Content-Type": "application/json",
                "Accept": "application/json, text/javascript, */*; q=0.01",
                "X-Requested-With": "XMLHttpRequest",
                "Origin": "https://edu.susu.ru",
                "Referer": "https://edu.susu.ru/calendar/view.php?view=month",
                "Cookie": "MoodleSession=\(session)"
            ]

            return try await client.request(url: url, method: "POST", headers: headers, body: bodyData)
        }

        var (data, _) = try await sendRequest(session: currentCreds.session, sesskey: currentCreds.sesskey)

        // Check if session or sesskey expired
        let rawStr = String(data: data, encoding: .utf8) ?? ""
        if rawStr.contains("invalidsesskey") || rawStr.contains("requireloginerror") {
            // Auto re-login once
            let refreshed = try await performMoodleLogin()
            let (retryData, _) = try await sendRequest(session: refreshed.session, sesskey: refreshed.sesskey)
            data = retryData
        }

        // Moodle возвращает JSON-массив результатов вызовов методов
        struct BatchResponse: Decodable {
            let error: Bool?
            let data: MonthlyViewData?
        }
        struct MonthlyViewData: Decodable {
            let weeks: [WeekItem]?
        }
        struct WeekItem: Decodable {
            let days: [DayItem]?
        }
        struct DayItem: Decodable {
            let events: [MoodleCalendarEvent]?
        }

        let decoder = JSONDecoder()
        if let batch = try? decoder.decode([BatchResponse].self, from: data),
           let first = batch.first, first.error != true,
           let weeks = first.data?.weeks {
            var extracted: [MoodleCalendarEvent] = []
            for w in weeks {
                guard let days = w.days else { continue }
                for d in days {
                    if let evs = d.events {
                        extracted.append(contentsOf: evs)
                    }
                }
            }
            return extracted.filter { $0.isAssignmentDeadline || $0.isQuizClose }
        }

        return []
    }
}
