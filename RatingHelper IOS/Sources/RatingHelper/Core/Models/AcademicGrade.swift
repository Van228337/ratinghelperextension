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

    public static func subtext(for percentage: Double) -> String {
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
            return "До зачёта / тройки не хватает \(toNext)%"
        }
    }
}
