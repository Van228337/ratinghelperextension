import Foundation

// MARK: - Варианты выписки

public enum TranscriptVariant: String, CaseIterable, Identifiable, Sendable {
    /// Одна дисциплина со всеми контрольными точками. Поддерживает моделирование.
    case single
    /// Все дисциплины текущего семестра со всеми контрольными точками. Только факт.
    case allDisciplines
    /// Сводный рейтинг по дисциплинам текущего семестра, без контрольных точек. Только факт.
    case overall

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .single: return "Одна дисциплина"
        case .allDisciplines: return "Все дисциплины"
        case .overall: return "Общий рейтинг"
        }
    }

    public var summary: String {
        switch self {
        case .single:
            return "Все контрольные точки выбранной дисциплины, баллы и итоговый рейтинг."
        case .allDisciplines:
            return "Все дисциплины текущего семестра с полным списком контрольных точек."
        case .overall:
            return "Рейтинг каждой дисциплины без контрольных точек — общая картина успеваемости."
        }
    }

    public var supportsSimulation: Bool { self == .single }

    public var documentTitle: String {
        switch self {
        case .single: return "Выписка по дисциплине"
        case .allDisciplines: return "Выписка с оценками"
        case .overall: return "Рейтинг семестра"
        }
    }
}

public enum TranscriptMode: String, CaseIterable, Identifiable, Sendable {
    /// Фактические результаты на момент формирования.
    case actual
    /// Факт и сохранённый план моделирования рядом. Оценки не изменяются.
    case simulated

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .actual: return "Фактическая"
        case .simulated: return "С моделированием"
        }
    }
}

// MARK: - Содержимое выписки

public struct TranscriptCheckpoint: Identifiable, Hashable, Sendable {
    public let index: Int
    public let title: String
    public let fact: Double
    public let maxScore: Double
    /// Балл из сохранённого плана моделирования. `nil` — планирования для точки нет.
    public let planned: Double?

    public var id: Int { index }

    public var delta: Double? {
        guard let planned else { return nil }
        return planned - fact
    }

    public var isChanged: Bool {
        guard let delta else { return false }
        return abs(delta) > 0.001
    }

    public init(index: Int, title: String, fact: Double, maxScore: Double, planned: Double? = nil) {
        self.index = index
        self.title = title
        self.fact = fact
        self.maxScore = maxScore
        self.planned = planned
    }
}

public struct TranscriptDiscipline: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let assessmentType: AssessmentType
    public let instructor: String
    public let checkpoints: [TranscriptCheckpoint]
    public let factRating: Double
    public let factGrade: AcademicGrade
    public let plannedRating: Double?
    public let plannedGrade: AcademicGrade?
    /// Журнал недоступен (нет сети и кэша): показан только рейтинг из списка дисциплин.
    public let checkpointsUnavailable: Bool

    public var hasPlan: Bool { plannedRating != nil }

    public var ratingDelta: Double? {
        guard let plannedRating else { return nil }
        return plannedRating - factRating
    }

    public init(
        id: String,
        name: String,
        assessmentType: AssessmentType,
        instructor: String,
        checkpoints: [TranscriptCheckpoint],
        factRating: Double,
        factGrade: AcademicGrade,
        plannedRating: Double? = nil,
        plannedGrade: AcademicGrade? = nil,
        checkpointsUnavailable: Bool = false
    ) {
        self.id = id
        self.name = name
        self.assessmentType = assessmentType
        self.instructor = instructor
        self.checkpoints = checkpoints
        self.factRating = factRating
        self.factGrade = factGrade
        self.plannedRating = plannedRating
        self.plannedGrade = plannedGrade
        self.checkpointsUnavailable = checkpointsUnavailable
    }
}

public struct TranscriptDocument: Sendable {
    public let variant: TranscriptVariant
    public let mode: TranscriptMode
    public let term: Int
    public let academicYear: String
    public let student: String
    public let group: String
    public let institute: String
    public let generatedAt: Date
    public let disciplines: [TranscriptDiscipline]
    public let averageRating: Double?

    public var title: String { variant.documentTitle }

    public var isSimulation: Bool {
        mode == .simulated && disciplines.contains(where: { $0.hasPlan })
    }

    public init(
        variant: TranscriptVariant,
        mode: TranscriptMode,
        term: Int,
        academicYear: String,
        student: String,
        group: String,
        institute: String,
        generatedAt: Date,
        disciplines: [TranscriptDiscipline],
        averageRating: Double? = nil
    ) {
        self.variant = variant
        self.mode = mode
        self.term = term
        self.academicYear = academicYear
        self.student = student
        self.group = group
        self.institute = institute
        self.generatedAt = generatedAt
        self.disciplines = disciplines
        self.averageRating = averageRating
    }
}

public enum TranscriptError: LocalizedError {
    case noSubjects
    case disciplineNotFound
    case journalUnavailable

    public var errorDescription: String? {
        switch self {
        case .noSubjects:
            return "В текущем семестре нет активных дисциплин для выписки."
        case .disciplineNotFound:
            return "Выберите дисциплину для выписки."
        case .journalUnavailable:
            return "Не удалось загрузить журнал дисциплины. Проверьте подключение к сети и попробуйте снова."
        }
    }
}
