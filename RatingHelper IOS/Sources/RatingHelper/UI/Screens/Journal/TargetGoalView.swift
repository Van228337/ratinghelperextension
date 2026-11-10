import SwiftUI

public struct TargetGoalView: View {
    public let result: TargetGoalResult
    public let selectedTarget: Double
    public var assessmentType: AssessmentType = .unknown
    public let onSelectTarget: (Double) -> Void
    public let onApplyScores: ([Double]) -> Void
    public let onApplyExam: (Double) -> Void

    private var targets: [(title: String, val: Double)] {
        if assessmentType == .zachet {
            return [("Зачёт 59%", 59.01)]
        } else {
            return [
                ("Удовл (3) 59%", 59.01),
                ("Хорошо (4) 74%", 74.01),
                ("Отлично (5) 84%", 84.01)
            ]
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🎯 Калькулятор целей:")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(targets, id: \.val) { t in
                    Button {
                        onSelectTarget(t.val)
                    } label: {
                        Text(t.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedTarget == t.val ? Color.blue : Color(.secondarySystemBackground))
                            .foregroundColor(selectedTarget == t.val ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }

            // Calculation result hint
            Group {
                switch result {
                case .alreadyAchieved(let current):
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Цель уже достигнута! Рейтинг: **\(String(format: "%.2f", current))%**")
                            .font(.footnote)
                    }
                case .unreachable(let maxPossible):
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Недостижимо: максимальный потенциал с учётом сданного — **\(String(format: "%.1f", maxPossible))%**")
                            .font(.footnote)
                    }
                case .allCompleted:
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.secondary)
                        Text("Все работы уже оценены. Изменяйте баллы в строках ниже для моделирования.")
                            .font(.footnote)
                    }
                case .neededExam(let neededScore, let currentControl):
                    VStack(alignment: .leading, spacing: 6) {
                        Text("При текущем контроле **\(String(format: "%.1f", currentControl))%**, на экзамене необходимо набрать не менее **\(String(format: "%.1f", neededScore))%**.")
                            .font(.footnote)
                        Button("Поставить балл за экзамен (\(Int(ceil(neededScore))))") {
                            onApplyExam(ceil(neededScore))
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                case .neededControl(let neededAvgPct, let remainingCount, let suggested):
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Оставшиеся **\(remainingCount)** работ нужно сдать в среднем на **\(String(format: "%.1f", neededAvgPct))%**.")
                            .font(.footnote)
                        Button("Заполнить баллы на остаток") {
                            onApplyScores(suggested)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}
