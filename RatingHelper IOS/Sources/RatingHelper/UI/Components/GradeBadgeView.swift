import SwiftUI

public struct GradeBadgeView: View {
    public let grade: AcademicGrade
    public var evaluation: AcademicEvaluation? = nil
    public var customText: String? = nil
    public var small: Bool = false

    public init(grade: AcademicGrade, evaluation: AcademicEvaluation? = nil, customText: String? = nil, small: Bool = false) {
        self.grade = grade
        self.evaluation = evaluation
        self.customText = customText
        self.small = small
    }

    public var body: some View {
        let label = customText ?? (evaluation?.statusTitle ?? grade.title)
        let color = evaluation?.color ?? grade.color
        Text(label)
            .font(small ? .caption2.weight(.bold) : .caption.weight(.bold))
            .padding(.horizontal, small ? 6 : 10)
            .padding(.vertical, small ? 2 : 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}
