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

    private var allGradedEntries: [CheckpointItem] {
        guard let j = journal else { return [] }
        return j.allContinuousAssignments
    }

    private var ratingResult: RatingResult {
        guard let j = journal else {
            let eval = AcademicEvaluation.evaluate(percentage: 0, assessmentType: subject.assessmentType)
            return RatingResult(currentControlRating: 0, finalRating: 0, grade: .unsatisfactory, evaluation: eval, subtext: "", totalWeight: 0)
        }
        let bonusContribution = bonusEnabled ? (
            j.bonusInfo.known ? (bonusPoints * j.bonusInfo.percentPerPoint) : bonusPoints
        ) : 0.0

        return RatingCalculator.compute(
            entries: allGradedEntries,
            scores: scores,
            bonus: bonusContribution,
            isExam: isExam,
            examScore: examScore,
            assessmentType: subject.assessmentType
        )
    }

    private var targetGoalResult: TargetGoalResult {
        guard let j = journal else { return .allCompleted }
        let bonusContribution = bonusEnabled ? (
            j.bonusInfo.known ? (bonusPoints * j.bonusInfo.percentPerPoint) : bonusPoints
        ) : 0.0

        return TargetCalculator.computeGoal(
            target: selectedTarget,
            entries: allGradedEntries,
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
            entries: allGradedEntries,
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
                    // Checkpoint change notifications banner
                    if !appState.activeCheckpointNotices.isEmpty {
                        checkpointNoticesBanner
                    }

                    // Draft active banner
                    if appState.activeDraft != nil {
                        draftBanner
                    }

                    // Offline mode banner
                    if appState.isOfflineMode {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash")
                                .font(.caption2)
                            Text("Офлайн-режим: показаны сохранённые баллы")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    }

                    // Main Rating Grade Card
                    gradeCard

                    // Range Forecast
                    if appState.settings.rangeForecast {
                        RangeForecastView(forecast: rangeForecast, assessmentType: subject.assessmentType)
                            .padding(.horizontal)
                    }

                    // Target Goal Calculator
                    if appState.settings.targetCalc {
                        TargetGoalView(
                            result: targetGoalResult,
                            selectedTarget: selectedTarget,
                            assessmentType: subject.assessmentType,
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
                                for i in 0..<allGradedEntries.count {
                                    if allGradedEntries[i].current == 0 || (i < scores.count && scores[i] == 0) {
                                        if i < scores.count {
                                            scores[i] = allGradedEntries[i].max
                                        }
                                    }
                                }
                            },
                            onAllMax: {
                                for i in 0..<allGradedEntries.count {
                                    if i < scores.count {
                                        scores[i] = allGradedEntries[i].max
                                    }
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

                    // 1. Current Control Checkpoints Section
                    if !j.currentControl.isEmpty {
                        checkpointsSection(
                            title: "Текущий контроль",
                            icon: "pencil.and.list.clipboard",
                            items: j.currentControl,
                            globalStartIndex: 0
                        )
                    }

                    // 2. Laboratory Works Section
                    if !j.labs.isEmpty {
                        checkpointsSection(
                            title: "Лабораторные работы",
                            icon: "flask.fill",
                            items: j.labs,
                            globalStartIndex: j.currentControl.count
                        )
                    }

                    // 3. Course Works / Projects Section
                    if !j.courseWorksOrProjects.isEmpty {
                        checkpointsSection(
                            title: "Курсовая работа",
                            icon: "doc.text.fill",
                            items: j.courseWorksOrProjects,
                            globalStartIndex: j.currentControl.count + j.labs.count
                        )
                    }

                    // 4. Other sections (Bonuses, Attestation)
                    if !j.bonuses.isEmpty {
                        readOnlySection(title: "Официальные бонусы", icon: "star.fill", items: j.bonuses)
                    }
                    if !j.attestation.isEmpty {
                        readOnlySection(title: "Промежуточная аттестация", icon: "graduationcap.fill", items: j.attestation)
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
                .environmentObject(appState)
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
        let totalCount = allGradedEntries.count

        // If there is an active draft plan, restore it
        if let draft = appState.activeDraft, draft.scores.count == totalCount {
            self.scores = draft.scores
            self.bonusPoints = draft.bonus
            self.bonusEnabled = draft.bonus > 0
            self.isExam = draft.isExam
            self.examScore = draft.examScore
        } else {
            self.scores = allGradedEntries.map { $0.current }
            if j.bonusInfo.detectedPoints > 0 {
                self.bonusPoints = j.bonusInfo.detectedPoints
                self.bonusEnabled = true
            }
        }
    }

    private func resetToFact() {
        guard journal != nil else { return }
        scores = allGradedEntries.map { $0.current }
        isExam = false
        examScore = 60.0
        bonusEnabled = false
        bonusPoints = 0.0
        Task {
            await appState.revertPlan()
        }
    }

    // MARK: - Subviews
    private var checkpointNoticesBanner: some View {
        VStack(spacing: 8) {
            ForEach(appState.activeCheckpointNotices) { notice in
                checkpointNoticeRow(notice)
            }
        }
        .padding(.horizontal)
    }

    private func checkpointNoticeRow(_ notice: CheckpointChangeNotice) -> some View {
        let isWeight = notice.isWeightChange
        let themeColor: Color = isWeight ? .orange : .red

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isWeight ? "scalemass.fill" : "arrow.down.circle.fill")
                .foregroundColor(themeColor)
                .font(.title3)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(isWeight ? "Изменение параметров точки" : "Снижение балла")
                    .font(.caption.weight(.bold))
                    .foregroundColor(themeColor)

                Text(notice.message)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(formatNoticeDate(notice.detectedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await appState.dismissCheckpointNotice(id: notice.id)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.7))
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.opacity(0.35), lineWidth: 1)
        )
    }

    private func formatNoticeDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM в HH:mm"
        return f.string(from: date)
    }

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
                        .foregroundColor(ratingResult.evaluation.color)
                }

                Spacer()

                GradeBadgeView(grade: ratingResult.grade, evaluation: ratingResult.evaluation)
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

    private func checkpointsSection(title: String, icon: String, items: [CheckpointItem], globalStartIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.susuBluePrimary)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("Работ: \(items.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(0..<items.count, id: \.self) { idx in
                    let entry = items[idx]
                    let globalIdx = globalStartIndex + idx
                    let current = globalIdx < scores.count ? scores[globalIdx] : entry.current

                    let notice = appState.activeCheckpointNotices.first(where: { $0.checkpointTitle == entry.title })

                    CheckpointRowView(
                        entry: entry,
                        currentScore: current,
                        onScoreChange: { newScore in
                            if globalIdx < scores.count {
                                scores[globalIdx] = newScore
                            }
                        },
                        onOpenMaterials: {
                            selectedCheckpointForMaterials = entry
                        },
                        onAddTask: {
                            selectedCheckpointForTask = entry
                            showingAddTaskSheet = true
                        },
                        communityMaterialsEnabled: appState.settings.communityMaterials,
                        notice: notice
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)

                    if idx < items.count - 1 {
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

    private func readOnlySection(title: String, icon: String, items: [CheckpointItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
            }
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
