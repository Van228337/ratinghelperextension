import Foundation

public struct ServerModerationResponse: Codable, Sendable {
    public let success: Bool?
    public let allowed: Bool?
    public let reason: String?
    public let status: String?
    public let error: String?
}

public struct ServerSummaryResponse: Codable, Sendable {
    public let success: Bool?
    public let summary: String?
    public let error: String?
}

public actor GroqModerationService {
    public static let shared = GroqModerationService()

    private let supabase = SupabaseService.shared
    private let client = HTTPClient.shared
    private var cachedScriptUrl: String?

    private init() {}

    private func getGatewayUrl() async -> String? {
        if let cached = cachedScriptUrl, !cached.isEmpty {
            return cached
        }

        // Keep the existing configuration key for compatibility, but do not
        // make moderation depend on a successful config read. The endpoint is
        // public; only the Groq key remains server-side in Apps Script.
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

    public func moderateReview(text: String) async -> ModerationCheckResult {
        // Уровень 1: Локальный пре-фильтр (структура, символы, базовые корни)
        let localCheck = TextPreFilter.preFilter(text)
        guard localCheck.allowed else {
            return localCheck
        }

        // Уровень 2 и 3: Серверный шлюз (нормализация NFKC + омоглифы + Groq AI)
        guard let gatewayUrlStr = await getGatewayUrl(), let url = URL(string: gatewayUrlStr) else {
            return ModerationCheckResult(
                allowed: false,
                reason: "Серверный адрес шлюза модерации недоступен. Проверьте подключение к базе данных."
            )
        }

        let payload: [String: Any] = [
            "action": "moderateReview",
            "text": text.trimmingCharacters(in: .whitespacesAndNewlines)
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
            // КРИТИЧЕСКИЙ ФИКС: НЕ пропускать отзыв, если обязательная серверная AI-модерация завершилась сбоем!
            return ModerationCheckResult(
                allowed: false,
                reason: "Не удалось выполнить проверку нейросетью: \(error.localizedDescription). Публикация без проверки запрещена."
            )
        }
    }

    public func generateTeacherSummary(teacherName: String, reviews: [TeacherReview]) async -> String? {
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
            if resp.success == true, let summary = resp.summary, !summary.isEmpty {
                return summary.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Groq summary generation error: \(error)")
        }

        return nil
    }
}
