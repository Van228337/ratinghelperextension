import SwiftUI

public struct AssessmentBadgeView: View {
    public let type: AssessmentType
    public var small: Bool = false

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(small ? .system(size: 9) : .system(size: 11))
            Text(type.rawValue)
                .font(small ? .caption2.weight(.semibold) : .caption.weight(.semibold))
        }
        .padding(.horizontal, small ? 6 : 8)
        .padding(.vertical, small ? 2 : 4)
        .background(type.badgeColor.opacity(0.12))
        .foregroundColor(type.badgeColor)
        .clipShape(Capsule())
    }
}
