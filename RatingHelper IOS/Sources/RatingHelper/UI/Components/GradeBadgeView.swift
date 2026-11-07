import SwiftUI

public struct GradeBadgeView: View {
    public let grade: AcademicGrade
    public var customText: String? = nil
    public var small: Bool = false

    public var body: some View {
        Text(customText ?? grade.title)
            .font(small ? .caption2.weight(.bold) : .caption.weight(.bold))
            .padding(.horizontal, small ? 6 : 10)
            .padding(.vertical, small ? 2 : 4)
            .background(grade.color.opacity(0.15))
            .foregroundColor(grade.color)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(grade.color.opacity(0.3), lineWidth: 1)
            )
    }
}
