import Foundation
import SwiftUI

public enum TaskPriority: String, Codable, CaseIterable, Identifiable, Sendable {
    case low = "low"
    case normal = "normal"
    case high = "high"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .low: return "Низкий"
        case .normal: return "Обычный"
        case .high: return "Высокий"
        }
    }

    public var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .normal: return "minus"
        case .high: return "exclamationmark"
        }
    }

    public var color: Color {
        switch self {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .red
        }
    }
}

public enum TaskStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .notStarted: return "Не начата"
        case .inProgress: return "В процессе"
        case .completed: return "Выполнена"
        }
    }

    public var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.dashed"
        case .completed: return "checkmark.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .notStarted: return .secondary
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

public enum TaskSourceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual = "manual"
    case checkpoint = "checkpoint"
    case moodle = "moodle"
    case schedule = "schedule"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .manual: return "Вручную"
        case .checkpoint: return "Контрольная точка"
        case .moodle: return "Moodle Дедлайн"
        case .schedule: return "Расписание"
        }
    }

    public var icon: String {
        switch self {
        case .manual: return "square.and.pencil"
        case .checkpoint: return "flag.fill"
        case .moodle: return "graduationcap.fill"
        case .schedule: return "calendar"
        }
    }
}

public enum TaskReminderOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case onDay = "on_day"
    case dayBefore = "day_before"
    case threeDaysBefore = "three_days_before"
    case weekBefore = "week_before"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .onDay: return "В день дедлайна (09:00)"
        case .dayBefore: return "За 1 день (09:00)"
        case .threeDaysBefore: return "За 3 дня (09:00)"
        case .weekBefore: return "За 1 неделю (09:00)"
        }
    }

    public func triggerDate(from dueDate: Date) -> Date? {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: dueDate)
        comps.hour = 9
        comps.minute = 0
        comps.second = 0
        guard let baseDate = cal.date(from: comps) else { return nil }

        switch self {
        case .onDay:
            return baseDate
        case .dayBefore:
            return cal.date(byAdding: .day, value: -1, to: baseDate)
        case .threeDaysBefore:
            return cal.date(byAdding: .day, value: -3, to: baseDate)
        case .weekBefore:
            return cal.date(byAdding: .day, value: -7, to: baseDate)
        }
    }
}

public struct StudyTask: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var disciplineId: String?
    public var disciplineName: String?
    public var checkpointId: String?
    public var checkpointTitle: String?
    public var termNumber: Int?
    public var sourceDeadline: Date?
    public var customDeadline: Date?
    public var dueDate: Date?
    public var externalSource: TaskSourceType
    public var externalId: String?
    public var priority: TaskPriority
    public var status: TaskStatus
    public var reminderOptions: [TaskReminderOption]
    public var customReminderDate: Date?
    public var createdAt: Date
    public var completedAt: Date?

    public var effectiveDeadline: Date? {
        customDeadline ?? sourceDeadline ?? dueDate
    }

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        disciplineId: String? = nil,
        disciplineName: String? = nil,
        checkpointId: String? = nil,
        checkpointTitle: String? = nil,
        termNumber: Int? = nil,
        sourceDeadline: Date? = nil,
        customDeadline: Date? = nil,
        dueDate: Date? = nil,
        externalSource: TaskSourceType = .manual,
        externalId: String? = nil,
        priority: TaskPriority = .normal,
        status: TaskStatus = .notStarted,
        reminderOptions: [TaskReminderOption] = [.onDay],
        customReminderDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.disciplineId = disciplineId
        self.disciplineName = disciplineName
        self.checkpointId = checkpointId
        self.checkpointTitle = checkpointTitle
        self.termNumber = termNumber
        self.sourceDeadline = sourceDeadline
        self.customDeadline = customDeadline
        self.dueDate = dueDate ?? customDeadline ?? sourceDeadline
        self.externalSource = externalSource
        self.externalId = externalId
        self.priority = priority
        self.status = status
        self.reminderOptions = reminderOptions
        self.customReminderDate = customReminderDate
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public var isOverdue: Bool {
        guard let due = effectiveDeadline, status != .completed else { return false }
        return due < Date()
    }

    public var isDueToday: Bool {
        guard let due = effectiveDeadline, status != .completed else { return false }
        return Calendar.current.isDateInToday(due)
    }

    public var isDueUpcoming: Bool {
        guard let due = effectiveDeadline, status != .completed else { return false }
        let now = Date()
        let inWeek = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return due > now && due <= inWeek && !Calendar.current.isDateInToday(due)
    }

    public var isDueLater: Bool {
        guard let due = effectiveDeadline, status != .completed else { return false }
        let inWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return due > inWeek
    }
}
