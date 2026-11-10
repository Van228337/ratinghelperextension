import SwiftUI

public struct SemesterDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var history: [SemesterHistoryItem] = []

    private var averageRating: Double {
        guard !history.isEmpty else { return 0.0 }
        let sum = history.reduce(0.0) { $0 + $1.rating }
        return sum / Double(history.count)
    }

    private var averageGrade: AcademicGrade {
        AcademicGrade.from(percentage: averageRating)
    }

    private var debtsCount: Int {
        history.filter { $0.rating < 59.01 }.count
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    VStack(spacing: 12) {
                        Text("Средний балл за семестр:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(String(format: "%.2f%%", averageRating))
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundColor(averageGrade.color)

                            GradeBadgeView(grade: averageGrade)
                        }

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "books.vertical.fill")
                                    .foregroundColor(.blue)
                                Text("Дисциплин: **\(history.count)**")
                                    .font(.caption)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(debtsCount > 0 ? .red : .green)
                                Text("Задолженностей: **\(debtsCount)**")
                                    .font(.caption)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    RatingHistoryView()
                        .padding(.horizontal)

                    // Subjects list
                    if history.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary)
                            Text("История семестра пуста")
                                .font(.headline)
                            Text("Открывайте предметы в журнале, и они автоматически сохранятся здесь для отслеживания общего рейтинга.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Учтённые предметы")
                                    .font(.headline)
                                Spacer()
                                Button("Очистить всё") {
                                    Task {
                                        await LocalStore.shared.clearSemesterHistory()
                                        history = []
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(history) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .font(.subheadline.weight(.medium))
                                                .lineLimit(2)
                                            if !item.teacher.isEmpty {
                                                Text("👨‍🏫 \(item.teacher)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        let type = AssessmentType.parse(item.assessmentType)
                                        let eval = AcademicEvaluation.evaluate(percentage: item.rating, assessmentType: type)
                                        GradeBadgeView(
                                            grade: AcademicGrade.from(percentage: item.rating),
                                            evaluation: eval,
                                            customText: "\(String(format: "%.1f", item.rating))%",
                                            small: true
                                        )

                                        Button {
                                            Task {
                                                await LocalStore.shared.removeSemesterHistoryItem(name: item.name)
                                                history.removeAll(where: { $0.name == item.name })
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.body)
                                                .foregroundColor(.secondary.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.leading, 6)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)

                                    if item.id != history.last?.id {
                                        Divider()
                                            .padding(.leading, 14)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Сводка семестра")
            .task {
                history = await LocalStore.shared.loadSemesterHistory()
            }
        }
    }
}
