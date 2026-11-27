import SwiftUI

// MARK: - Оформление

enum TranscriptStyle {
    static let paper = Color.white
    static let ink = Color(red: 0.075, green: 0.086, blue: 0.110)
    static let inkSecondary = Color(red: 0.360, green: 0.392, blue: 0.443)
    static let inkTertiary = Color(red: 0.545, green: 0.573, blue: 0.616)
    static let rule = Color(red: 0.855, green: 0.871, blue: 0.890)
    static let ruleStrong = Color(red: 0.180, green: 0.200, blue: 0.235)
    static let accent = Color(red: 0.050, green: 0.300, blue: 0.600)
    static let surface = Color(red: 0.968, green: 0.973, blue: 0.980)
    static let negative = Color(red: 0.600, green: 0.180, blue: 0.180)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

enum TranscriptFormat {
    static func score(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if abs(rounded - rounded.rounded()) < 0.001 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.2f", rounded).replacingOccurrences(of: ".", with: ",")
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",") + " %"
    }

    static func delta(_ value: Double) -> String {
        if abs(value) < 0.005 { return "—" }
        let sign = value > 0 ? "+" : "−"
        return sign + String(format: "%.2f", abs(value)).replacingOccurrences(of: ".", with: ",")
    }

    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    static func gradeText(rating: Double, type: AssessmentType) -> String {
        if type == .zachet {
            return rating >= 59.01 ? "Зачтено" : "Не зачтено"
        }
        return AcademicGrade.from(percentage: rating).title
    }
}

private enum Metrics {
    static let columnSpacing: CGFloat = 14
    static let fact: CGFloat = 62
    static let rating: CGFloat = 72
    static let plan: CGFloat = 62
    static let delta: CGFloat = 52
    static let maxScore: CGFloat = 58
    static let number: CGFloat = 22
    static let assessment: CGFloat = 108
    static let grade: CGFloat = 132
}

// MARK: - Страница

struct TranscriptPageView: View {
    let document: TranscriptDocument
    let blocks: [AnyView]
    let isFirst: Bool
    let index: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isFirst {
                TranscriptDocumentHeader(document: document)
            } else {
                TranscriptContinuationHeader(document: document)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { item in
                    item.element
                }
            }

            Spacer(minLength: 0)

            TranscriptPageFooter(index: index, total: total)
        }
        .padding(.horizontal, 56)
        .padding(.top, 50)
        .padding(.bottom, 36)
        .frame(width: 794, height: 1123, alignment: .topLeading)
        .background(TranscriptStyle.paper)
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Шапка и подвал

struct TranscriptDocumentHeader: View {
    let document: TranscriptDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("RATING HELPER")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(2.2)
                    .foregroundColor(TranscriptStyle.accent)
                Spacer(minLength: 16)
                Text("Сформировано \(TranscriptFormat.date(document.generatedAt))")
                    .font(.system(size: 9.5))
                    .foregroundColor(TranscriptStyle.inkTertiary)
            }

            Text(document.title)
                .font(TranscriptStyle.serif(28, .semibold))
                .foregroundColor(TranscriptStyle.ink)
                .padding(.top, 16)

            Text("\(document.term) семестр · \(document.academicYear) учебный год")
                .font(.system(size: 12))
                .foregroundColor(TranscriptStyle.inkSecondary)
                .padding(.top, 6)

            HStack(alignment: .top, spacing: 28) {
                metaColumn("Студент", document.student)
                metaColumn("Группа", document.group)
                if !document.institute.isEmpty {
                    metaColumn("Институт", document.institute)
                }
            }
            .padding(.top, 20)

            Rectangle()
                .fill(TranscriptStyle.ruleStrong)
                .frame(height: 1)
                .padding(.top, 18)
        }
        .padding(.bottom, 20)
    }

    private func metaColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(0.9)
                .foregroundColor(TranscriptStyle.inkTertiary)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 11.5))
                .foregroundColor(TranscriptStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TranscriptContinuationHeader: View {
    let document: TranscriptDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(document.title)
                    .font(TranscriptStyle.serif(13, .semibold))
                    .foregroundColor(TranscriptStyle.ink)
                Text("продолжение")
                    .font(.system(size: 9.5))
                    .foregroundColor(TranscriptStyle.inkTertiary)
                Spacer(minLength: 0)
            }
            Rectangle()
                .fill(TranscriptStyle.rule)
                .frame(height: 0.5)
                .padding(.top, 10)
        }
        .padding(.bottom, 18)
    }
}

struct TranscriptPageFooter: View {
    let index: Int
    let total: Int

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(TranscriptStyle.rule)
                .frame(height: 0.5)
            HStack(alignment: .firstTextBaseline) {
                Text("Не является официальным документом университета")
                Spacer(minLength: 12)
                Text("Стр. \(index) из \(total)")
            }
            .font(.system(size: 8.5))
            .foregroundColor(TranscriptStyle.inkTertiary)
            .padding(.top, 8)
        }
    }
}

