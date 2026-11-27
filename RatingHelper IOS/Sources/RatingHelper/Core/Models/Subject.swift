import SwiftUI

public enum AssessmentType: String, Codable, CaseIterable, Sendable {
    case exam = "Экзамен"
    case zachet = "Зачёт"
    case diffZachet = "Диф. зачёт"
    case coursework = "Курсовая работа"
    case courseProject = "Курсовой проект"
    case practice = "Практика"
    case unknown = "Другое"

    public var icon: String {
        switch self {
        case .exam: return "book.closed.fill"
        case .zachet: return "checkmark.seal.fill"
        case .diffZachet: return "chart.bar.fill"
        case .coursework: return "doc.text.fill"
        case .courseProject: return "folder.fill"
        case .practice: return "figure.walk"
        case .unknown: return "list.bullet.clipboard"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .exam: return Color.blue
        case .zachet: return Color.green
        case .diffZachet: return Color.purple
        case .coursework, .courseProject, .practice: return Color.orange
        case .unknown: return Color.gray
        }
    }

    public static func parse(_ raw: String?) -> AssessmentType {
        guard let text = raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return .unknown
        }
        if text.contains("практик") {
            return .practice
        } else if text.contains("дифференцированный") || text.contains("диф. зачет") || text.contains("диф.зачет") || text.contains("диф зачет") || text.contains("диф. зачёт") || text == "диф.зач" || text == "дифзачет" {
            return .diffZachet
        } else if text.contains("курсовой проект") || text == "кп" || text.hasPrefix("кп ") || text.hasSuffix(" кп") {
            return .courseProject
        } else if text.contains("курсовая работа") || text.contains("курсовая") || text.contains("курсовой") || text.contains("курсовые") || text == "кр" || text.hasPrefix("кр ") || text.hasSuffix(" кр") {
            return .coursework
        } else if text.contains("экзамен") || text == "экз" {
            return .exam
        } else if text.contains("зачет") || text.contains("зачёт") || text == "зач" {
            return .zachet
        }
        return .unknown
    }
}

public struct SubjectInstructor: Codable, Hashable, Sendable {
    public let lastName: String?
    public let firstName: String?
    public let middleName: String?

