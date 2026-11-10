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

public struct SupabaseAppUser: Codable, Sendable, Identifiable {
    public var id: String { userId }
    public let userId: String
    public var externalUserId: String?
    public var username: String?
    public var fullName: String?
    public var email: String?
    public var susuEmail: String?
    public var groupName: String?
    public var specialityName: String?
    public var unitName: String?
    public var educationLevel: String?
    public var educationForm: String?
    public var studyYears: String?
    public var deviceInfo: String?
    public var isBanned: Bool
    public var banReason: String?
    public var canViewMaterials: Bool
    public var isAdmin: Bool
    public var lastActive: String?
    public var appVersion: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case externalUserId = "external_user_id"
        case username
        case fullName = "full_name"
        case email
        case susuEmail = "susu_email"
        case groupName = "group_name"
        case specialityName = "speciality_name"
        case unitName = "unit_name"
        case educationLevel = "education_level"
        case educationForm = "education_form"
        case studyYears = "study_years"
        case deviceInfo = "device_info"
        case isBanned = "is_banned"
        case banReason = "ban_reason"
        case canViewMaterials = "can_view_materials"
        case isAdmin = "is_admin"
        case lastActive = "last_active"
        case appVersion = "app_version"
    }

    public init(
        userId: String,
        externalUserId: String? = nil,
        username: String? = nil,
        fullName: String? = nil,
        email: String? = nil,
        susuEmail: String? = nil,
        groupName: String? = nil,
        specialityName: String? = nil,
        unitName: String? = nil,
        educationLevel: String? = nil,
        educationForm: String? = nil,
        studyYears: String? = nil,
        deviceInfo: String? = nil,
        isBanned: Bool = false,
        banReason: String? = nil,
        canViewMaterials: Bool = true,
        isAdmin: Bool = false,
        lastActive: String? = nil,
        appVersion: String? = nil
    ) {
        self.userId = userId
        self.externalUserId = externalUserId
        self.username = username
        self.fullName = fullName
        self.email = email
        self.susuEmail = susuEmail
        self.groupName = groupName
        self.specialityName = specialityName
        self.unitName = unitName
        self.educationLevel = educationLevel
        self.educationForm = educationForm
        self.studyYears = studyYears
        self.deviceInfo = deviceInfo
        self.isBanned = isBanned
        self.banReason = banReason
        self.canViewMaterials = canViewMaterials
        self.isAdmin = isAdmin
        self.lastActive = lastActive
        self.appVersion = appVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.externalUserId = try container.decodeIfPresent(String.self, forKey: .externalUserId)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.susuEmail = try container.decodeIfPresent(String.self, forKey: .susuEmail)
        self.groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        self.specialityName = try container.decodeIfPresent(String.self, forKey: .specialityName)
        self.unitName = try container.decodeIfPresent(String.self, forKey: .unitName)
        self.educationLevel = try container.decodeIfPresent(String.self, forKey: .educationLevel)
        self.educationForm = try container.decodeIfPresent(String.self, forKey: .educationForm)
        self.studyYears = try container.decodeIfPresent(String.self, forKey: .studyYears)
        self.deviceInfo = try container.decodeIfPresent(String.self, forKey: .deviceInfo)
        self.isBanned = (try? container.decodeIfPresent(Bool.self, forKey: .isBanned)) ?? false
        self.banReason = try container.decodeIfPresent(String.self, forKey: .banReason)
        self.canViewMaterials = (try? container.decodeIfPresent(Bool.self, forKey: .canViewMaterials)) ?? true
        self.isAdmin = (try? container.decodeIfPresent(Bool.self, forKey: .isAdmin)) ?? false
        self.lastActive = try container.decodeIfPresent(String.self, forKey: .lastActive)
        self.appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
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
    public let subjectId: String?
    public let rating: Double
    public let recordedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case term
        case subjectId = "subject_id"
        case rating
        case recordedAt = "recorded_at"
    }

    public init(
        id: String = UUID().uuidString,
        userId: String,
        term: Int,
        subjectId: String? = nil,
        rating: Double,
        recordedAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.userId = userId
        self.term = term
        self.subjectId = subjectId
        self.rating = rating
        self.recordedAt = recordedAt
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

    // MARK: - 2. Rating History (Overall & Per Subject)
    public func loadRatingHistory(userId: String, term: Int, subjectId: String? = nil, from: Date? = nil) async -> [RatingHistoryPoint] {
        guard !userId.isEmpty, term > 0,
              var components = URLComponents(string: "\(url)/rest/v1/rating_history") else { return [] }
        var queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "term", value: "eq.\(term)"),
            URLQueryItem(name: "order", value: "recorded_at.asc"),
            URLQueryItem(name: "select", value: "*")
        ]
        if let sId = subjectId, !sId.isEmpty, UUID(uuidString: sId) != nil {
            queryItems.append(URLQueryItem(name: "subject_id", value: "eq.\(sId)"))
        } else {
            queryItems.append(URLQueryItem(name: "subject_id", value: "is.null"))
        }
        if let from {
            queryItems.append(URLQueryItem(name: "recorded_at", value: "gte.\(ISO8601DateFormatter().string(from: from))"))
        }
        components.queryItems = queryItems
        guard let requestURL = components.url else { return [] }
        return (try? await client.requestJSON(url: requestURL, headers: defaultHeaders())) ?? []
    }

    public func recordRatingPoint(userId: String, term: Int, subjectId: String? = nil, rating: Double) async {
        guard !userId.isEmpty, term > 0, rating.isFinite else { return }
        let rounded = (rating * 100).rounded() / 100
        let history = await loadRatingHistory(userId: userId, term: term, subjectId: subjectId)
        if let last = history.last, abs(last.rating - rounded) < 0.005 { return }
        guard let requestURL = URL(string: "\(url)/rest/v1/rating_history") else { return }

        var item: [String: Any] = [
            "user_id": userId,
            "term": term,
            "rating": rounded,
            "recorded_at": ISO8601DateFormatter().string(from: Date())
        ]
        if let sId = subjectId, UUID(uuidString: sId) != nil {
            item["subject_id"] = sId
        }

        guard let body = try? JSONSerialization.data(withJSONObject: [item]) else { return }
        do {
            _ = try await client.request(url: requestURL, method: "POST", headers: defaultHeaders(prefer: "return=minimal"), body: body)
        } catch {
            print("Rating history write failed: \(error.localizedDescription)")
        }
    }

    public func recordOverallRating(userId: String, term: Int, rating: Double) async {
        await recordRatingPoint(userId: userId, term: term, subjectId: nil, rating: rating)
    }

    // MARK: - 3. Subject & Checkpoints Sync
    public func syncSubjectData(
        subjectId: String,
        subjectName: String,
        teacherName: String?,
        entries: [CheckpointItem]
    ) async -> [SupabaseCheckpoint] {
        guard UUID(uuidString: subjectId) != nil, !subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

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

    // MARK: - 4. Materials
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

    public func getMaterialsForCheckpoint(checkpointId: String, userId: String? = nil) async -> [MaterialItem] {
        guard UUID(uuidString: checkpointId) != nil else {
            return []
        }

        // 1. Попытка через защищённый RPC с проверкой прав пользователя
        if let uId = userId, !uId.isEmpty, let rpcURL = URL(string: "\(url)/rest/v1/rpc/get_accessible_materials") {
            let payload: [String: Any] = [
                "p_user_id": uId,
                "p_checkpoint_id": checkpointId
            ]
            if let body = try? JSONSerialization.data(withJSONObject: payload),
               let list: [MaterialItem] = try? await client.requestJSON(url: rpcURL, method: "POST", headers: defaultHeaders(), body: body) {
                return list.sorted { $0.relevanceScore > $1.relevanceScore }
            }
        }

        // 2. Резервный запрос при ожидании применения миграции v2
        guard let reqUrl = URL(string: "\(url)/rest/v1/materials?checkpoint_id=eq.\(checkpointId)&select=*") else {
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
            if isUpvote { up = max(0, up - 1) } else { down = max(0, down - 1) }
        } else {
            if wasUp { up = max(0, up - 1) }
            if wasDown { down = max(0, down - 1) }
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

    // MARK: - 5. Teacher Reviews & Stats
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

    // MARK: - 6. Teacher Summary
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

    public func getTeacherCard(teacherName: String) async -> TeacherCardData? {
        guard let reqUrl = URL(string: "\(url)/rest/v1/rpc/get_teacher_card") else { return nil }
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: ["p_teacher_name": teacherName])
            let card: TeacherCardData = try await client.requestJSON(
                url: reqUrl,
                method: "POST",
                headers: defaultHeaders(),
                body: bodyData
            )
            return card
        } catch {
            return nil
        }
    }

    // MARK: - 7. User Resolution & Admin RPC
    public func resolveOrRegisterUser(
        externalUserId: String,
        externalIdentity: String? = nil,
        username: String? = nil,
        fullName: String? = nil,
        email: String? = nil,
        susuEmail: String? = nil,
        groupId: String? = nil,
        groupName: String? = nil,
        specialityCode: String? = nil,
        specialityName: String? = nil,
        unitName: String? = nil,
        educationLevel: String? = nil,
        educationForm: String? = nil,
        studyYears: String? = nil,
        appVersion: String? = "2.1.0",
        deviceInfo: String? = "iPhone / iOS Native"
    ) async -> SupabaseAppUser {
        struct ResolveResp: Decodable {
            let user_id: String
            let is_banned: Bool
            let ban_reason: String?
            let can_view_materials: Bool
            let is_admin: Bool
            let full_name: String?
            let group_name: String?
        }

        if let rpcURL = URL(string: "\(url)/rest/v1/rpc/resolve_or_register_user") {
            let payload: [String: Any] = [
                "p_external_user_id": externalUserId,
                "p_external_identity": externalIdentity ?? NSNull(),
                "p_username": username ?? NSNull(),
                "p_full_name": fullName ?? NSNull(),
                "p_email": email ?? NSNull(),
                "p_susu_email": susuEmail ?? NSNull(),
                "p_group_id": groupId ?? NSNull(),
                "p_group_name": groupName ?? NSNull(),
                "p_speciality_code": specialityCode ?? NSNull(),
                "p_speciality_name": specialityName ?? NSNull(),
                "p_unit_name": unitName ?? NSNull(),
                "p_education_level": educationLevel ?? NSNull(),
                "p_education_form": educationForm ?? NSNull(),
                "p_study_years": studyYears ?? NSNull(),
                "p_app_version": appVersion ?? "2.1.0",
                "p_device_info": deviceInfo ?? "iPhone / iOS Native"
            ]

            if let body = try? JSONSerialization.data(withJSONObject: payload),
               let list: [ResolveResp] = try? await client.requestJSON(url: rpcURL, method: "POST", headers: defaultHeaders(), body: body),
               let first = list.first {
                return SupabaseAppUser(
                    userId: first.user_id,
                    externalUserId: externalUserId,
                    username: username,
                    fullName: first.full_name ?? fullName,
                    email: email,
                    susuEmail: susuEmail,
                    groupName: first.group_name ?? groupName,
                    specialityName: specialityName,
                    unitName: unitName,
                    educationLevel: educationLevel,
                    educationForm: educationForm,
                    studyYears: studyYears,
                    deviceInfo: deviceInfo,
                    isBanned: first.is_banned,
                    banReason: first.ban_reason,
                    canViewMaterials: first.can_view_materials,
                    isAdmin: first.is_admin,
                    lastActive: ISO8601DateFormatter().string(from: Date()),
                    appVersion: appVersion
                )
            }
        }

        // Fallback если RPC еще не развернут
        return await getUserProfile(userId: externalUserId)
    }

    public func getUserProfile(userId: String) async -> SupabaseAppUser {
        guard let reqUrl = URL(string: "\(url)/rest/v1/app_users?user_id=eq.\(userId)&select=*") else {
            return SupabaseAppUser(userId: userId, isBanned: false, canViewMaterials: true, isAdmin: false)
        }
        do {
            let users: [SupabaseAppUser] = try await client.requestJSON(url: reqUrl, headers: defaultHeaders())
            if let existing = users.first {
                if let patchUrl = URL(string: "\(url)/rest/v1/app_users?user_id=eq.\(userId)"),
                   let patchData = try? JSONSerialization.data(withJSONObject: ["last_active": ISO8601DateFormatter().string(from: Date())]) {
                    _ = try? await client.request(url: patchUrl, method: "PATCH", headers: defaultHeaders(prefer: "return=minimal"), body: patchData)
                }
                return existing
            }

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

    // MARK: - 8. Admin Methods & Security Verification
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

    public func adminSetUserStatus(
        adminUserId: String,
        targetUserId: String,
        isBanned: Bool? = nil,
        banReason: String? = nil,
        canViewMaterials: Bool? = nil
    ) async throws -> Bool {
        if let rpcURL = URL(string: "\(url)/rest/v1/rpc/admin_set_user_status") {
            var payload: [String: Any] = [
                "p_admin_user_id": adminUserId,
                "p_target_user_id": targetUserId
            ]
            if let b = isBanned { payload["p_is_banned"] = b }
            if let r = banReason { payload["p_ban_reason"] = r }
            if let m = canViewMaterials { payload["p_can_view_materials"] = m }

            if let body = try? JSONSerialization.data(withJSONObject: payload),
               let res: Bool = try? await client.requestJSON(url: rpcURL, method: "POST", headers: defaultHeaders(), body: body) {
                return res
            }
        }

        // Fallback: direct PATCH if RPC not yet deployed
        var updates: [String: Any] = [:]
        if let b = isBanned {
            updates["is_banned"] = b
            updates["ban_reason"] = b ? (banReason ?? "Заблокирован администратором") : NSNull()
        }
        if let m = canViewMaterials {
            updates["can_view_materials"] = m
        }
        guard !updates.isEmpty, let patchUrl = URL(string: "\(url)/rest/v1/app_users?user_id=eq.\(targetUserId)") else { return false }
        let body = try JSONSerialization.data(withJSONObject: updates)
        _ = try await client.request(url: patchUrl, method: "PATCH", headers: defaultHeaders(prefer: "return=representation"), body: body)
        return true
    }

    public func updateUser(userId: String, updates: [String: Any]) async throws {
        guard let reqUrl = URL(string: "\(url)/rest/v1/app_users?user_id=eq.\(userId)") else { return }
        let body = try JSONSerialization.data(withJSONObject: updates)
        _ = try await client.request(url: reqUrl, method: "PATCH", headers: defaultHeaders(prefer: "return=representation"), body: body)
    }
}
