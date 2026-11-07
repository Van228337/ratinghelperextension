import SwiftUI

public struct JournalView: View {
    @EnvironmentObject private var appState: AppState
    public let subject: Subject

    @State private var scores: [Double] = []
    @State private var bonusEnabled: Bool = false
    @State private var bonusPoints: Double = 0.0
    @State private var isExam: Bool = false
    @State private var examScore: Double = 60.0
    @State private var selectedTarget: Double = 84.01
    @State private var isPlanSaved: Bool = false

    // Sheets
    @State private var showingReviewsSheet: Bool = false
    @State private var selectedCheckpointForMaterials: CheckpointItem? = nil
    @State private var showingAddTaskSheet: Bool = false
    @State private var selectedCheckpointForTask: CheckpointItem? = nil

    private var journal: JournalData? {
        appState.currentJournal
    }

    private var ratingResult: RatingResult {
        guard let j = journal else {
            return RatingResult(currentControlRating: 0, finalRating: 0, grade: .unsatisfactory, subtext: "", totalWeight: 0)
        }
        let bonusContribution = bonusEnabled ? (
            j.bonusInfo.known ? (bonusPoints * j.bonusInfo.percentPerPoint) : bonusPoints
        ) : 0.0

        return RatingCalculator.compute(
            entries: j.currentControl,
            scores: scores,
            bonus: bonusContribution,
            isExam: isExam,
            examScore: examScore
        )
    }

    private var targetGoalResult: TargetGoalResult {
        guard let j = journal else { return .allCompleted }
        let bonusContribution = bonusEnabled ? (
            j.bonusInfo.known ? (bonusPoints * j.bonusInfo.percentPerPoint) : bonusPoints
        ) : 0.0

        return TargetCalculator.computeGoal(
            target: selectedTarget,
            entries: j.currentControl,
            currentScores: scores,
            bonus: bonusContribution,
            isExam: isExam
        )
    }

