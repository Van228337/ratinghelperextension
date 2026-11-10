import SwiftUI

public enum AcademicGrade: Int, Codable, CaseIterable, Sendable {
    case unsatisfactory = 2
    case satisfactory = 3
    case good = 4
    case excellent = 5

    public var title: String {
        switch self {
        case .excellent: return "Отлично (5)"
        case .good: return "Хорошо (4)"
        case .satisfactory: return "Удовлетворительно (3)"
        case .unsatisfactory: return "Незачёт / Долг (2)"
        }
    }

    public var shortLabel: String {
        switch self {
        case .excellent: return "Отл (5)"
        case .good: return "Хор (4)"
        case .satisfactory: return "Удовл (3)"
        case .unsatisfactory: return "Долг (2)"
        }
    }

    public var threshold: Double {
        switch self {
        case .excellent: return 84.01
        case .good: return 74.01
        case .satisfactory: return 59.01
        case .unsatisfactory: return 0.0
        }
    }

    public var color: Color {
        switch self {
        case .excellent: return Color(red: 0.13, green: 0.77, blue: 0.37) // #22c55e
        case .good: return Color(red: 0.15, green: 0.39, blue: 0.92)      // #2563eb
        case .satisfactory: return Color(red: 0.96, green: 0.62, blue: 0.04) // #f59e0b
        case .unsatisfactory: return Color(red: 0.94, green: 0.27, blue: 0.24) // #ef4444
        }
    }

    public var lightBackground: Color {
        switch self {
        case .excellent: return Color(red: 0.86, green: 0.99, blue: 0.90)
        case .good: return Color(red: 0.86, green: 0.92, blue: 1.00)
        case .satisfactory: return Color(red: 1.00, green: 0.95, blue: 0.78)
        case .unsatisfactory: return Color(red: 1.00, green: 0.89, blue: 0.89)
        }
    }

    public static func from(percentage: Double) -> AcademicGrade {
        if percentage >= 84.01 {
            return .excellent
        } else if percentage >= 74.01 {
            return .good
        } else if percentage >= 59.01 {
            return .satisfactory
        } else {
            return .unsatisfactory
        }
    }

    public static func subtext(for percentage: Double, assessmentType: AssessmentType = .unknown) -> String {
        if assessmentType == .zachet {
            if percentage >= 59.01 {
                return "Зачёт получен! Минимальный порог 59.01% успешно преодолён."
            } else {
                let toNext = String(format: "%.1f", 59.01 - percentage)
                return "До зачёта не хватает \(toNext)%"
            }
        }

        let current = percentage
        if current >= 84.01 {
            return "Отличный результат по БРС! Сдача обеспечена."
        } else if current >= 74.01 {
            let toNext = String(format: "%.2f", 84.01 - current)
            return "До «Отлично (5)» не хватает \(toNext)%"
        } else if current >= 59.01 {
            let toNext = String(format: "%.2f", 74.01 - current)
            return "До «Хорошо (4)» не хватает \(toNext)%"
        } else {
            let toNext = String(format: "%.2f", 59.01 - current)
            let targetLabel = (assessmentType == .exam) ? "тройки (3)" : "сдачи"
            return "До \(targetLabel) не хватает \(toNext)%"
        }
    }
}

public struct AcademicEvaluation: Hashable, Sendable {
    public let rating: Double
    public let assessmentType: AssessmentType
    public let statusTitle: String
    public let shortLabel: String
    public let isPassed: Bool
    public let gradeValue: Int?
    public let progressToNext: String?
    public let color: Color
    public let lightBackground: Color

    public static func evaluate(percentage: Double, assessmentType: AssessmentType) -> AcademicEvaluation {
        let current = percentage.isFinite ? max(0, percentage) : 0
        switch assessmentType {
        case .zachet:
            if current >= 59.01 {
                return AcademicEvaluation(
                    rating: current,
                    assessmentType: assessmentType,
                    statusTitle: "Зачтено",
                    shortLabel: "Зачёт",
                    isPassed: true,
                    gradeValue: nil,
                    progressToNext: nil,
                    color: Color(red: 0.13, green: 0.77, blue: 0.37),
                    lightBackground: Color(red: 0.86, green: 0.99, blue: 0.90)
                )
            } else {
                let toZachet = String(format: "%.1f", 59.01 - current)
                return AcademicEvaluation(
                    rating: current,
                    assessmentType: assessmentType,
                    statusTitle: "Не зачтено",
                    shortLabel: "Незачёт",
                    isPassed: false,
                    gradeValue: nil,
                    progressToNext: "До зачёта не хватает \(toZachet)%",
                    color: Color(red: 0.94, green: 0.27, blue: 0.24),
                    lightBackground: Color(red: 1.00, green: 0.89, blue: 0.89)
                )
            }
        case .exam, .diffZachet, .coursework, .courseProject, .practice, .unknown:
            let g = AcademicGrade.from(percentage: current)
            let subtext: String?
            if current >= 84.01 {
                subtext = "Отличный результат по БРС!"
            } else if current >= 74.01 {
                let toNext = String(format: "%.1f", 84.01 - current)
                subtext = "До «Отлично (5)» не хватает \(toNext)%"
            } else if current >= 59.01 {
                let toNext = String(format: "%.1f", 74.01 - current)
                subtext = "До «Хорошо (4)» не хватает \(toNext)%"
            } else {
                let toNext = String(format: "%.1f", 59.01 - current)
                let targetLabel = (assessmentType == .exam) ? "тройки (3)" : "сдачи (3)"
                subtext = "До \(targetLabel) не хватает \(toNext)%"
            }
            return AcademicEvaluation(
                rating: current,
                assessmentType: assessmentType,
                statusTitle: g.title,
                shortLabel: g.shortLabel,
                isPassed: current >= 59.01,
                gradeValue: g.rawValue,
                progressToNext: subtext,
                color: g.color,
                lightBackground: g.lightBackground
            )
        }
    }
}
