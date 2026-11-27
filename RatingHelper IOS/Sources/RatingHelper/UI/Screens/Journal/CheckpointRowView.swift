import SwiftUI

public struct CheckpointRowView: View {
    public let entry: CheckpointItem
    public let currentScore: Double
    public let onScoreChange: (Double) -> Void
    public let onOpenMaterials: () -> Void
    public let onAddTask: () -> Void
    public var communityMaterialsEnabled: Bool = true
    public var notice: CheckpointChangeNotice? = nil

    @State private var showingScoreSheet: Bool = false

    private var percentage: Double {
        entry.max > 0 ? (currentScore / entry.max) * 100.0 : 0.0
    }

    private var scoreColor: Color {
        if percentage < 33.33 {
            return AppTheme.dangerRed
        } else if percentage < 66.66 {
            return AppTheme.warningOrange
        } else {
            return AppTheme.successGreen
        }
    }

    public init(
        entry: CheckpointItem,
        currentScore: Double,
        onScoreChange: @escaping (Double) -> Void,
        onOpenMaterials: @escaping () -> Void,
        onAddTask: @escaping () -> Void,
        communityMaterialsEnabled: Bool = true,
        notice: CheckpointChangeNotice? = nil
    ) {
        self.entry = entry
        self.currentScore = currentScore
        self.onScoreChange = onScoreChange
        self.onOpenMaterials = onOpenMaterials
        self.onAddTask = onAddTask
        self.communityMaterialsEnabled = communityMaterialsEnabled
        self.notice = notice
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Заголовок контрольной точки и действия
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let n = notice {
                        HStack(spacing: 4) {
                            Image(systemName: n.isWeightChange ? "scalemass.fill" : "arrow.down.circle.fill")
                            Text(n.message)
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundColor(n.isWeightChange ? .orange : .red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(n.isWeightChange ? Color.orange.opacity(0.12) : Color.red.opacity(0.12))
                        .cornerRadius(4)
                    }

                    HStack(spacing: 6) {
                        Text("Вес: \(String(format: "%.2f", entry.weight))")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if entry.current > 0 {
                            Text("• Факт: \(String(format: "%g", entry.current))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Действия: "В план" (Создать задачу) и "Материалы"
                HStack(spacing: 6) {
                    // Кнопка создания задачи
                    Button {
                        onAddTask()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus.square.dashed")
                                .font(.system(size: 12))
                            Text("В план")
                                .font(.caption2.weight(.medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.susuBluePrimary.opacity(0.12))
                        .foregroundColor(AppTheme.susuBluePrimary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Кнопка материалов
                    if communityMaterialsEnabled {
                        Button {
                            onOpenMaterials()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 11))
                                if entry.materialsCount > 0 {
                                    Text("\(entry.materialsCount)")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(entry.materialsCount > 0 ? Color.blue.opacity(0.15) : Color(uiColor: .tertiarySystemFill))
                            .foregroundColor(entry.materialsCount > 0 ? .blue : .secondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Индикатор прогресса выполнения контрольной точки
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(scoreColor)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(percentage / 100.0))), height: 5)
                }
            }
            .frame(height: 5)

            // Панель выставления балла с крупными кнопками (+ / - не менее 44x44 pt)
            HStack(spacing: 12) {
                Spacer()

                // Кнопка Минус (область нажатия 44x44 pt)
                Button {
                    let step = entry.max <= 10 ? 0.5 : 1.0
                    let newScore = max(0.0, currentScore - step)
                    onScoreChange(newScore)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(uiColor: .secondarySystemFill))
                            .frame(width: 44, height: 44)
                        Image(systemName: "minus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                // Индикатор балла (нажатие открывает удобный модальный ввод)
                Button {
                    showingScoreSheet = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%g", currentScore))
                            .font(.title3.weight(.bold))
                            .foregroundColor(scoreColor)
                        Text("/ \(String(format: "%g", entry.max))")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 80, minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(Color(uiColor: .secondarySystemFill))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                // Кнопка Плюс (область нажатия 44x44 pt)
                Button {
                    let step = entry.max <= 10 ? 0.5 : 1.0
                    let newScore = min(entry.max, currentScore + step)
                    onScoreChange(newScore)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.susuBluePrimary.opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.susuBluePrimary)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingScoreSheet) {
            ScorePickerSheet(
                title: entry.title,
                maxScore: entry.max,
                initialScore: currentScore,
                onSave: { newScore in
                    onScoreChange(newScore)
                }
            )
            .presentationDetents([.fraction(0.45)])
        }
    }
}

// Удобный современный Sheet для ввода оценки (заменяет устаревший UIAlertController)
struct ScorePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let maxScore: Double
    let initialScore: Double
    let onSave: (Double) -> Void

    @State private var score: Double = 0.0
    @State private var scoreText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text("Максимум: \(String(format: "%g", maxScore)) баллов")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)

                // Поле ввода и крупный слайдер
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        TextField("0", text: $scoreText)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 120, height: 50)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .cornerRadius(12)
                            .onChange(of: scoreText) { _, newText in
                                let normalized = newText.replacingOccurrences(of: ",", with: ".")
                                if let val = Double(normalized) {
                                    score = min(maxScore, max(0.0, val))
                                }
                            }

                        Text("баллов")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $score, in: 0...max(0.1, maxScore), step: maxScore <= 10 ? 0.5 : 1.0)
                        .tint(AppTheme.susuBluePrimary)
                        .padding(.horizontal)
                        .onChange(of: score) { _, newVal in
                            scoreText = String(format: "%g", newVal)
                        }
                }

                // Быстрые пресеты
                HStack(spacing: 10) {
                    Button("0 баллов") {
                        setScore(0.0)
                    }
                    .buttonStyle(.bordered)

                    Button("50% (\(String(format: "%g", maxScore / 2)))") {
                        setScore(maxScore / 2.0)
                    }
                    .buttonStyle(.bordered)

                    Button("Макс (\(String(format: "%g", maxScore)))") {
                        setScore(maxScore)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.susuBluePrimary)
                }
                .font(.footnote.weight(.medium))

                Spacer()
            }
            .padding()
            .navigationTitle("Изменить балл")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(score)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                score = initialScore
                scoreText = String(format: "%g", initialScore)
            }
        }
    }

    private func setScore(_ val: Double) {
        let clamped = min(maxScore, max(0.0, val))
        score = clamped
        scoreText = String(format: "%g", clamped)
    }
}
