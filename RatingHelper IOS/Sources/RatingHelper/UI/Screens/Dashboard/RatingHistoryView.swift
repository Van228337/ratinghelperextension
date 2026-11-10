import SwiftUI
import Charts

public struct RatingHistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var points: [RatingHistoryPoint] = []
    @State private var period: Period = .all
    @State private var selectedSubjectId: String? = nil
    @State private var selectedDate: Date?

    public enum Period: String, CaseIterable, Identifiable {
        case month = "Месяц"
        case quarter = "3 месяца"
        case all = "Всё время"
        public var id: String { rawValue }
        var days: Int? { self == .month ? 30 : (self == .quarter ? 90 : nil) }
    }

    private var availableSubjects: [Subject] {
        appState.subjects.filter { !$0.isHidden && $0.termNumber == appState.selectedTerm }
    }

    private var visiblePoints: [RatingHistoryPoint] {
        guard let days = period.days else { return points }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return points.filter { date(for: $0) >= cutoff }
    }

    private var deltaFromPrevious: Double? {
        guard visiblePoints.count >= 2 else { return nil }
        let last = visiblePoints[visiblePoints.count - 1].rating
        let prev = visiblePoints[visiblePoints.count - 2].rating
        return last - prev
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedSubjectId == nil ? "История общего рейтинга" : "История дисциплины")
                    .font(.headline)
                Spacer()
                Picker("Период", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }

            // Переключатель дисциплины (Общий рейтинг или конкретный предмет)
            if !availableSubjects.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedSubjectId = nil
                            Task { await load() }
                        } label: {
                            Text("Общий")
                                .font(.caption.weight(selectedSubjectId == nil ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedSubjectId == nil ? AppTheme.susuBluePrimary : Color(.secondarySystemBackground))
                                .foregroundColor(selectedSubjectId == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }

                        ForEach(availableSubjects) { sub in
                            Button {
                                selectedSubjectId = sub.disciplineId
                                Task { await load() }
                            } label: {
                                Text(sub.disciplineName)
                                    .font(.caption.weight(selectedSubjectId == sub.disciplineId ? .bold : .medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedSubjectId == sub.disciplineId ? AppTheme.susuBluePrimary : Color(.secondarySystemBackground))
                                    .foregroundColor(selectedSubjectId == sub.disciplineId ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            if visiblePoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line").font(.title2).foregroundStyle(.secondary)
                    Text("История пока не накоплена").font(.subheadline.weight(.medium))
                    Text("Точки рейтинга фиксируются автоматически при открытии журнала оценок.")
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "Текущий: %.2f%%", last.rating))
                                .font(.footnote.weight(.semibold))

                            if let delta = deltaFromPrevious {
                                HStack(spacing: 3) {
                                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    Text(String(format: "%@%.2f%% к прошлой точке", delta >= 0 ? "+" : "", delta))
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundColor(delta > 0 ? .green : (delta < 0 ? .red : .secondary))
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Обновлено:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(date(for: last), style: .date)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
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
        let userId = appState.effectiveUserId
        guard !userId.isEmpty else { return }
        points = await SupabaseService.shared.loadRatingHistory(
            userId: userId,
            term: appState.selectedTerm,
            subjectId: selectedSubjectId
        )
    }
}