    public var fullName: String {
        [lastName, firstName, middleName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

public struct RawSubjectResponse: Codable, Sendable {
    public let disciplineId: String
    public let disciplineName: String
    public let rating: Double?
    public let controlType: String?
    public let assessmentType: String?
    public let attestationType: String?
    public let controlTypeId: Int?
    public let checkNumber: Int?
    public let termNumber: Int?
    public let instructors: [SubjectInstructor]?
    public let isCourseWorkOrProject: Bool?
    public let isCredit: Bool?

    enum CodingKeys: String, CodingKey {
        case disciplineId, disciplineName, rating, controlType, assessmentType, attestationType
        case controlTypeId, checkNumber, termNumber, instructors
        case isCourseWorkOrProject, isCredit
        case controlTypeSnake = "control_type"
        case attestationTypeSnake = "attestation_type"
        case controlTypeIdSnake = "control_type_id"
        case isCourseWorkOrProjectSnake = "is_course_work_or_project"
        case isCreditSnake = "is_credit"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        disciplineId = try c.decode(String.self, forKey: .disciplineId)
        disciplineName = try c.decode(String.self, forKey: .disciplineName)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        controlType = try c.decodeIfPresent(String.self, forKey: .controlType)
            ?? (try c.decodeIfPresent(String.self, forKey: .controlTypeSnake))
        assessmentType = try c.decodeIfPresent(String.self, forKey: .assessmentType)
        attestationType = try c.decodeIfPresent(String.self, forKey: .attestationType)
            ?? (try c.decodeIfPresent(String.self, forKey: .attestationTypeSnake))
        func decodeInt(_ key: CodingKeys) -> Int? {
            if let value = try? c.decode(Int.self, forKey: key) { return value }
            if let value = try? c.decode(String.self, forKey: key) { return Int(value) }
            return nil
        }
        controlTypeId = decodeInt(.controlTypeId) ?? decodeInt(.controlTypeIdSnake)
        checkNumber = decodeInt(.checkNumber)
        termNumber = decodeInt(.termNumber)
        instructors = try c.decodeIfPresent([SubjectInstructor].self, forKey: .instructors)
        isCourseWorkOrProject = try c.decodeIfPresent(Bool.self, forKey: .isCourseWorkOrProject)
            ?? (try c.decodeIfPresent(Bool.self, forKey: .isCourseWorkOrProjectSnake))
        isCredit = try c.decodeIfPresent(Bool.self, forKey: .isCredit)
            ?? (try c.decodeIfPresent(Bool.self, forKey: .isCreditSnake))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(disciplineId, forKey: .disciplineId)
        try c.encode(disciplineName, forKey: .disciplineName)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(controlType, forKey: .controlType)
        try c.encodeIfPresent(assessmentType, forKey: .assessmentType)
        try c.encodeIfPresent(attestationType, forKey: .attestationType)
        try c.encodeIfPresent(controlTypeId, forKey: .controlTypeId)
        try c.encodeIfPresent(checkNumber, forKey: .checkNumber)
        try c.encodeIfPresent(termNumber, forKey: .termNumber)
        try c.encodeIfPresent(instructors, forKey: .instructors)
        try c.encodeIfPresent(isCourseWorkOrProject, forKey: .isCourseWorkOrProject)
        try c.encodeIfPresent(isCredit, forKey: .isCredit)
    }
}

public struct Subject: Identifiable, Codable, Hashable, Sendable {
    public var isCourseWork: Bool {
        assessmentType == .coursework || assessmentType == .courseProject
    }

    public var id: String {
        isCourseWork ? "\(disciplineId)_cw" : disciplineId
    }

    public var displayName: String {
        if assessmentType == .coursework {
            return "\(disciplineName) (КР)"
        } else if assessmentType == .courseProject {
            return "\(disciplineName) (КП)"
        }
        return disciplineName
    }

    public let disciplineId: String
    public var disciplineName: String
    public var rating: Double
    public var controlType: String
    public var assessmentType: AssessmentType
    public var checkNumber: Int
    public var termNumber: Int
    public var instructor: String
    public var hasJournal: Bool
    public var isHidden: Bool
    public var lastUpdated: Date

    public init(
        disciplineId: String,
        disciplineName: String,
        rating: Double,
        controlType: String,
        assessmentType: AssessmentType? = nil,
        checkNumber: Int = 0,
        termNumber: Int = 1,
        instructor: String = "",
        hasJournal: Bool = true,
        isHidden: Bool = false,
        lastUpdated: Date = Date()
    ) {
        self.disciplineId = disciplineId
        self.disciplineName = disciplineName
        self.rating = rating
        self.controlType = controlType
        self.assessmentType = assessmentType ?? AssessmentType.parse(controlType)
        self.checkNumber = checkNumber
        self.termNumber = termNumber
        self.instructor = instructor
        self.hasJournal = hasJournal
        self.isHidden = isHidden
        self.lastUpdated = lastUpdated
    }

    public static func from(raw: RawSubjectResponse, term: Int, isHidden: Bool = false) -> Subject {
        let instructorName = raw.instructors?.first?.fullName ?? ""
        let control = raw.controlType ?? raw.assessmentType ?? raw.attestationType ?? ""
        
        var parsedType = AssessmentType.parse(control)

        // 1. Check if explicitly marked as Course Work or Project
        let lowerName = raw.disciplineName.lowercased()
        let lowerControl = control.lowercased()
        let isCwFlag = raw.isCourseWorkOrProject == true
        let hasCwName = lowerName.contains("курсов") || lowerName.contains(" кр") || lowerName.contains(" кп") || lowerControl.contains("курсов") || lowerControl == "кр" || lowerControl == "кп"

        if parsedType == .unknown && (isCwFlag || hasCwName) {
            if lowerName.contains("проект") || lowerControl.contains("проект") || lowerControl == "кп" {
                parsedType = .courseProject
            } else {
                parsedType = .coursework
            }
        }

        // 2. Check controlTypeId mappings from SUSU API database
        if parsedType == .unknown, let typeId = raw.controlTypeId {
            switch typeId {
            case 1: parsedType = .exam
            case 2: parsedType = .zachet
            case 3: parsedType = .diffZachet
            case 4: parsedType = .coursework
            case 5: parsedType = .courseProject
            case 6: parsedType = .practice
            default: break
            }
        }

        // 3. Fallback check for credit / exam flag
        if parsedType == .unknown {
            if let isCredit = raw.isCredit {
                parsedType = isCredit ? .zachet : .exam
            }
        }

        let hasJournal = !(raw.instructors?.isEmpty ?? true)
        return Subject(
            disciplineId: raw.disciplineId,
            disciplineName: cleanName(raw.disciplineName),
            rating: raw.rating ?? 0.0,
            controlType: control.isEmpty ? parsedType.rawValue : control,
            assessmentType: parsedType,
            checkNumber: raw.checkNumber ?? 0,
            termNumber: raw.termNumber ?? term,
            instructor: instructorName,
            hasJournal: hasJournal,
            isHidden: isHidden
        )
    }

    public static func cleanName(_ name: String) -> String {
        var cleaned = name
        // Remove trailing badge symbols or "Рейтинг: ..."
        if let range = cleaned.range(of: "[🎓⚡📝✅📊📂].*$", options: .regularExpression) {
            cleaned.removeSubrange(range)
        }
        if let range = cleaned.range(of: "Рейтинг:.*$", options: .regularExpression) {
            cleaned.removeSubrange(range)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
