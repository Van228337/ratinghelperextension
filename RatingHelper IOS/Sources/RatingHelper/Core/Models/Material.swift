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
        createdAt: String? = nil
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
    }
}
