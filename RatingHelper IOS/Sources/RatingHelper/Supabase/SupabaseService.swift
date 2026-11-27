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
    public var groupName: String?
    public var groupId: String?
    public var deviceInfo: String?
    public var canUploadFiles: Bool
    public var canViewMaterials: Bool
    public var canPublishReviews: Bool
    public var reviewEditCooldownSeconds: Int
    public var sanctionReason: String?
    public var sanctionExpiresAt: String?
    public var isAdmin: Bool
    public var createdAt: String?
    public var lastActive: String?
    public var appVersion: String?
    public var uploadCount: Int
    public var uploadedBytes: Int64
    public var materialsViewsCount: Int
    public var reviewsCount: Int
    public var reviewsEditCount: Int
    public var groqModerationCalls: Int
    public var groqTokensUsed: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case externalUserId = "external_user_id"
        case username
        case groupName = "group_name"
        case groupId = "group_id"
        case deviceInfo = "device_info"
        case canUploadFiles = "can_upload_files"
        case canViewMaterials = "can_view_materials"
        case canPublishReviews = "can_publish_reviews"
        case reviewEditCooldownSeconds = "review_edit_cooldown_seconds"
        case sanctionReason = "sanction_reason"
        case sanctionExpiresAt = "sanction_expires_at"
        case isAdmin = "is_admin"
        case createdAt = "created_at"
        case lastActive = "last_active"
        case appVersion = "app_version"
        case uploadCount = "upload_count"
        case uploadedBytes = "uploaded_bytes"
        case materialsViewsCount = "materials_views_count"
        case reviewsCount = "reviews_count"
        case reviewsEditCount = "reviews_edit_count"
        case groqModerationCalls = "groq_moderation_calls"
        case groqTokensUsed = "groq_tokens_used"
    }

    public init(
        userId: String,
        externalUserId: String? = nil,
        username: String? = nil,
        groupName: String? = nil,
        groupId: String? = nil,
        deviceInfo: String? = nil,
        canUploadFiles: Bool = true,
        canViewMaterials: Bool = true,
        canPublishReviews: Bool = true,
        reviewEditCooldownSeconds: Int = 60,
        sanctionReason: String? = nil,
        sanctionExpiresAt: String? = nil,
        isAdmin: Bool = false,
        createdAt: String? = nil,
        lastActive: String? = nil,
        appVersion: String? = nil,
        uploadCount: Int = 0,
        uploadedBytes: Int64 = 0,
        materialsViewsCount: Int = 0,
        reviewsCount: Int = 0,
        reviewsEditCount: Int = 0,
        groqModerationCalls: Int = 0,
        groqTokensUsed: Int = 0
    ) {
        self.userId = userId
        self.externalUserId = externalUserId
        self.username = username
        self.groupName = groupName
        self.groupId = groupId
        self.deviceInfo = deviceInfo
        self.canUploadFiles = canUploadFiles
        self.canViewMaterials = canViewMaterials
        self.canPublishReviews = canPublishReviews
        self.reviewEditCooldownSeconds = reviewEditCooldownSeconds
        self.sanctionReason = sanctionReason
        self.sanctionExpiresAt = sanctionExpiresAt
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.lastActive = lastActive
        self.appVersion = appVersion
        self.uploadCount = uploadCount
        self.uploadedBytes = uploadedBytes
        self.materialsViewsCount = materialsViewsCount
        self.reviewsCount = reviewsCount
        self.reviewsEditCount = reviewsEditCount
        self.groqModerationCalls = groqModerationCalls
        self.groqTokensUsed = groqTokensUsed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try c.decode(String.self, forKey: .userId)
        self.externalUserId = try? c.decodeIfPresent(String.self, forKey: .externalUserId)
        self.username = try? c.decodeIfPresent(String.self, forKey: .username)
        self.groupName = try? c.decodeIfPresent(String.self, forKey: .groupName)
        self.groupId = try? c.decodeIfPresent(String.self, forKey: .groupId)
        self.deviceInfo = try? c.decodeIfPresent(String.self, forKey: .deviceInfo)
        self.canUploadFiles = (try? c.decodeIfPresent(Bool.self, forKey: .canUploadFiles)) ?? true
        self.canViewMaterials = (try? c.decodeIfPresent(Bool.self, forKey: .canViewMaterials)) ?? true
        self.canPublishReviews = (try? c.decodeIfPresent(Bool.self, forKey: .canPublishReviews)) ?? true
        self.reviewEditCooldownSeconds = (try? c.decodeIfPresent(Int.self, forKey: .reviewEditCooldownSeconds)) ?? 60
        self.sanctionReason = try? c.decodeIfPresent(String.self, forKey: .sanctionReason)
        self.sanctionExpiresAt = try? c.decodeIfPresent(String.self, forKey: .sanctionExpiresAt)
        self.isAdmin = (try? c.decodeIfPresent(Bool.self, forKey: .isAdmin)) ?? false
        self.createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        self.lastActive = try? c.decodeIfPresent(String.self, forKey: .lastActive)
        self.appVersion = try? c.decodeIfPresent(String.self, forKey: .appVersion)
        self.uploadCount = (try? c.decodeIfPresent(Int.self, forKey: .uploadCount)) ?? 0
        self.uploadedBytes = (try? c.decodeIfPresent(Int64.self, forKey: .uploadedBytes)) ?? 0
        self.materialsViewsCount = (try? c.decodeIfPresent(Int.self, forKey: .materialsViewsCount)) ?? 0
        self.reviewsCount = (try? c.decodeIfPresent(Int.self, forKey: .reviewsCount)) ?? 0
        self.reviewsEditCount = (try? c.decodeIfPresent(Int.self, forKey: .reviewsEditCount)) ?? 0
        self.groqModerationCalls = (try? c.decodeIfPresent(Int.self, forKey: .groqModerationCalls)) ?? 0
        self.groqTokensUsed = (try? c.decodeIfPresent(Int.self, forKey: .groqTokensUsed)) ?? 0
    }
}