// MARK: - Таблица контрольных точек

struct TranscriptCheckpointsTableHeader: View {
    let showsPlan: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.columnSpacing) {
                label("Контрольная точка", width: nil, alignment: .leading)
                label(showsPlan ? "Факт" : "Балл", width: Metrics.fact, alignment: .trailing)
                if showsPlan {
                    label("План", width: Metrics.plan, alignment: .trailing)
                    label("Δ", width: Metrics.delta, alignment: .trailing)
                }
                label("Макс", width: Metrics.maxScore, alignment: .trailing)
            }
            .padding(.bottom, 6)

            Rectangle()
                .fill(TranscriptStyle.ruleStrong)
                .frame(height: 0.7)
        }
    }

    private func label(_ text: String, width: CGFloat?, alignment: Alignment) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .semibold))
            .tracking(0.7)
            .foregroundColor(TranscriptStyle.inkSecondary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }
}

struct TranscriptCheckpointRow: View {
    let checkpoint: TranscriptCheckpoint
    let showsPlan: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.columnSpacing) {
                Text(checkpoint.title)
                    .font(.system(size: 12))
                    .foregroundColor(TranscriptStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                number(TranscriptFormat.score(checkpoint.fact), width: Metrics.fact)

                if showsPlan {
                    number(
                        checkpoint.planned.map(TranscriptFormat.score) ?? "—",
                        width: Metrics.plan,
                        color: TranscriptStyle.accent
                    )

                    if let delta = checkpoint.delta, checkpoint.isChanged {
                        Text(TranscriptFormat.delta(delta))
                            .font(.system(size: 11.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(delta > 0 ? TranscriptStyle.accent : TranscriptStyle.negative)
                            .frame(width: Metrics.delta, alignment: .trailing)
                    } else {
                        Text("—")
                            .font(.system(size: 11.5))
                            .foregroundColor(TranscriptStyle.inkTertiary)
                            .frame(width: Metrics.delta, alignment: .trailing)
                    }
                }

                number(
                    TranscriptFormat.score(checkpoint.maxScore),
                    width: Metrics.maxScore,
                    color: TranscriptStyle.inkSecondary
                )
            }
            .padding(.vertical, 7)

            Rectangle()
                .fill(TranscriptStyle.rule)
                .frame(height: 0.5)
        }
    }

    private func number(_ text: String, width: CGFloat, color: Color = TranscriptStyle.ink) -> some View {
        Text(text)
            .font(.system(size: 12))
            .monospacedDigit()
            .foregroundColor(color)
            .frame(width: width, alignment: .trailing)
    }
}

// MARK: - Заголовки дисциплин

struct TranscriptDisciplineHeader: View {
    let discipline: TranscriptDiscipline
    let isFirst: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isFirst {
                Rectangle()
                    .fill(TranscriptStyle.rule)
                    .frame(height: 0.5)
                    .padding(.top, 22)
                    .padding(.bottom, 16)
            }

            Text(discipline.name)
                .font(TranscriptStyle.serif(15, .semibold))
                .foregroundColor(TranscriptStyle.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if discipline.assessmentType != .unknown {
                    Text(discipline.assessmentType.rawValue)
                }
                if !discipline.instructor.isEmpty {
                    Text(discipline.instructor)
                }
            }
            .font(.system(size: 10.5))
            .foregroundColor(TranscriptStyle.inkSecondary)
            .padding(.top, 5)
            .padding(.bottom, 10)
        }
        .padding(.top, isFirst ? 4 : 0)
    }
}

struct TranscriptDisciplineContinuation: View {
    let discipline: TranscriptDiscipline

