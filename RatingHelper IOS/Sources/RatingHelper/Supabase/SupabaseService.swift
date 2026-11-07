import Foundation

public struct SupabaseCheckpoint: Identifiable, Codable, Sendable {
    public let id: String
    public let subjectId: String
    public let title: String
    public let maxScore: Double
    public let weight: Double

    enum CodingKeys: String, CodingKey {
        case id
        case subjectId = "subject_id"
        case title
        case maxScore = "max_score"
        case weight
    }
}

public struct SupabaseAppUser: Codable, Sendable {
    public let userId: String
    public var deviceInfo: String?
    public var isBanned: Bool
    public var canViewMaterials: Bool
    public var isAdmin: Bool
    public var lastActive: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceInfo = "device_info"
        case isBanned = "is_banned"
        case canViewMaterials = "can_view_materials"
        case isAdmin = "is_admin"
        case lastActive = "last_active"
    }

    public init(
        userId: String,
        deviceInfo: String? = nil,
        isBanned: Bool = false,
        canViewMaterials: Bool = true,
        isAdmin: Bool = false,
        lastActive: String? = nil
    ) {
        self.userId = userId
        self.deviceInfo = deviceInfo
        self.isBanned = isBanned
        self.canViewMaterials = canViewMaterials
        self.isAdmin = isAdmin
        self.lastActive = lastActive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.deviceInfo = try container.decodeIfPresent(String.self, forKey: .deviceInfo)
        self.isBanned = (try? container.decodeIfPresent(Bool.self, forKey: .isBanned)) ?? false
        self.canViewMaterials = (try? container.decodeIfPresent(Bool.self, forKey: .canViewMaterials)) ?? true
        self.isAdmin = (try? container.decodeIfPresent(Bool.self, forKey: .isAdmin)) ?? false
        self.lastActive = try container.decodeIfPresent(String.self, forKey: .lastActive)
    }
}

public struct AppConfigItem: Codable, Sendable {
    public let key: String
    public let value: String
}

public struct RatingHistoryPoint: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let userId: String
    public let term: Int
    public let rating: Double
    public let recordedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case term
        case rating
        case recordedAt = "recorded_at"
    }
}

