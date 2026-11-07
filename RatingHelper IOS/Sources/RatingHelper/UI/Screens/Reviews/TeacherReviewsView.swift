import SwiftUI

public struct TeacherReviewsView: View {
    @Environment(\.dismiss) private var dismiss
    public let teacherName: String
    public let subjectName: String
    public let subjectId: String?

    @State private var reviews: [TeacherReview] = []
    @State private var stats: TeacherStats?
    @State private var summary: TeacherSummary?
    @State private var userVotes: [String: String] = [:]
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

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Stats Card
                    if let s = stats {
                        statsCard(s)
                    }

                    // AI Summary Card
                    aiSummaryCard

                    // Reviews List
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Отзывы и советы студентов")
                                .font(.headline)
                            Spacer()
                            Text("Всего: \(reviews.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        if isLoading && reviews.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if reviews.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("Отзывов пока нет")
                                    .font(.subheadline.weight(.semibold))
                                Text("Будьте первым, кто оставит совет по этому преподавателю!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(reviews) { r in
                                    reviewCard(r)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("👨‍🏫 \(teacherName)")
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
                AddReviewSheet(teacherName: teacherName, subjectName: subjectName, subjectId: subjectId) {
                    Task { await loadReviews() }
                }
            }
        }
    }

    private func loadReviews() async {
        isLoading = true
        let (revs, st) = await SupabaseService.shared.getTeacherReviews(teacherName: teacherName)
        self.reviews = revs
        self.stats = st
        self.summary = await SupabaseService.shared.getTeacherSummary(teacherName: teacherName)
        self.userVotes = await LocalStore.shared.loadReviewVotes()
        isLoading = false

        // Auto generate summary if reviews exist but no summary yet
        if summary == nil && !revs.isEmpty {
            isGeneratingSummary = true
            if let newSum = await GroqModerationService.shared.generateTeacherSummary(teacherName: teacherName, reviews: revs) {
                await SupabaseService.shared.saveTeacherSummary(teacherName: teacherName, summaryText: newSum, count: revs.count)
                self.summary = TeacherSummary(teacherName: teacherName, summaryText: newSum, reviewsCount: revs.count)
            }
            isGeneratingSummary = false
        }
    }

    private func statsCard(_ s: TeacherStats) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", s.avgDifficulty))
                    .font(.title2.weight(.bold))
                    .foregroundColor(.orange)
                Text("Сложность / 5")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack(spacing: 4) {
                Text("\(s.avtomatPct)%")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.green)
                Text("Даёт автомат")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack(spacing: 4) {
                Text("\(s.attendancePct)%")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.blue)
                Text("Строго к посещ.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private var aiSummaryCard: some View {
        Group {
            if let sum = summary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("AI-выжимка нейросети", systemImage: "sparkles")
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
                    Text("Генерация выжимки нейросетью...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private func reviewCard(_ r: TeacherReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .foregroundColor(.green)
                }

                if r.attendanceStrict {
                    Text("• Посещения")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.blue)
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
                        .foregroundColor(vote == "up" ? .green : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(vote == "up" ? Color.green.opacity(0.15) : Color(.tertiarySystemFill))
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
                        .foregroundColor(vote == "down" ? .red : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(vote == "down" ? Color.red.opacity(0.15) : Color(.tertiarySystemFill))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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
