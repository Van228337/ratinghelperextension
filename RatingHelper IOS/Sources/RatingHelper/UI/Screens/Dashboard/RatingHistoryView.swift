import SwiftUI
import Charts

public struct RatingHistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var points: [RatingHistoryPoint] = []
    @State private var period: Period = .all
    @State private var selectedSubjectId: String? = nil
    @State private var selectedDate: Date?
    @State private var manuallySelectedPointId: String? = nil

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

    private var yDomain: ClosedRange<Double> {
        let ratings = visiblePoints.map(\.rating)
        guard !ratings.isEmpty else { return 0...100 }
        let minR = ratings.min() ?? 0.0
        let maxR = ratings.max() ?? 100.0

        // Разумные отступы вокруг минимума и максимума с кратностью 5%
        var lower = max(0.0, floor((minR - 6.0) / 5.0) * 5.0)
        var upper = min(100.0, ceil((maxR + 6.0) / 5.0) * 5.0)

        // Минимальный видимый диапазон шкалы — 20 баллов, чтобы график не скакал из-за долей процента
        if (upper - lower) < 20.0 {
            lower = max(0.0, lower - 8.0)
            upper = min(100.0, max(lower + 22.0, upper + 5.0))
        }
        return lower...upper
    }

    private var activeSelectedPoint: RatingHistoryPoint? {
        if let manId = manuallySelectedPointId, let p = visiblePoints.first(where: { $0.id == manId }) {
            return p
        }
        guard let selDate = selectedDate, !visiblePoints.isEmpty else { return nil }
        return visiblePoints.min(by: {
            abs(date(for: $0).timeIntervalSince(selDate)) < abs(date(for: $1).timeIntervalSince(selDate))
        })
    }

    private var deltaFromPrevious: Double? {
        guard visiblePoints.count >= 2 else { return nil }
        let last = visiblePoints[visiblePoints.count - 1].rating
        let prev = visiblePoints[visiblePoints.count - 2].rating
        return last - prev
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Заголовок и выбор периода
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedSubjectId == nil ? "История общего рейтинга" : "История дисциплины")
                        .font(.headline)
                    Text("Балльно-рейтинговая динамика (прямая интерполяция)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Picker("Период", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }

            // Переключатель дисциплины (Общий или конкретный предмет)
            if !availableSubjects.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedSubjectId = nil
                            manuallySelectedPointId = nil
                            selectedDate = nil
                            Task { await load() }
                        } label: {
                            Text("Общий")
                                .font(.caption.weight(selectedSubjectId == nil ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedSubjectId == nil ? AppTheme.susuBluePrimary : Color(.secondarySystemBackground))
                                .foregroundColor(selectedSubjectId == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }

                        ForEach(availableSubjects) { sub in
                            Button {
                                selectedSubjectId = sub.disciplineId
                                manuallySelectedPointId = nil
                                selectedDate = nil
                                Task { await load() }
                            } label: {
                                Text(sub.disciplineName)
                                    .font(.caption.weight(selectedSubjectId == sub.disciplineId ? .bold : .medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedSubjectId == sub.disciplineId ? AppTheme.susuBluePrimary : Color(.secondarySystemBackground))
                                    .foregroundColor(selectedSubjectId == sub.disciplineId ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            // Всплывающая плашка выбранной точки
            if let sel = activeSelectedPoint {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatFullDate(date(for: sel)))
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f%%", sel.rating))
                            .font(.title3.weight(.bold))
                            .foregroundColor(AcademicGrade.from(percentage: sel.rating).color)
                    }

                    Spacer()

                    GradeBadgeView(grade: AcademicGrade.from(percentage: sel.rating))

                    Button {
                        manuallySelectedPointId = nil
                        selectedDate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .scale))
            }

            // График
            if visiblePoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("История пока не накоплена")
                        .font(.subheadline.weight(.medium))
                    Text("Точки рейтинга фиксируются автоматически при открытии журнала оценок.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart {
                    ForEach(visiblePoints) { point in
                        // Прямая линейная линия без ложных изгибов
                        LineMark(
                            x: .value("Дата", date(for: point)),
                            y: .value("Рейтинг", point.rating)
                        )
                        .foregroundStyle(AppTheme.susuBluePrimary)
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        // Фоновый градиент под графиком
                        AreaMark(
                            x: .value("Дата", date(for: point)),
                            y: .value("Рейтинг", point.rating)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.susuBluePrimary.opacity(0.22), AppTheme.susuBluePrimary.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.linear)

                        // Точки на графике
                        PointMark(
                            x: .value("Дата", date(for: point)),
                            y: .value("Рейтинг", point.rating)
                        )
                        .foregroundStyle(activeSelectedPoint?.id == point.id ? Color.orange : AppTheme.susuBluePrimary)
                        .symbolSize(activeSelectedPoint?.id == point.id ? 80 : 35)
                    }

                    // Индикатор выбранной точки
                    if let sel = activeSelectedPoint {
                        RuleMark(x: .value("Выбрано", date(for: sel)))
                            .foregroundStyle(Color.orange.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                }
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .leading) { val in
                        AxisGridLine()
                        AxisTick()
                        if let d = val.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(d))%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { val in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .frame(height: 200)

                // Итоговая строка
                if let last = visiblePoints.last {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "Последний: %.2f%%", last.rating))
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
                            Text("Всего замеров: \(visiblePoints.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(date(for: last), style: .date)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }

                // Интерактивная лента точек (можно нажать на конкретную точку!)
                if visiblePoints.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(visiblePoints.suffix(8).reversed()) { pt in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        manuallySelectedPointId = pt.id
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(String(format: "%.1f%%", pt.rating))
                                            .font(.caption2.weight(.bold))
                                        Text(formatShortDate(date(for: pt)))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(activeSelectedPoint?.id == pt.id ? AppTheme.susuBluePrimary.opacity(0.2) : Color(.tertiarySystemFill))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    }
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

    private func formatFullDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy, HH:mm"
        return f.string(from: d)
    }

    private func formatShortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f.string(from: d)
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
