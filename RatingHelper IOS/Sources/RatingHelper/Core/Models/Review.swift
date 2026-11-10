import Foundation

public struct TeacherReview: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var teacherName: String
    public var subjectId: String?
    public var subjectName: String?
    public var text: String
    public var difficulty: Int
    public var givesAvtomat: Bool
    public var attendanceStrict: Bool
    public var year: Int
    public var likes: Int
    public var dislikes: Int
    public var createdAt: String?

    public init(
        id: String = UUID().uuidString,
        teacherName: String,
        subjectId: String? = nil,
        subjectName: String? = nil,
        text: String,
        difficulty: Int = 3,
        givesAvtomat: Bool = false,
        attendanceStrict: Bool = false,
        year: Int = Calendar.current.component(.year, from: Date()),
        likes: Int = 0,
        dislikes: Int = 0,
        createdAt: String? = nil
    ) {
        self.id = id
        self.teacherName = teacherName
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.text = text
        self.difficulty = difficulty
        self.givesAvtomat = givesAvtomat
        self.attendanceStrict = attendanceStrict
        self.year = year
        self.likes = likes
        self.dislikes = dislikes
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case teacherName = "teacher_name"
        case subjectId = "subject_id"
        case subjectName = "subject_name"
        case text
        case difficulty
        case givesAvtomat = "gives_avtomat"
        case attendanceStrict = "attendance_strict"
        case year
        case likes
        case dislikes
        case createdAt = "created_at"
    }
}

public struct TeacherSummary: Codable, Hashable, Sendable {
    public var teacherName: String
    public var summaryText: String
    public var reviewsCount: Int
    public var updatedAt: String?

    public init(
        teacherName: String,
        summaryText: String,
        reviewsCount: Int = 0,
        updatedAt: String? = nil
    ) {
        self.teacherName = teacherName
        self.summaryText = summaryText
        self.reviewsCount = reviewsCount
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case teacherName = "teacher_name"
        case summaryText = "summary_text"
        case reviewsCount = "reviews_count"
        case updatedAt = "updated_at"
    }
}

public struct TeacherStats: Codable, Hashable, Sendable {
    public var totalReviews: Int
    public var avgDifficulty: Double
    public var avtomatPct: Int
    public var attendancePct: Int

    public init(
        totalReviews: Int = 0,
        avgDifficulty: Double = 3.0,
        avtomatPct: Int = 0,
        attendancePct: Int = 0
    ) {
        self.totalReviews = totalReviews
        self.avgDifficulty = avgDifficulty
        self.avtomatPct = avtomatPct
        self.attendancePct = attendancePct
    }

    public static func compute(from reviews: [TeacherReview]) -> TeacherStats? {
        guard !reviews.isEmpty else { return nil }
        let total = reviews.count
        let sumDiff = reviews.reduce(0) { $0 + $1.difficulty }
        let avtomatCount = reviews.filter { $0.givesAvtomat }.count
        let strictCount = reviews.filter { $0.attendanceStrict }.count

        return TeacherStats(
            totalReviews: total,
            avgDifficulty: Double(sumDiff) / Double(total),
            avtomatPct: Int((Double(avtomatCount) / Double(total)) * 100),
            attendancePct: Int((Double(strictCount) / Double(total)) * 100)
        )
    }
}

public struct TeacherDisciplineItem: Codable, Hashable, Sendable {
    public let disciplineId: String?
    public let disciplineName: String?

    public init(disciplineId: String? = nil, disciplineName: String? = nil) {
        self.disciplineId = disciplineId
        self.disciplineName = disciplineName
    }

    enum CodingKeys: String, CodingKey {
        case disciplineId = "discipline_id"
        case disciplineName = "discipline_name"
    }
}

public struct TeacherCardData: Codable, Sendable {
    public let id: String?
    public let fullName: String
    public let department: String?
    public let photoUrl: String?
    public let disciplines: [TeacherDisciplineItem]?
    public let stats: TeacherStats?
    public let summary: TeacherSummary?

    public init(
        id: String? = nil,
        fullName: String,
        department: String? = nil,
        photoUrl: String? = nil,
        disciplines: [TeacherDisciplineItem]? = nil,
        stats: TeacherStats? = nil,
        summary: TeacherSummary? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.department = department
        self.photoUrl = photoUrl
        self.disciplines = disciplines
        self.stats = stats
        self.summary = summary
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case department
        case photoUrl = "photo_url"
        case disciplines
        case stats
        case summary
    }
}