    var body: some View {
        Text("\(discipline.name) · продолжение")
            .font(TranscriptStyle.serif(12, .semibold))
            .foregroundColor(TranscriptStyle.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}

struct TranscriptCheckpointsUnavailableNote: View {
    var body: some View {
        Text("Контрольные точки недоступны — показан только текущий рейтинг дисциплины.")
            .font(.system(size: 10.5))
            .foregroundColor(TranscriptStyle.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
    }
}

// MARK: - Итоги

struct TranscriptRatingSummary: View {
    let discipline: TranscriptDiscipline

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            cell(
                label: "Текущий рейтинг",
                rating: discipline.factRating,
                gradeText: TranscriptFormat.gradeText(
                    rating: discipline.factRating,
                    type: discipline.assessmentType
                ),
                delta: discipline.ratingDelta
            )

            if let plannedRating = discipline.plannedRating {
                Rectangle()
                    .fill(TranscriptStyle.rule)
                    .frame(width: 0.5)
                    .padding(.vertical, 2)

                cell(
                    label: "Прогноз по плану",
                    rating: plannedRating,
                    gradeText: TranscriptFormat.gradeText(
                        rating: plannedRating,
                        type: discipline.assessmentType
                    ),
                    delta: nil
                )
                .padding(.leading, 22)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(TranscriptStyle.surface)
        .padding(.top, 14)
    }

    private func cell(label: String, rating: Double, gradeText: String, delta: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(0.9)
                .foregroundColor(TranscriptStyle.inkTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(TranscriptFormat.percent(rating))
                    .font(TranscriptStyle.serif(21, .semibold))
                    .monospacedDigit()
                    .foregroundColor(TranscriptStyle.ink)
                Text(gradeText)
                    .font(.system(size: 11))
                    .foregroundColor(TranscriptStyle.inkSecondary)
            }

            if let delta, abs(delta) > 0.005 {
                Text("Изменение: \(TranscriptFormat.delta(delta)) п.п.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(delta > 0 ? TranscriptStyle.accent : TranscriptStyle.negative)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TranscriptDisciplineFooterRow: View {
    let discipline: TranscriptDiscipline

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Текущий рейтинг")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(TranscriptStyle.inkSecondary)

            Spacer(minLength: 12)

            Text(TranscriptFormat.percent(discipline.factRating))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(TranscriptStyle.ink)

            Text(TranscriptFormat.gradeText(rating: discipline.factRating, type: discipline.assessmentType))
                .font(.system(size: 10.5))
                .foregroundColor(TranscriptStyle.inkSecondary)
                .frame(minWidth: 96, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(TranscriptStyle.surface)
        .padding(.top, 10)
    }
}

// MARK: - Общий рейтинг

struct TranscriptOverviewSummary: View {
    let average: Double?
    let count: Int
    let debtCount: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("СРЕДНИЙ РЕЙТИНГ ПО СЕМЕСТРУ")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(0.9)
                    .foregroundColor(TranscriptStyle.inkTertiary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(average.map(TranscriptFormat.percent) ?? "—")
                        .font(TranscriptStyle.serif(30, .semibold))
                        .monospacedDigit()
                        .foregroundColor(TranscriptStyle.ink)
                    if let average {
                        Text(AcademicGrade.from(percentage: average).title)
                            .font(.system(size: 11))
                            .foregroundColor(TranscriptStyle.inkSecondary)
                    }
                }
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 4) {
                Text("Дисциплин: \(count)")
                Text(debtCount > 0 ? "С задолженностью: \(debtCount)" : "Задолженностей нет")
            }
            .font(.system(size: 10.5))
            .foregroundColor(TranscriptStyle.inkSecondary)
        }
        .padding(.vertical, 6)
        .padding(.bottom, 20)
    }
}

struct TranscriptOverviewTableHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.columnSpacing) {
                label("№", width: Metrics.number, alignment: .leading)
                label("Дисциплина", width: nil, alignment: .leading)
                label("Аттестация", width: Metrics.assessment, alignment: .leading)
                label("Рейтинг", width: Metrics.rating, alignment: .trailing)
                label("Оценка", width: Metrics.grade, alignment: .trailing)
            }
            .padding(.bottom, 6)

            Rectangle()
                .fill(TranscriptStyle.ruleStrong)
                .frame(height: 0.7)
        }
    }

    private func label(_ text: String, width: CGFloat?, alignment: Alignment) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .semibold))
            .tracking(0.7)
            .foregroundColor(TranscriptStyle.inkSecondary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }
}

struct TranscriptOverviewRow: View {
    let index: Int
    let discipline: TranscriptDiscipline

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.columnSpacing) {
                Text("\(index)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundColor(TranscriptStyle.inkTertiary)
                    .frame(width: Metrics.number, alignment: .leading)

                Text(discipline.name)
                    .font(.system(size: 12))
                    .foregroundColor(TranscriptStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(discipline.assessmentType == .unknown ? "—" : discipline.assessmentType.rawValue)
                    .font(.system(size: 10.5))
                    .foregroundColor(TranscriptStyle.inkSecondary)
                    .frame(width: Metrics.assessment, alignment: .leading)

                Text(TranscriptFormat.percent(discipline.factRating))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(TranscriptStyle.ink)
                    .frame(width: Metrics.rating, alignment: .trailing)

                Text(TranscriptFormat.gradeText(rating: discipline.factRating, type: discipline.assessmentType))
                    .font(.system(size: 10.5))
                    .foregroundColor(TranscriptStyle.inkSecondary)
                    .frame(width: Metrics.grade, alignment: .trailing)
            }
            .padding(.vertical, 8)

            Rectangle()
                .fill(TranscriptStyle.rule)
                .frame(height: 0.5)
        }
    }
}

struct TranscriptEmptyNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundColor(TranscriptStyle.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 12)
    }
}
