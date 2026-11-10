import Foundation

public struct ScheduleInstructor: Codable, Hashable, Sendable {
    public let name: String?
    public let roomId: String?
    public let location: String?

    enum CodingKeys: String, CodingKey {
        case name, roomId, location
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        if let s = try? c.decode(String.self, forKey: .roomId) {
            roomId = s
        } else if let i = try? c.decode(Int.self, forKey: .roomId) {
            roomId = String(i)
        } else {
            roomId = nil
        }
        location = try? c.decodeIfPresent(String.self, forKey: .location)
    }

    public init(name: String? = nil, roomId: String? = nil, location: String? = nil) {
        self.name = name
        self.roomId = roomId
        self.location = location
    }

    public var displayLocation: String {
        if let loc = location, !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return loc.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Аудитория уточняется"
    }

    public var displayName: String {
        if let n = name, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return n.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Преподаватель не указан"
    }
}

public struct ScheduleLesson: Identifiable, Codable, Hashable, Sendable {
    public var id: String {
        "\(eventDate)_\(beginTime)_\(subject)_\(instructors.first?.roomId ?? "")_\(eventType)"
    }
    public let beginTime: String
    public let endTime: String
    public let subject: String
    public let eventType: String
    public let eventDate: String
    public let instructors: [ScheduleInstructor]
    public let isAllowedToOpen: Bool?
    public var matchedSubjectId: String?

    enum CodingKeys: String, CodingKey {
        case beginTime, endTime, subject, eventType, eventDate, instructors, isAllowedToOpen, matchedSubjectId
    }

    public init(
        beginTime: String,
        endTime: String,
        subject: String,
        eventType: String,
        eventDate: String,
        instructors: [ScheduleInstructor] = [],
        isAllowedToOpen: Bool? = nil,
        matchedSubjectId: String? = nil
    ) {
        self.beginTime = beginTime
        self.endTime = endTime
        self.subject = subject
        self.eventType = eventType
        self.eventDate = eventDate
        self.instructors = instructors
        self.isAllowedToOpen = isAllowedToOpen
        self.matchedSubjectId = matchedSubjectId
    }

    public var formattedTimeRange: String {
        let b = String(beginTime.prefix(5))
        let e = String(endTime.prefix(5))
        return "\(b) — \(e)"
    }

    public var eventTypeIcon: String {
        let lower = eventType.lowercased()
        if lower.contains("лекц") {
            return "book.fill"
        } else if lower.contains("практ") {
            return "pencil.and.ruler.fill"
        } else if lower.contains("лабор") {
            return "flask.fill"
        } else if lower.contains("консуль") {
            return "person.2.fill"
        } else if lower.contains("экзам") || lower.contains("зачет") || lower.contains("зачёт") {
            return "checkmark.seal.fill"
        }
        return "calendar"
    }
}
