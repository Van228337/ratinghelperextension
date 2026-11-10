import Foundation

public struct ServerModerationResponse: Codable, Sendable {
    public let success: Bool?
    public let allowed: Bool?
    public let reason: String?
    public let status: String?
    public let tokensUsed: Int?
    public let textHash: String?
    public let cached: Bool?
    public let error: String?
}

public struct ServerSummaryResponse: Codable, Sendable {
    public let success: Bool?
    public let summary: String?
    public let tokensUsed: Int?
    public let error: String?
}

public actor GroqModerationService {
    public static let shared = GroqModerationService()

    private let supabase = SupabaseService.shared
    private let client = HTTPClient.shared
    private var cachedScriptUrl: String?
    private var inFlightTasks: [String: Task<ModerationCheckResult, Never>] = [:]

    private init() {}

    private func getGatewayUrl() async -> String? {
        if let cached = cachedScriptUrl, !cached.isEmpty {
            return cached
        }

        let dedicated = await supabase.getConfig(key: "groq_gateway_url")
        let configured: String?
        if let dedicated, !dedicated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            configured = dedicated
        } else {
            configured = await supabase.getConfig(key: "google_drive_script_url")
        }
        let candidate = configured?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let candidate, let parsed = URL(string: candidate),
           parsed.scheme == "https", parsed.host != nil {
            self.cachedScriptUrl = candidate
        } else {
            self.cachedScriptUrl = APIEndpoints.googleAppsScriptGateway
        }
        return cachedScriptUrl
    }

    public func moderateReview(text: String, userId: String? = nil) async -> ModerationCheckResult {
        // Уровень 1: Локальный пре-фильтр (структура, символы, базовые корни)
        let localCheck = TextPreFilter.preFilter(text)
        guard localCheck.allowed else {
            return localCheck
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hashKey = trimmed.lowercased()

        // Защита от параллельных одинаковых вызовов (дедупликация)
        if let existingTask = inFlightTasks[hashKey] {
            return await existingTask.value
        }

        let task = Task<ModerationCheckResult, Never> { [weak self] in
            guard let self = self else {
                return ModerationCheckResult(allowed: false, reason: "Сервис модерации временно недоступен")
            }
            return await self.executeModeration(text: trimmed, userId: userId)
        }

        inFlightTasks[hashKey] = task
        defer {
            inFlightTasks.removeValue(forKey: hashKey)
        }

        return await task.value
    }

    private func executeModeration(text: String, userId: String?) async -> ModerationCheckResult {
        guard let gatewayUrlStr = await getGatewayUrl(), let url = URL(string: gatewayUrlStr) else {
            return ModerationCheckResult(
                allowed: false,
                reason: "Серверный адрес шлюза модерации недоступен. Проверьте подключение к базе данных."
            )
        }

        let payload: [String: Any] = [
            "action": "moderateReview",
            "text": text
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            return ModerationCheckResult(
                allowed: false,
                reason: "Ошибка сериализации запроса модерации."
            )
        }

        do {
            let resp: ServerModerationResponse = try await client.requestJSON(
                url: url,
                method: "POST",
                headers: ["Content-Type": "text/plain"],
                body: bodyData,
                timeoutInterval: 75
            )

            let tokens = resp.tokensUsed ?? 0
            if let uId = userId, !uId.isEmpty, tokens > 0 {
                await supabase.recordGroqUsage(userId: uId, tokensUsed: tokens, isRejected: resp.allowed == false)
            }

            if resp.success == false {
                let errText = resp.error ?? resp.reason ?? "Сервис AI-модерации временно недоступен"
                return ModerationCheckResult(allowed: false, reason: errText)
            }

            if let allowed = resp.allowed {
                return ModerationCheckResult(allowed: allowed, reason: resp.reason)
            }

            return ModerationCheckResult(
                allowed: false,
                reason: "Не получен утвердительный ответ от системы модерации."
            )
        } catch {
            print("Groq moderation error: \(error)")
            return ModerationCheckResult(
                allowed: false,
                reason: "Не удалось выполнить проверку нейросетью: \(error.localizedDescription). Публикация без проверки запрещена."
            )
        }
    }

    public func generateTeacherSummary(teacherName: String, reviews: [TeacherReview], userId: String? = nil) async -> String? {
        guard !reviews.isEmpty else { return nil }
        guard let gatewayUrlStr = await getGatewayUrl(), let url = URL(string: gatewayUrlStr) else {
            return nil
        }

        let slice = Array(reviews.prefix(15)).map { r in
            [
                "text": r.text,
                "difficulty": r.difficulty,
                "gives_avtomat": r.givesAvtomat,
                "attendance_strict": r.attendanceStrict
            ]
        }

        let payload: [String: Any] = [
            "action": "generateSummary",
            "teacherName": teacherName,
            "reviews": slice
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }

        do {
            let resp: ServerSummaryResponse = try await client.requestJSON(
                url: url,
                method: "POST",
                headers: ["Content-Type": "text/plain"],
                body: bodyData
            )

            if let uId = userId, !uId.isEmpty, let tokens = resp.tokensUsed, tokens > 0 {
                await supabase.recordGroqUsage(userId: uId, tokensUsed: tokens, isRejected: false)
            }

            if resp.success == true, let summary = resp.summary, !summary.isEmpty {
                return summary.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Groq summary generation error: \(error)")
        }

        return nil
    }
}