public struct AdminAuditLogItem: Codable, Sendable, Identifiable {
    public let id: String
    public let adminUserId: String
    public let targetUserId: String?
    public let action: String
    public let reason: String?
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case adminUserId = "admin_user_id"
        case targetUserId = "target_user_id"
        case action
        case reason
        case createdAt = "created_at"
    }

    public init(
        id: String = UUID().uuidString,
        adminUserId: String,
        targetUserId: String? = nil,
        action: String,
        reason: String? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.adminUserId = adminUserId
        self.targetUserId = targetUserId
        self.action = action
        self.reason = reason
        self.createdAt = createdAt
    }
}

public struct AdminInfrastructureStats: Codable, Sendable {
    public let totalUsers: Int
    public let activeUsers24h: Int
    public let totalMaterials: Int
    public let totalStorageBytes: Int64
    public let totalReviews: Int
    public let totalGroqCalls: Int
    public let totalGroqTokens: Int
    public let sanctionedUsers: Int

    enum CodingKeys: String, CodingKey {
        case totalUsers = "total_users"
        case activeUsers24h = "active_users_24h"
        case totalMaterials = "total_materials"
        case totalStorageBytes = "total_storage_bytes"
        case totalReviews = "total_reviews"
        case totalGroqCalls = "total_groq_calls"
        case totalGroqTokens = "total_groq_tokens"
        case sanctionedUsers = "sanctioned_users"
    }
}

public struct AdminDashboardData: Codable, Sendable {
    public let users: [SupabaseAppUser]
    public let auditLogs: [AdminAuditLogItem]
    public let stats: AdminInfrastructureStats