public actor SupabaseService {
    public static let shared = SupabaseService()

    private let url = APIEndpoints.supabaseURL
    private let key = APIEndpoints.supabaseKey
    private let client = HTTPClient.shared

    private init() {}

    private func defaultHeaders(prefer: String? = nil) -> [String: String] {
        var h = [
            "apikey": key,
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json"
        ]
        if let p = prefer {
            h["Prefer"] = p
        }
        return h
    }

    // MARK: - 1. Config
    public func getConfig(key: String) async -> String? {
        guard let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let reqUrl = URL(string: "\(url)/rest/v1/app_config?key=eq.\(encoded)&select=value") else {
            return nil
        }
        do {
            let items: [AppConfigItem] = try await client.requestJSON(url: reqUrl, headers: defaultHeaders())
            return items.first?.value
        } catch {
            print("Supabase app_config read failed for key '\(key)': \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Rating history
    public func loadRatingHistory(userId: String, term: Int, from: Date? = nil) async -> [RatingHistoryPoint] {
        guard !userId.isEmpty, term > 0,
              var components = URLComponents(string: "\(url)/rest/v1/rating_history") else { return [] }
        var queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "term", value: "eq.\(term)"),
            URLQueryItem(name: "order", value: "recorded_at.asc"),
            URLQueryItem(name: "select", value: "*")
        ]
        if let from {
            queryItems.append(URLQueryItem(name: "recorded_at", value: "gte.\(ISO8601DateFormatter().string(from: from))"))
        }
        components.queryItems = queryItems
        guard let requestURL = components.url else { return [] }
        return (try? await client.requestJSON(url: requestURL, headers: defaultHeaders())) ?? []
    }

    public func recordOverallRating(userId: String, term: Int, rating: Double) async {
        guard !userId.isEmpty, term > 0, rating.isFinite else { return }
        let rounded = (rating * 100).rounded() / 100
        let history = await loadRatingHistory(userId: userId, term: term)
        if let last = history.last, abs(last.rating - rounded) < 0.005 { return }
        guard let requestURL = URL(string: "\(url)/rest/v1/rating_history") else { return }
        let payload: [[String: Any]] = [[
            "user_id": userId,
            "term": term,
            "rating": rounded,
            "recorded_at": ISO8601DateFormatter().string(from: Date())
        ]]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        do {
            _ = try await client.request(url: requestURL, method: "POST", headers: defaultHeaders(prefer: "return=minimal"), body: body)
        } catch {
            print("Rating history write failed: \(error.localizedDescription)")
        }
    }

    // MARK: - 2. Subject & Checkpoints Sync
    public func syncSubjectData(
        subjectId: String,
        subjectName: String,
        teacherName: String?,
        entries: [CheckpointItem]
    ) async -> [SupabaseCheckpoint] {
        guard UUID(uuidString: subjectId) != nil, !subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        // Metadata is written through one narrowly scoped SECURITY DEFINER RPC.
        // Direct REST upserts under the publishable key are rejected by RLS and
        // were the source of the repeated 42501/401 errors in the logs.
        guard let rpcURL = URL(string: "\(url)/rest/v1/rpc/sync_subject_metadata") else {
            return await getCheckpoints(subjectId: subjectId)
        }
        let rows = entries.map { ["title": $0.title, "max_score": $0.max, "weight": $0.weight] as [String: Any] }
        let payload: [String: Any] = [
            "p_subject_id": subjectId,
            "p_subject_name": subjectName,
            "p_teacher_name": teacherName ?? NSNull(),
            "p_checkpoints": rows
        ]
        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            return try await client.requestJSON(
                url: rpcURL,
                method: "POST",
                headers: defaultHeaders(),
                body: body
            )
        } catch {
            // Keep the journal usable when the migration has not been deployed,
            // but leave a precise diagnostic instead of hiding the failure.
            print("Supabase metadata sync failed (RPC sync_subject_metadata): \(error.localizedDescription)")
            return await getCheckpoints(subjectId: subjectId)
        }
    }

    public func getCheckpoints(subjectId: String) async -> [SupabaseCheckpoint] {
        guard let reqUrl = URL(string: "\(url)/rest/v1/checkpoints?subject_id=eq.\(subjectId)&select=*") else {
            return []
        }
        do {
            return try await client.requestJSON(url: reqUrl, headers: defaultHeaders())
        } catch {
            return []
        }
    }

    // MARK: - 3. Materials
    public func getMaterialsCountForSubject(subjectId: String) async -> [String: Int] {
        struct Item: Decodable {
            let checkpoint_id: String?
        }
        guard UUID(uuidString: subjectId) != nil,
              let reqUrl = URL(string: "\(url)/rest/v1/materials?subject_id=eq.\(subjectId)&select=checkpoint_id") else {
            return [:]
        }
        do {
            let items: [Item] = try await client.requestJSON(url: reqUrl, headers: defaultHeaders())
            var map: [String: Int] = [:]
            for it in items {
                if let cpId = it.checkpoint_id {
                    map[cpId, default: 0] += 1
                }
            }
            return map
        } catch {
            return [:]
        }
    }

    public func getMaterialsForCheckpoint(checkpointId: String) async -> [MaterialItem] {
        guard UUID(uuidString: checkpointId) != nil,
              let reqUrl = URL(string: "\(url)/rest/v1/materials?checkpoint_id=eq.\(checkpointId)&select=*") else {
            print("Supabase materials read skipped: checkpoint id is not a UUID")
            return []
        }
        do {
            let list: [MaterialItem] = try await client.requestJSON(url: reqUrl, headers: defaultHeaders())
            return list.sorted { $0.relevanceScore > $1.relevanceScore }
        } catch {
            return []
        }
    }

    public func addMaterialRecord(
        checkpointId: String,
        subjectId: String,
        teacherName: String?,
        title: String,
        fileUrl: String,
        fileName: String,
        year: Int
    ) async throws -> MaterialItem {
        guard UUID(uuidString: checkpointId) != nil else {
            throw NetworkError.invalidURL("Контрольная точка ещё не синхронизирована с базой данных")
        }
        guard UUID(uuidString: subjectId) != nil else {
            throw NetworkError.invalidURL("Дисциплина имеет некорректный идентификатор")
        }
        guard let reqUrl = URL(string: "\(url)/rest/v1/materials") else {
            throw NetworkError.invalidURL("\(url)/rest/v1/materials")
        }

        var newMat: [String: Any] = [
            "title": title,
            "file_url": fileUrl,
            "file_name": fileName,
            "year": year,
            "upvotes": 1,
            "downvotes": 0
        ]

        newMat["checkpoint_id"] = checkpointId
        newMat["subject_id"] = subjectId
        if let tn = teacherName, !tn.isEmpty {
            newMat["teacher_name"] = tn
        }

        let bodyData = try JSONSerialization.data(withJSONObject: [newMat])
        let items: [MaterialItem] = try await client.requestJSON(
            url: reqUrl,
            method: "POST",
            headers: defaultHeaders(prefer: "return=representation"),
            body: bodyData
        )
        guard let first = items.first else {
            throw NetworkError.decodingError("Не получен ответ после сохранения материала")
        }
        return first
    }

    public func voteMaterial(materialId: String, isUpvote: Bool, previousVote: String?) async throws -> (up: Int, down: Int) {
        struct VoteData: Decodable {
            let upvotes: Int?
            let downvotes: Int?
        }
        guard let fetchUrl = URL(string: "\(url)/rest/v1/materials?id=eq.\(materialId)&select=upvotes,downvotes") else {
            return (0, 0)
        }
        let cur: [VoteData] = try await client.requestJSON(url: fetchUrl, headers: defaultHeaders())
        guard let first = cur.first else { return (0, 0) }

        var up = first.upvotes ?? 0
        var down = first.downvotes ?? 0

        let wasUp = previousVote == "up"
        let wasDown = previousVote == "down"

        if (isUpvote && wasUp) || (!isUpvote && wasDown) {
            // Отмена текущего голоса
            if isUpvote { up = max(0, up - 1) } else { down = max(0, down - 1) }
        } else {
            // Откат противоположного голоса
            if wasUp { up = max(0, up - 1) }
            if wasDown { down = max(0, down - 1) }

            // Применение нового
            if isUpvote { up += 1 } else { down += 1 }
        }

        guard let patchUrl = URL(string: "\(url)/rest/v1/materials?id=eq.\(materialId)") else {
            return (up, down)
        }
        let patchData = try JSONSerialization.data(withJSONObject: ["upvotes": up, "downvotes": down])
        _ = try await client.request(
            url: patchUrl,
            method: "PATCH",
            headers: defaultHeaders(prefer: "return=minimal"),
            body: patchData
        )
        return (up, down)
    }

    // MARK: - 4. Teacher Reviews & Stats
    public func getTeacherReviews(teacherName: String) async -> ([TeacherReview], TeacherStats?) {
        guard let encoded = teacherName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let reqUrl = URL(string: "\(url)/rest/v1/teacher_reviews?teacher_name=eq.\(encoded)&order=created_at.desc") else {
            return ([], nil)
        }
        do {
            let reviews: [TeacherReview] = try await client.requestJSON(url: reqUrl, headers: defaultHeaders())
            let stats = TeacherStats.compute(from: reviews)
            return (reviews, stats)
        } catch {
            return ([], nil)
        }
    }

    public func addTeacherReview(review: TeacherReview) async throws -> TeacherReview {
        guard let reqUrl = URL(string: "\(url)/rest/v1/teacher_reviews") else {
            throw NetworkError.invalidURL("\(url)/rest/v1/teacher_reviews")
        }

        var dict: [String: Any] = [
            "id": review.id,
            "teacher_name": review.teacherName,
            "subject_name": review.subjectName ?? "",
            "text": review.text,
            "difficulty": review.difficulty,
            "gives_avtomat": review.givesAvtomat,
            "attendance_strict": review.attendanceStrict,
            "year": review.year,
            "likes": 0,
            "dislikes": 0
        ]

        // КРИТИЧЕСКИЙ ФИКС: subject_id в базе данных PostgreSQL является типом UUID.
        // Передача пустой строки "" приводит к ошибке: invalid input syntax for type uuid: ""
        // Если subjectId не является валидным UUID, не передаем его вообще (PostgreSQL запишет NULL).
        if let sId = review.subjectId, !sId.isEmpty, UUID(uuidString: sId) != nil {
            dict["subject_id"] = sId
        }

        let bodyData = try JSONSerialization.data(withJSONObject: [dict])
        let items: [TeacherReview] = try await client.requestJSON(
            url: reqUrl,
            method: "POST",
            headers: defaultHeaders(prefer: "return=representation,resolution=ignore-duplicates"),
            body: bodyData
        )
        if let first = items.first {
            return first
        }

        // `resolution=ignore-duplicates` makes a retry safe. If the first
        // request committed and the response was lost, return the existing row
        // instead of telling the user that publication failed.
        guard let existingURL = URL(string: "\(url)/rest/v1/teacher_reviews?id=eq.\(review.id)&select=*") else {
            throw NetworkError.decodingError("Не удалось подтвердить сохранение отзыва")
        }
        let existing: [TeacherReview] = try await client.requestJSON(url: existingURL, headers: defaultHeaders())
        guard let first = existing.first else {
            throw NetworkError.decodingError("Не удалось сохранить отзыв в базе данных")
        }
        return first
    }

    public func voteReview(reviewId: String, isUpvote: Bool, previousVote: String?) async throws -> (likes: Int, dislikes: Int) {
        struct ReviewVoteData: Decodable {
            let likes: Int?
            let dislikes: Int?
        }
        guard let fetchUrl = URL(string: "\(url)/rest/v1/teacher_reviews?id=eq.\(reviewId)&select=likes,dislikes") else {
            return (0, 0)
        }
        let cur: [ReviewVoteData] = try await client.requestJSON(url: fetchUrl, headers: defaultHeaders())
        guard let first = cur.first else { return (0, 0) }

        var likes = first.likes ?? 0
        var dislikes = first.dislikes ?? 0

        let wasUp = previousVote == "up"
        let wasDown = previousVote == "down"

        if (isUpvote && wasUp) || (!isUpvote && wasDown) {
            if isUpvote { likes = max(0, likes - 1) } else { dislikes = max(0, dislikes - 1) }
        } else {
            if wasUp { likes = max(0, likes - 1) }
            if wasDown { dislikes = max(0, dislikes - 1) }

            if isUpvote { likes += 1 } else { dislikes += 1 }
        }

        guard let patchUrl = URL(string: "\(url)/rest/v1/teacher_reviews?id=eq.\(reviewId)") else {
            return (likes, dislikes)
        }
        let patchData = try JSONSerialization.data(withJSONObject: ["likes": likes, "dislikes": dislikes])
        _ = try await client.request(
            url: patchUrl,
            method: "PATCH",
            headers: defaultHeaders(prefer: "return=minimal"),
            body: patchData
        )
        return (likes, dislikes)
    }

    // MARK: - 5. Teacher Summary
    public func getTeacherSummary(teacherName: String) async -> TeacherSummary? {
        guard let encoded = teacherName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let reqUrl = URL(string: "\(url)/rest/v1/teacher_summaries?teacher_name=eq.\(encoded)&select=*") else {
            return nil
        }
        do {
            let items: [TeacherSummary] = try await client.requestJSON(url: reqUrl, headers: defaultHeaders())
            return items.first
        } catch {
            return nil
        }
    }

    public func saveTeacherSummary(teacherName: String, summaryText: String, count: Int) async {
        guard let reqUrl = URL(string: "\(url)/rest/v1/teacher_summaries?on_conflict=teacher_name") else { return }
        let dict: [[String: Any]] = [[
            "teacher_name": teacherName,
            "summary_text": summaryText,
            "reviews_count": count,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]]
        if let bodyData = try? JSONSerialization.data(withJSONObject: dict) {
            _ = try? await client.request(
                url: reqUrl,
                method: "POST",
                headers: defaultHeaders(prefer: "resolution=merge-duplicates"),
                body: bodyData
            )
        }
    }

    // MARK: - 6. User Profile & Admin RPC
    public func getUserProfile(userId: String) async -> SupabaseAppUser {
        guard let reqUrl = URL(string: "\(url)/rest/v1/app_users?user_id=eq.\(userId)&select=*") else {
            return SupabaseAppUser(userId: userId, isBanned: false, canViewMaterials: true, isAdmin: false)
        }
        do {
            let users: [SupabaseAppUser] = try await client.requestJSON(url: reqUrl, headers: defaultHeaders())
            if let existing = users.first {
                // Обновляем last_active
                if let patchUrl = URL(string: "\(url)/rest/v1/app_users?user_id=eq.\(userId)"),
                   let patchData = try? JSONSerialization.data(withJSONObject: ["last_active": ISO8601DateFormatter().string(from: Date())]) {
                    _ = try? await client.request(url: patchUrl, method: "PATCH", headers: defaultHeaders(prefer: "return=minimal"), body: patchData)
                }
                return existing
            }

            // Регистрируем нового пользователя (без передачи is_admin, чтобы избежать падения, если колонка еще не создана миграцией)
            let newUser = SupabaseAppUser(
                userId: userId,
                deviceInfo: "iOS Native App",
                isBanned: false,
                canViewMaterials: true,
                isAdmin: false,
                lastActive: ISO8601DateFormatter().string(from: Date())
            )
            if let postUrl = URL(string: "\(url)/rest/v1/app_users?on_conflict=user_id"),
               let postData = try? JSONSerialization.data(withJSONObject: [[
                   "user_id": userId,
                   "device_info": "iOS Native App",
                   "is_banned": false,
                   "can_view_materials": true,
                   "created_at": ISO8601DateFormatter().string(from: Date()),
                   "last_active": ISO8601DateFormatter().string(from: Date())
               ]]) {
                _ = try? await client.request(url: postUrl, method: "POST", headers: defaultHeaders(prefer: "resolution=merge-duplicates"), body: postData)
            }
            return newUser
        } catch {
            return SupabaseAppUser(userId: userId, isBanned: false, canViewMaterials: true, isAdmin: false)
        }
    }

    public func verifyAdminPin(pin: String) async -> Bool {
        guard let reqUrl = URL(string: "\(url)/rest/v1/rpc/verify_admin_pin") else { return false }
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: ["p_pin": pin])
            let result: Bool = try await client.requestJSON(
                url: reqUrl,
                method: "POST",
                headers: defaultHeaders(),
                body: bodyData
            )
            return result
        } catch {
            return false
        }
    }

    // MARK: - 7. Admin Methods
    public func getAllUsers() async -> [SupabaseAppUser] {
        guard let reqUrl = URL(string: "\(url)/rest/v1/app_users?order=last_active.desc") else { return [] }
        return (try? await client.requestJSON(url: reqUrl, headers: defaultHeaders())) ?? []
    }

    public func getAllReviews() async -> [TeacherReview] {
        guard let reqUrl = URL(string: "\(url)/rest/v1/teacher_reviews?order=created_at.desc") else { return [] }
        return (try? await client.requestJSON(url: reqUrl, headers: defaultHeaders())) ?? []
    }

    public func getAllMaterials() async -> [MaterialItem] {
        guard let reqUrl = URL(string: "\(url)/rest/v1/materials?order=created_at.desc") else { return [] }
        return (try? await client.requestJSON(url: reqUrl, headers: defaultHeaders())) ?? []
    }

    public func deleteReview(id: String) async throws {
        guard let reqUrl = URL(string: "\(url)/rest/v1/teacher_reviews?id=eq.\(id)") else { return }
        _ = try await client.request(url: reqUrl, method: "DELETE", headers: defaultHeaders(prefer: "return=representation"))
    }

    public func deleteMaterial(id: String) async throws {
        guard let reqUrl = URL(string: "\(url)/rest/v1/materials?id=eq.\(id)") else { return }
        _ = try await client.request(url: reqUrl, method: "DELETE", headers: defaultHeaders(prefer: "return=representation"))
    }

    public func updateUser(userId: String, updates: [String: Any]) async throws {
        guard let reqUrl = URL(string: "\(url)/rest/v1/app_users?user_id=eq.\(userId)") else { return }
        let body = try JSONSerialization.data(withJSONObject: updates)
        _ = try await client.request(url: reqUrl, method: "PATCH", headers: defaultHeaders(prefer: "return=representation"), body: body)
    }
}