    private var rangeForecast: RangeForecastResult {
        guard let j = journal else { return RangeForecastResult(minRating: 0, currentRating: 0, maxRating: 0) }
        let bonusContribution = bonusEnabled ? (
            j.bonusInfo.known ? (bonusPoints * j.bonusInfo.percentPerPoint) : bonusPoints
        ) : 0.0

        return RangeForecaster.computeForecast(
            entries: j.currentControl,
            currentRating: ratingResult.finalRating,
            bonus: bonusContribution
        )
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                headerCard

                if appState.isLoading && journal == nil {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Загрузка журнала оценок...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else if let j = journal {
                    // Draft active banner
                    if appState.activeDraft != nil {
                        draftBanner
                    }

                    // Main Rating Grade Card
                    gradeCard

                    // Range Forecast
                    if appState.settings.rangeForecast {
                        RangeForecastView(forecast: rangeForecast)
                            .padding(.horizontal)
                    }

                    // Target Goal Calculator
                    if appState.settings.targetCalc {
                        TargetGoalView(
                            result: targetGoalResult,
                            selectedTarget: selectedTarget,
                            onSelectTarget: { selectedTarget = $0 },
                            onApplyScores: { applied in
                                scores = applied
                            },
                            onApplyExam: { examScore = $0 }
                        )
                        .padding(.horizontal)
                    }

                    // Quick Actions
                    if appState.settings.quickActions {
                        SimulatorControlBar(
                            onRemainingMax: {
                                for i in 0..<j.currentControl.count {
                                    if j.currentControl[i].current == 0 || scores[i] == 0 {
                                        scores[i] = j.currentControl[i].max
                                    }
                                }
                            },
                            onAllMax: {
                                for i in 0..<j.currentControl.count {
                                    scores[i] = j.currentControl[i].max
                                }
                            },
                            onReset: {
                                resetToFact()
                            },
                            onSavePlan: {
                                Task {
                                    await appState.savePlan(
                                        scores: scores,
                                        bonus: bonusPoints,
                                        isExam: isExam,
                                        examScore: examScore
                                    )
                                    isPlanSaved = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        isPlanSaved = false
                                    }
                                }
                            },
                            isPlanSaved: isPlanSaved
                        )
                    }

                    // Exam Mode Card
                    if appState.settings.examMode {
                        examCard
                    }

                    // Bonus Points Card
                    bonusCard

                    // Current Control Checkpoints Section
                    checkpointsSection(j)

                    // Other sections (Bonuses, Attestation)
                    if !j.bonuses.isEmpty {
                        readOnlySection(title: "Официальные бонусы", items: j.bonuses)
                    }
                    if !j.attestation.isEmpty {
                        readOnlySection(title: "Промежуточная аттестация", items: j.attestation)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(subject.disciplineName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Кнопка быстрого добавления задачи по этому предмету
                Button {
                    selectedCheckpointForTask = nil
                    showingAddTaskSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.square.dashed")
                        Text("В план")
                            .font(.caption.weight(.medium))
                    }
                }

                // Кнопка перехода к отзывам о преподавателе
                if !subject.instructor.isEmpty && appState.settings.teacherReviews {
                    Button {
                        showingReviewsSheet = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Отзывы")
                                .font(.caption.weight(.medium))
                        }
                    }
                }
            }
        }
        .task {
            await appState.loadJournal(for: subject)
            syncInitialScores()
        }
        .sheet(isPresented: $showingReviewsSheet) {
            TeacherReviewsView(teacherName: subject.instructor, subjectName: subject.disciplineName, subjectId: subject.disciplineId)
        }
        .sheet(item: $selectedCheckpointForMaterials) { checkpoint in
            MaterialsView(checkpoint: checkpoint, subjectId: subject.disciplineId, teacherName: subject.instructor)
        }
        .sheet(isPresented: $showingAddTaskSheet) {
            CreateTaskSheet(prefilledSubject: subject, prefilledCheckpoint: selectedCheckpointForTask)
        }
    }

    private func syncInitialScores() {
        guard let j = appState.currentJournal else { return }

        // If there is an active draft plan, restore it
        if let draft = appState.activeDraft, draft.scores.count == j.currentControl.count {
            self.scores = draft.scores
            self.bonusPoints = draft.bonus
            self.bonusEnabled = draft.bonus > 0
            self.isExam = draft.isExam
            self.examScore = draft.examScore
        } else {
            self.scores = j.currentControl.map { $0.current }
            if j.bonusInfo.detectedPoints > 0 {
                self.bonusPoints = j.bonusInfo.detectedPoints
                self.bonusEnabled = true
            }
        }
    }

    private func resetToFact() {
        guard let j = journal else { return }
        scores = j.currentControl.map { $0.current }
        isExam = false
        examScore = 60.0
        bonusEnabled = false
        bonusPoints = 0.0
        Task {
            await appState.revertPlan()
        }
    }

    // MARK: - Subviews
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AssessmentBadgeView(type: subject.assessmentType)
                Spacer()
                if !subject.instructor.isEmpty {
                    Text("👨‍🏫 \(subject.instructor)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal)
    }

    private var draftBanner: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundColor(.orange)
            Text("Применён сохранённый план моделирования")
                .font(.caption.weight(.medium))
                .foregroundColor(.orange)
            Spacer()
            Button("Сброс") {
                resetToFact()
            }
            .font(.caption.weight(.bold))
            .foregroundColor(.orange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var gradeCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Рейтинг БРС")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f%%", ratingResult.finalRating))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(ratingResult.grade.color)
                }

                Spacer()

                GradeBadgeView(grade: ratingResult.grade)
            }

            Divider()

            HStack {
                Text(ratingResult.subtext)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var examCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isExam) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Учёт сдачи экзамена / дифзачёта")
                        .font(.subheadline.weight(.semibold))
                    Text("Формула: 60% текущий контроль + 40% экзамен")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if isExam {
                HStack(spacing: 14) {
                    Text("Балл:")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)

                    Slider(value: $examScore, in: 0...100, step: 1)
                        .tint(AppTheme.susuBluePrimary)

                    Text("\(Int(examScore))%")
                        .font(.headline.weight(.bold))
                        .frame(width: 48, alignment: .trailing)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private var bonusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $bonusEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Учитывать бонусы")
                        .font(.subheadline.weight(.semibold))
                    if let j = journal, j.bonusInfo.known {
                        Text("Коэффициент: 1 бонусный балл = +\(String(format: "%.2f", j.bonusInfo.percentPerPoint))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("1 балл = +1.0% к итоговому рейтингу")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if bonusEnabled {
                HStack {
                    Text("Бонусные баллы:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Stepper(value: $bonusPoints, in: 0...50, step: 0.5) {
                        Text(String(format: "%.1f б.", bonusPoints))
                            .font(.subheadline.weight(.bold))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private func checkpointsSection(_ j: JournalData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Текущий контроль")
                    .font(.headline)
                Spacer()
                Text("Работ: \(j.currentControl.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(0..<j.currentControl.count, id: \.self) { idx in
                    let entry = j.currentControl[idx]
                    let current = idx < scores.count ? scores[idx] : entry.current

                    CheckpointRowView(
                        entry: entry,
                        currentScore: current,
                        onScoreChange: { newScore in
                            if idx < scores.count {
                                scores[idx] = newScore
                            }
                        },
                        onOpenMaterials: {
                            selectedCheckpointForMaterials = entry
                        },
                        onAddTask: {
                            selectedCheckpointForTask = entry
                            showingAddTaskSheet = true
                        },
                        communityMaterialsEnabled: appState.settings.communityMaterials
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)

                    if idx < j.currentControl.count - 1 {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }

    private func readOnlySection(title: String, items: [CheckpointItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack {
                        Text(item.title)
                            .font(.subheadline)
                        Spacer()
                        Text("\(String(format: "%g", item.current)) / \(String(format: "%g", item.max))")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }
}