    enum CodingKeys: String, CodingKey {
        case users
        case auditLogs = "audit_logs"
        case stats
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
        if let sId = subjectId, !sId.isEmpty {
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
        if let sId = subjectId, !sId.isEmpty {
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
        year: Int,
        userId: String? = nil,
        fileSizeBytes: Int64 = 0,
        fileSha256: String? = nil,
        driveFileId: String? = nil
    ) async throws -> MaterialItem {
        guard UUID(uuidString: checkpointId) != nil else {
            throw NetworkError.invalidURL("Контрольная точка ещё не синхронизирована с базой данных")
        }
        guard UUID(uuidString: subjectId) != nil else {
            throw NetworkError.invalidURL("Дисциплина имеет некорректный идентификатор")
        }

        // 1. Попытка через защищённый RPC register_uploaded_material
        if let uId = userId, !uId.isEmpty, let rpcURL = URL(string: "\(url)/rest/v1/rpc/register_uploaded_material") {
            struct RegisterResp: Decodable {
                let success: Bool
                let id: String?
                let error: String?
            }

            let payload: [String: Any] = [
                "p_user_id": uId,
                "p_checkpoint_id": checkpointId,
                "p_subject_id": subjectId,
                "p_teacher_name": teacherName ?? NSNull(),
                "p_title": title,
                "p_file_url": fileUrl,
                "p_file_name": fileName,
                "p_file_size_bytes": fileSizeBytes,
                "p_file_sha256": fileSha256 ?? NSNull(),
                "p_year": year
            ]

            if let bodyData = try? JSONSerialization.data(withJSONObject: payload) {
                let resp: RegisterResp = try await client.requestJSON(url: rpcURL, method: "POST", headers: defaultHeaders(), body: bodyData)
                if !resp.success {
                    throw NetworkError.serverError(403, resp.error ?? "Загрузка файла отклонена сервером")
                }
                return MaterialItem(
                    id: resp.id ?? UUID().uuidString,
                    checkpointId: checkpointId,
                    subjectId: subjectId,
                    teacherName: teacherName,
                    title: title,
                    fileUrl: fileUrl,
                    fileName: fileName,
                    year: year,
                    upvotes: 1,
                    downvotes: 0,
                    userId: uId,
                    fileSizeBytes: fileSizeBytes,
                    fileSha256: fileSha256,
                    driveFileId: driveFileId
                )
            }
        }

        // 2. Резервный прямой REST запрос
        guard let reqUrl = URL(string: "\(url)/rest/v1/materials") else {
            throw NetworkError.invalidURL("\(url)/rest/v1/materials")
        }

        var newMat: [String: Any] = [
            "title": title,
            "file_url": fileUrl,
            "file_name": fileName,
            "year": year,
            "upvotes": 1,
            "downvotes": 0,
            "checkpoint_id": checkpointId,
            "subject_id": subjectId
        ]
        if let tn = teacherName, !tn.isEmpty { newMat["teacher_name"] = tn }
        if let u = userId, !u.isEmpty { newMat["user_id"] = u }
        if fileSizeBytes > 0 { newMat["file_size_bytes"] = fileSizeBytes }
        if let sha = fileSha256, !sha.isEmpty { newMat["file_sha256"] = sha }
        if let df = driveFileId, !df.isEmpty { newMat["drive_file_id"] = df }

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
        let cleanName = teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return ([], nil) }

        let surname = cleanName.split(separator: " ").first.map(String.init) ?? cleanName
        let surnameQuery = "\(surname)*"

        // 1. Поиск по фамилии через ilike (находит и полную форму, и сокращение с инициалами)
        var reviews: [TeacherReview] = []
        if let encoded = surnameQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let reqUrl = URL(string: "\(url)/rest/v1/teacher_reviews?teacher_name=ilike.\(encoded)&order=created_at.desc") {
            if let fetched: [TeacherReview] = try? await client.requestJSON(url: reqUrl, headers: defaultHeaders()) {
                reviews = fetched
            }
        }

        // 2. Fallback на точное совпадение
        if reviews.isEmpty {
            if let encodedExact = cleanName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let reqUrl = URL(string: "\(url)/rest/v1/teacher_reviews?teacher_name=eq.\(encodedExact)&order=created_at.desc") {
                if let fetched: [TeacherReview] = try? await client.requestJSON(url: reqUrl, headers: defaultHeaders()) {
                    reviews = fetched
                }
            }
        }

        let stats = TeacherStats.compute(from: reviews)
        return (reviews, stats)
    }

