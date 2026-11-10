import SwiftUI

public struct TeacherReviewsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    public let teacherName: String
    public let subjectName: String
    public let subjectId: String?

    @State private var reviews: [TeacherReview] = []
    @State private var teacherCard: TeacherCardData? = nil
    @State private var stats: TeacherStats?
    @State private var summary: TeacherSummary?
    @State private var userVotes: [String: String] = [:]
    @State private var selectedDisciplineFilter: String? = nil
    @State private var isLoading: Bool = true
    @State private var isGeneratingSummary: Bool = false
    @State private var showingAddReviewSheet: Bool = false

    public init(
        teacherName: String,
        subjectName: String,
        subjectId: String? = nil
    ) {
        self.teacherName = teacherName
        self.subjectName = subjectName
        self.subjectId = subjectId
    }

    private var teacherInitials: String {
        let parts = teacherName.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "ПР"
    }

    private var allTaughtDisciplines: [String] {
        var names = Set<String>()
        if !subjectName.isEmpty {
            names.insert(subjectName)
        }
        if let cardDisciplines = teacherCard?.disciplines {
            for d in cardDisciplines {
                if let n = d.disciplineName, !n.isEmpty {
                    names.insert(n)
                }
            }
        }
        for r in reviews {
            if let n = r.subjectName, !n.isEmpty {
                names.insert(n)
            }
        }

        // Подтягиваем все дисциплины из семестра студента, которые ведёт этот же преподаватель
        let surname = teacherName.split(separator: " ").first.map(String.init)?.lowercased() ?? ""
        if !surname.isEmpty {
            for sub in appState.subjects {
                let inst = sub.instructor.lowercased()
                if inst.contains(surname) && !sub.disciplineName.isEmpty {
                    names.insert(sub.disciplineName)
                }
            }
        }

        return Array(names).sorted()
    }

    private var filteredReviews: [TeacherReview] {
        if let filter = selectedDisciplineFilter, !filter.isEmpty {
            return reviews.filter { $0.subjectName == filter }
        }
        return reviews
    }

    private var activeStats: TeacherStats {
        if let s = TeacherStats.compute(from: filteredReviews) {
            return s
        }
        return stats ?? TeacherStats()
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Unified Teacher Profile Header
                    teacherProfileHeader

                    // Disciplines Filter Chips
                    if !allTaughtDisciplines.isEmpty {
                        disciplinesFilterBar
                    }

                    // Stats Card (Dynamically computed for selected discipline or overall)
                    statsCard(activeStats)

                    // AI Summary Card
                    aiSummaryCard

                    // Reviews List
                    reviewsSection
                }
                .padding(.vertical)
            }
            .background(AppTheme.background)
            .navigationTitle("Карточка преподавателя")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddReviewSheet = true
                    } label: {
                        Label("Написать", systemImage: "square.and.pencil")
                    }
                }
            }
            .task {
                await loadReviews()
            }
            .sheet(isPresented: $showingAddReviewSheet) {
                AddReviewSheet(
                    teacherName: teacherName,
                    subjectName: selectedDisciplineFilter ?? subjectName,
                    subjectId: subjectId
                ) {
                    Task { await loadReviews() }
                }
            }
        }
    }

    // MARK: - Subviews

    private var teacherProfileHeader: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.susuBluePrimary, AppTheme.susuAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Text(teacherInitials)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(teacherName)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let dept = teacherCard?.department, !dept.isEmpty {
                    Text(dept)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Image(systemName: "books.vertical.fill")
                        .font(.caption2)
                        .foregroundColor(AppTheme.susuBluePrimary)
                    Text("Дисциплин: \(allTaughtDisciplines.count)")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var disciplinesFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Все дисциплины (\(reviews.count))",
                    isSelected: selectedDisciplineFilter == nil
                ) {
                    selectedDisciplineFilter = nil
                }

                ForEach(allTaughtDisciplines, id: \.self) { disc in
                    let count = reviews.filter { $0.subjectName == disc }.count
                    FilterChip(
                        title: "\(disc) (\(count))",
                        isSelected: selectedDisciplineFilter == disc
                    ) {
                        if selectedDisciplineFilter == disc {
                            selectedDisciplineFilter = nil
                        } else {
                            selectedDisciplineFilter = disc
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func statsCard(_ s: TeacherStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let disc = selectedDisciplineFilter {
                Text("Статистика по предмету: \(disc)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppTheme.susuBluePrimary)
                    .padding(.horizontal, 4)
            }

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", s.avgDifficulty))
                        .font(.title2.weight(.bold))
                        .foregroundColor(AppTheme.warningOrange)
                    Text("Сложность / 5")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack(spacing: 4) {
                    Text("\(s.avtomatPct)%")
                        .font(.title2.weight(.bold))
                        .foregroundColor(AppTheme.successGreen)
                    Text("Даёт автомат")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack(spacing: 4) {
                    Text("\(s.attendancePct)%")
                        .font(.title2.weight(.bold))
                        .foregroundColor(AppTheme.susuBluePrimary)
                    Text("Строго к посещ.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(14)
        }
        .padding(.horizontal)
    }

    private var aiSummaryCard: some View {
        Group {
            if let sum = summary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("AI-выжимка отзывов", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.purple)
                        Spacer()
                        Text("на основе \(sum.reviewsCount) отзывов")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(sum.summaryText)
                        .font(.footnote)
                        .lineSpacing(3)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color.purple.opacity(0.08))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
            } else if isGeneratingSummary {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Нейросеть формирует сводку отзывов...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Отзывы и советы студентов")
                    .font(.headline)
                Spacer()
                Text("Показано: \(filteredReviews.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if isLoading && reviews.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if filteredReviews.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Отзывов пока нет")
                        .font(.subheadline.weight(.semibold))
                    Text(selectedDisciplineFilter != nil ? "По данной дисциплине ещё нет отзывов" : "Будьте первым, кто оставит совет по этому преподавателю!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredReviews) { r in
                        reviewCard(r)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func reviewCard(_ r: TeacherReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let subj = r.subjectName, !subj.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.caption2)
                        .foregroundColor(AppTheme.susuBluePrimary)
                    Text(subj)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }

            Text(r.text)
                .font(.subheadline)
                .foregroundColor(.primary)

            HStack(spacing: 6) {
                Text("📅 \(r.year) г.")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("• Сложность: \(r.difficulty)/5")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if r.givesAvtomat {
                    Text("• Автомат")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppTheme.successGreen)
                }

                if r.attendanceStrict {
                    Text("• Посещения")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppTheme.susuBluePrimary)
                }

                Spacer()

                // Vote buttons
                let vote = userVotes[r.id]
                HStack(spacing: 4) {
                    Button {
                        handleVote(r, isUpvote: true)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: vote == "up" ? "hand.thumbsup.fill" : "hand.thumbsup")
                            Text("\(r.likes)")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(vote == "up" ? AppTheme.successGreen : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(vote == "up" ? AppTheme.successGreen.opacity(0.15) : Color(uiColor: .tertiarySystemFill))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        handleVote(r, isUpvote: false)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: vote == "down" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            Text("\(r.dislikes)")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(vote == "down" ? AppTheme.dangerRed : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(vote == "down" ? AppTheme.dangerRed.opacity(0.15) : Color(uiColor: .tertiarySystemFill))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Data Loading & Actions

    private func loadReviews() async {
        isLoading = true

        // 1. Load teacher card with normalized disciplines
        if let card = await SupabaseService.shared.getTeacherCard(teacherName: teacherName) {
            self.teacherCard = card
        }

        // 2. Load reviews & stats
        let (revs, st) = await SupabaseService.shared.getTeacherReviews(teacherName: teacherName)
        self.reviews = revs
        self.stats = st
        self.summary = await SupabaseService.shared.getTeacherSummary(teacherName: teacherName)
        self.userVotes = await LocalStore.shared.loadReviewVotes()
        isLoading = false

        // 3. Auto generate summary if reviews exist but no summary yet
        if summary == nil && !revs.isEmpty {
            isGeneratingSummary = true
            if let newSum = await GroqModerationService.shared.generateTeacherSummary(teacherName: teacherName, reviews: revs) {
                await SupabaseService.shared.saveTeacherSummary(teacherName: teacherName, summaryText: newSum, count: revs.count)
                self.summary = TeacherSummary(teacherName: teacherName, summaryText: newSum, reviewsCount: revs.count)
            }
            isGeneratingSummary = false
        }
    }

    private func handleVote(_ r: TeacherReview, isUpvote: Bool) {
        let prevVote = userVotes[r.id]
        Task {
            do {
                let res = try await SupabaseService.shared.voteReview(reviewId: r.id, isUpvote: isUpvote, previousVote: prevVote)
                if let idx = reviews.firstIndex(where: { $0.id == r.id }) {
                    reviews[idx].likes = res.likes
                    reviews[idx].dislikes = res.dislikes
                }

                if (isUpvote && prevVote == "up") || (!isUpvote && prevVote == "down") {
                    userVotes.removeValue(forKey: r.id)
                    await LocalStore.shared.saveReviewVote(reviewId: r.id, vote: nil)
                } else {
                    let newVote = isUpvote ? "up" : "down"
                    userVotes[r.id] = newVote
                    await LocalStore.shared.saveReviewVote(reviewId: r.id, vote: newVote)
                }
            } catch {
                print("Vote error: \(error)")
            }
        }
    }
}
