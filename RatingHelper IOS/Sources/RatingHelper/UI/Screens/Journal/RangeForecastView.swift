import SwiftUI

public struct RangeForecastView: View {
    public let forecast: RangeForecastResult
    public var assessmentType: AssessmentType = .unknown

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Минимум")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f%%", forecast.minRating))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                Text("Текущий")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f%%", forecast.currentRating))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(AcademicEvaluation.evaluate(percentage: forecast.currentRating, assessmentType: assessmentType).color)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .trailing, spacing: 2) {
                Text("Максимум")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f%%", forecast.maxRating))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
