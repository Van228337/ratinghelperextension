import SwiftUI

public struct ProgressRingView: View {
    public let value: Double
    public var label: String? = nil
    public var size: CGFloat = 72
    public var strokeWidth: CGFloat = 7

    private var clampedValue: Double {
        max(0.0, min(100.0, value))
    }

    private var gradeColor: Color {
        AcademicGrade.from(percentage: clampedValue).color
    }

    public var body: some View {
        VStack(spacing: 4) {
            if let label = label {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
            }
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: strokeWidth)
                Circle()
                    .trim(from: 0.0, to: CGFloat(clampedValue / 100.0))
                    .stroke(
                        gradeColor,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: clampedValue)
                Text(String(format: "%.1f%%", clampedValue))
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(width: size, height: size)
        }
    }
}
