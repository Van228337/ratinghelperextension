import Foundation

public struct MaterialItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var checkpointId: String
    public var subjectId: String
    public var teacherName: String?
    public var title: String
    public var fileUrl: String
    public var fileName: String
    public var year: Int
    public var upvotes: Int
    public var downvotes: Int
    public var createdAt: String?
    public var userId: String?
    public var fileSizeBytes: Int64
    public var fileSha256: String?
    public var driveFileId: String?

    public var isFresh: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return max(0, currentYear - year) <= 1
    }

    public var relevanceScore: Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = max(0, currentYear - year)
        let freshnessScore = max(0, 10 - age * 2)
        let voteScore = (upvotes - downvotes) * 3
        return freshnessScore + voteScore
    }

    public init(
        id: String = UUID().uuidString,
        checkpointId: String,
        subjectId: String,
        teacherName: String? = nil,
        title: String,
        fileUrl: String,
        fileName: String,
        year: Int = Calendar.current.component(.year, from: Date()),
        upvotes: Int = 1,
        downvotes: Int = 0,
        createdAt: String? = nil,
        userId: String? = nil,
        fileSizeBytes: Int64 = 0,
        fileSha256: String? = nil,
        driveFileId: String? = nil
    ) {
        self.id = id
        self.checkpointId = checkpointId
        self.subjectId = subjectId
        self.teacherName = teacherName
        self.title = title
        self.fileUrl = fileUrl
        self.fileName = fileName
        self.year = year
        self.upvotes = upvotes
        self.downvotes = downvotes
        self.createdAt = createdAt
        self.userId = userId
        self.fileSizeBytes = fileSizeBytes
        self.fileSha256 = fileSha256
        self.driveFileId = driveFileId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case checkpointId = "checkpoint_id"
        case subjectId = "subject_id"
        case teacherName = "teacher_name"
        case title
        case fileUrl = "file_url"
        case fileName = "file_name"
        case year
        case upvotes
        case downvotes
        case createdAt = "created_at"
        case userId = "user_id"
        case fileSizeBytes = "file_size_bytes"
        case fileSha256 = "file_sha256"
        case driveFileId = "drive_file_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.checkpointId = try c.decode(String.self, forKey: .checkpointId)
        self.subjectId = try c.decode(String.self, forKey: .subjectId)
        self.teacherName = try? c.decodeIfPresent(String.self, forKey: .teacherName)
        self.title = try c.decode(String.self, forKey: .title)
        self.fileUrl = try c.decode(String.self, forKey: .fileUrl)
        self.fileName = try c.decode(String.self, forKey: .fileName)
        self.year = (try? c.decodeIfPresent(Int.self, forKey: .year)) ?? Calendar.current.component(.year, from: Date())
        self.upvotes = (try? c.decodeIfPresent(Int.self, forKey: .upvotes)) ?? 1
        self.downvotes = (try? c.decodeIfPresent(Int.self, forKey: .downvotes)) ?? 0
        self.createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        self.userId = try? c.decodeIfPresent(String.self, forKey: .userId)
        self.fileSizeBytes = (try? c.decodeIfPresent(Int64.self, forKey: .fileSizeBytes)) ?? 0
        self.fileSha256 = try? c.decodeIfPresent(String.self, forKey: .fileSha256)
        self.driveFileId = try? c.decodeIfPresent(String.self, forKey: .driveFileId)
    }
}
