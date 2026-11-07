import SwiftUI
import Charts

public struct RatingHistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var points: [RatingHistoryPoint] = []
    @State private var period: Period = .all
    @State private var selectedDate: Date?

    public enum Period: String, CaseIterable, Identifiable {
        case month = "Месяц"
        case quarter = "3 месяца"
        case all = "Всё время"
        public var id: String { rawValue }
        var days: Int? { self == .month ? 30 : (self == .quarter ? 90 : nil) }
    }

    private var visiblePoints: [RatingHistoryPoint] {
        guard let days = period.days else { return points }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return points.filter { date(for: $0) >= cutoff }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("История общего рейтинга").font(.headline)
                Spacer()
                Picker("Период", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }

            if visiblePoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line").font(.title2).foregroundStyle(.secondary)
                    Text("История пока не накоплена").font(.subheadline.weight(.medium))
                    Text("Точки начинают сохраняться после установки этой версии приложения.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(visiblePoints) { point in
                    LineMark(x: .value("Дата", date(for: point)), y: .value("Рейтинг", point.rating))
                        .foregroundStyle(AppTheme.susuBluePrimary)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Дата", date(for: point)), y: .value("Рейтинг", point.rating))
                        .foregroundStyle(AppTheme.susuBluePrimary)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXSelection(value: $selectedDate)
                .frame(height: 190)

                if let last = visiblePoints.last {
                    HStack {
                        Text(String(format: "Последняя точка: %.2f%%", last.rating))
                        Spacer()
                        Text(date(for: last), style: .date)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task(id: appState.selectedTerm) { await load() }
    }

    private func date(for point: RatingHistoryPoint) -> Date {
        ISO8601DateFormatter().date(from: point.recordedAt) ?? .distantPast
    }

    private func load() async {
        guard let userId = KeychainHelper.shared.readString(key: "app_user_uuid") else { return }
        points = await SupabaseService.shared.loadRatingHistory(userId: userId, term: appState.selectedTerm)
    }
}