    public func addTeacherReview(review: TeacherReview, userId: String? = nil) async throws -> TeacherReview {
        let effectiveUid = userId ?? review.userId ?? ""

        // 1. Защищённый RPC publish_teacher_review (контроль 1 отзыв на предмет, cooldown, can_publish_reviews)
        if !effectiveUid.isEmpty, let sId = review.subjectId, UUID(uuidString: sId) != nil,
           let rpcURL = URL(string: "\(url)/rest/v1/rpc/publish_teacher_review") {
            struct PublishResp: Decodable {
                let success: Bool
                let action: String?
                let id: String?
                let edit_count: Int?
                let error: String?
            }

            let payload: [String: Any] = [
                "p_user_id": effectiveUid,
                "p_teacher_name": review.teacherName,
                "p_subject_id": sId,
                "p_subject_name": review.subjectName ?? "",
                "p_text": review.text,
                "p_difficulty": review.difficulty,
                "p_gives_avtomat": review.givesAvtomat,
                "p_attendance_strict": review.attendanceStrict,
                "p_year": review.year
            ]

            let bodyData = try JSONSerialization.data(withJSONObject: payload)
            let resp: PublishResp = try await client.requestJSON(url: rpcURL, method: "POST", headers: defaultHeaders(), body: bodyData)
            if !resp.success {
                throw NetworkError.serverError(400, resp.error ?? "Не удалось опубликовать отзыв")
            }

            var resultReview = review
            resultReview.userId = effectiveUid
            if let newId = resp.id { resultReview.id = newId }
            if let ec = resp.edit_count { resultReview.editCount = ec }
            return resultReview
        }

        // 2. Fallback REST
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
        if !effectiveUid.isEmpty { dict["user_id"] = effectiveUid }
        if let sId = review.subjectId, !sId.isEmpty, UUID(uuidString: sId) != nil {
            dict["subject_id"] = sId
        }

        let bodyData = try JSONSerialization.data(withJSONObject: [dict])
        let items: [TeacherReview] = try await client.requestJSON(
            url: reqUrl,
            method: "POST",
            headers: defaultHeaders(prefer: "return=representation,resolution=merge-duplicates"),
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
        let cleanName = teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        let surname = cleanName.split(separator: " ").first.map(String.init) ?? cleanName

        // 1. Поиск по фамилии
        if let encoded = "\(surname)*".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let reqUrl = URL(string: "\(url)/rest/v1/teacher_summaries?teacher_name=ilike.\(encoded)&select=*&order=reviews_count.desc&limit=1") {
            if let list: [TeacherSummary] = try? await client.requestJSON(url: reqUrl, headers: defaultHeaders()),
               let first = list.first {
                return first
            }
        }

        // 2. Fallback на точное совпадение
        if let encoded = cleanName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let reqUrl = URL(string: "\(url)/rest/v1/teacher_summaries?teacher_name=eq.\(encoded)&select=*") {
            if let list: [TeacherSummary] = try? await client.requestJSON(url: reqUrl, headers: defaultHeaders()),
               let first = list.first {
                return first
            }
        }
        return nil
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

    // MARK: - 7. User Resolution (Zero Personal Data Collection)
    public func resolveOrRegisterUser(
        externalUserId: String,
        externalIdentity: String? = nil,
        username: String? = nil,
        groupId: String? = nil,
        groupName: String? = nil,
        appVersion: String? = "2.1.0",
        deviceInfo: String? = "iPhone / iOS Native"
    ) async -> SupabaseAppUser {
        struct ResolveResp: Decodable {
            let user_id: String
            let can_upload_files: Bool?
            let can_view_materials: Bool?
            let can_publish_reviews: Bool?
            let review_edit_cooldown_seconds: Int?
            let sanction_reason: String?
            let sanction_expires_at: String?
            let is_admin: Bool?
            let group_name: String?
            let group_id: String?
        }

        if let rpcURL = URL(string: "\(url)/rest/v1/rpc/resolve_or_register_user") {
            let payload: [String: Any] = [
                "p_external_user_id": externalUserId,
                "p_external_identity": externalIdentity ?? NSNull(),
                "p_username": username ?? NSNull(),
                "p_group_id": groupId ?? NSNull(),
                "p_group_name": groupName ?? NSNull(),
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
                    groupName: first.group_name ?? groupName,
                    groupId: first.group_id ?? groupId,
                    deviceInfo: deviceInfo,
                    canUploadFiles: first.can_upload_files ?? true,
                    canViewMaterials: first.can_view_materials ?? true,
                    canPublishReviews: first.can_publish_reviews ?? true,
                    reviewEditCooldownSeconds: first.review_edit_cooldown_seconds ?? 60,
                    sanctionReason: first.sanction_reason,
                    sanctionExpiresAt: first.sanction_expires_at,
                    isAdmin: first.is_admin ?? false,
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
            return SupabaseAppUser(userId: userId)
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
                canUploadFiles: true,
                canViewMaterials: true,
                canPublishReviews: true,
                isAdmin: false,
                lastActive: ISO8601DateFormatter().string(from: Date())
            )
            return newUser
        } catch {
            return SupabaseAppUser(userId: userId)
        }
    }

    public func recordGroqUsage(userId: String, tokensUsed: Int, isRejected: Bool = false) async {
        guard !userId.isEmpty, tokensUsed > 0, let reqUrl = URL(string: "\(url)/rest/v1/rpc/record_groq_usage") else {
            return
        }
        let payload: [String: Any] = [
            "p_user_id": userId,
            "p_tokens_used": tokensUsed,
            "p_is_rejected": isRejected
        ]
        if let bodyData = try? JSONSerialization.data(withJSONObject: payload) {
            _ = try? await client.request(url: reqUrl, method: "POST", headers: defaultHeaders(), body: bodyData)
        }
    }

    public func verifyAdminMasterKey(secret: String) async -> Bool {
        guard !secret.isEmpty else { return false }
        if let reqUrl = URL(string: "\(url)/rest/v1/rpc/verify_admin_credentials") {
            struct AdminCredResp: Decodable {
                let success: Bool?
            }
            if let bodyData = try? JSONSerialization.data(withJSONObject: ["p_secret": secret]),
               let res: AdminCredResp = try? await client.requestJSON(url: reqUrl, method: "POST", headers: defaultHeaders(), body: bodyData) {
                if res.success == true { return true }
            }
        }
        return await verifyAdminPin(pin: secret)
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
    public func getAdminDashboardData(secret: String) async throws -> AdminDashboardData {
        guard let reqUrl = URL(string: "\(url)/rest/v1/rpc/get_admin_dashboard_data") else {
            throw NetworkError.invalidURL("Некорректный адрес RPC get_admin_dashboard_data")
        }
        let bodyData = try JSONSerialization.data(withJSONObject: ["p_secret": secret])
        return try await client.requestJSON(
            url: reqUrl,
            method: "POST",
            headers: defaultHeaders(),
            body: bodyData
        )
    }

    public func getAllUsers() async -> [SupabaseAppUser] {
        guard let reqUrl = URL(string: "\(url)/rest/v1/app_users?order=last_active.desc") else { return [] }
        return (try? await client.requestJSON(url: reqUrl, headers: defaultHeaders())) ?? []
    }

    public func getAllReviews() async -> [TeacherReview] {
        guard let reqUrl = URL(string: "\(url)/rest/v1/teacher_reviews?is_deleted=neq.true&order=created_at.desc") else { return [] }
        return (try? await client.requestJSON(url: reqUrl, headers: defaultHeaders())) ?? []
    }

    public func getAllMaterials() async -> [MaterialItem] {
        guard let reqUrl = URL(string: "\(url)/rest/v1/materials?order=created_at.desc") else { return [] }
        return (try? await client.requestJSON(url: reqUrl, headers: defaultHeaders())) ?? []
    }

    public func deleteReview(id: String, userId: String? = nil, isAdmin: Bool = false) async throws {
        // 1. Попытка через защищённый RPC delete_teacher_review
        if let rpcURL = URL(string: "\(url)/rest/v1/rpc/delete_teacher_review") {
            let payload: [String: Any] = [
                "p_user_id": userId ?? NSNull(),
                "p_review_id": id,
                "p_is_admin": isAdmin
            ]
            if let body = try? JSONSerialization.data(withJSONObject: payload),
               let res: Bool = try? await client.requestJSON(url: rpcURL, method: "POST", headers: defaultHeaders(), body: body),
               res == true {
                return
            }
        }

        // 2. Fallback REST
        guard let reqUrl = URL(string: "\(url)/rest/v1/teacher_reviews?id=eq.\(id)") else { return }
        _ = try await client.request(url: reqUrl, method: "DELETE", headers: defaultHeaders(prefer: "return=representation"))
    }

    public func deleteMaterial(id: String) async throws {
        guard let reqUrl = URL(string: "\(url)/rest/v1/materials?id=eq.\(id)") else { return }
        _ = try await client.request(url: reqUrl, method: "DELETE", headers: defaultHeaders(prefer: "return=representation"))
    }

    public func adminSetUserPermissions(
        masterSecret: String,
        adminUserId: String,
        targetUserId: String,
        canUploadFiles: Bool? = nil,
        canViewMaterials: Bool? = nil,
        canPublishReviews: Bool? = nil,
        cooldownSeconds: Int? = nil,
        sanctionReason: String? = nil,
        sanctionDurationHours: Int? = nil
    ) async throws -> Bool {
        if let rpcURL = URL(string: "\(url)/rest/v1/rpc/admin_set_user_permissions") {
            var payload: [String: Any] = [
                "p_master_secret": masterSecret,
                "p_admin_user_id": adminUserId,
                "p_target_user_id": targetUserId
            ]
            if let up = canUploadFiles { payload["p_can_upload_files"] = up }
            if let vm = canViewMaterials { payload["p_can_view_materials"] = vm }
            if let pr = canPublishReviews { payload["p_can_publish_reviews"] = pr }
            if let cd = cooldownSeconds { payload["p_cooldown_seconds"] = cd }
            if let sr = sanctionReason { payload["p_sanction_reason"] = sr }
            if let dh = sanctionDurationHours { payload["p_sanction_duration_hours"] = dh }

            struct Resp: Decodable {
                let success: Bool
            }

            let body = try JSONSerialization.data(withJSONObject: payload)
            let res: Resp = try await client.requestJSON(url: rpcURL, method: "POST", headers: defaultHeaders(), body: body)
            return res.success
        }

        // Fallback direct patch
        var updates: [String: Any] = [:]
        if let up = canUploadFiles { updates["can_upload_files"] = up }
        if let vm = canViewMaterials { updates["can_view_materials"] = vm }
        if let pr = canPublishReviews { updates["can_publish_reviews"] = pr }
        if let cd = cooldownSeconds { updates["review_edit_cooldown_seconds"] = cd }
        if let sr = sanctionReason { updates["sanction_reason"] = sr }
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
