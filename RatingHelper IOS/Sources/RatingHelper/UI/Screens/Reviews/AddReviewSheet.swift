import SwiftUI

public struct AddReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    public let teacherName: String
    public let subjectName: String
    public let subjectId: String?
    public let reviewToEdit: TeacherReview?
    public let onReviewAdded: () -> Void

    @State private var text: String = ""
    @State private var difficulty: Int = 3
    @State private var givesAvtomat: Bool = false
    @State private var attendanceStrict: Bool = false
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var isSubmitting: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isError: Bool = false

    private let years = [2026, 2025, 2024, 2023, 2022]

    public init(
        teacherName: String,
        subjectName: String,
        subjectId: String? = nil,
        reviewToEdit: TeacherReview? = nil,
        onReviewAdded: @escaping () -> Void
    ) {
        self.teacherName = teacherName
        self.subjectName = subjectName
        self.subjectId = subjectId
        self.reviewToEdit = reviewToEdit
        self.onReviewAdded = onReviewAdded

        _text = State(initialValue: reviewToEdit?.text ?? "")
        _difficulty = State(initialValue: reviewToEdit?.difficulty ?? 3)
        _givesAvtomat = State(initialValue: reviewToEdit?.givesAvtomat ?? false)
        _attendanceStrict = State(initialValue: reviewToEdit?.attendanceStrict ?? false)
        _year = State(initialValue: reviewToEdit?.year ?? Calendar.current.component(.year, from: Date()))
    }

    public var body: some View {
        NavigationStack {
            Form {
                if !appState.canPublishReviews {
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.orange)
                            Text("Публикация отзывов для вашей учётной записи отключена администратором.")
                                .font(.footnote)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section(header: Text("Преподаватель и предмет")) {
                    Text("👨‍🏫 \(teacherName)")
                        .font(.headline)
                    Text("Дисциплина: \(subjectName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Ваш совет или отзыв")) {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                    Text("Символов: \(text.count) (от 15 до 1200)")
                        .font(.caption2)
                        .foregroundColor(text.count < 15 || text.count > 1200 ? .red : .secondary)
                }

                Section(header: Text("Параметры сдачи")) {
                    Picker("Сложность предмета", selection: $difficulty) {
                        Text("1 - Очень легко").tag(1)
                        Text("2 - Легко").tag(2)
                        Text("3 - Средне").tag(3)
                        Text("4 - Сложно").tag(4)
                        Text("5 - Хардкор").tag(5)
                    }

                    Toggle("Ставит автомат", isOn: $givesAvtomat)
                    Toggle("Строго к посещениям", isOn: $attendanceStrict)

                    Picker("Год сдачи", selection: $year) {
                        ForEach(years, id: \.self) { y in
                            Text("\(y) год").tag(y)
                        }
                    }
                }

                if let msg = statusMessage {
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(isError ? .red : .green)
                            Text(msg)
                                .font(.footnote)
                                .foregroundColor(isError ? .red : .green)
                        }
                    }
                }
            }
            .navigationTitle(reviewToEdit != nil ? "Редактировать отзыв" : "Новый совет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitReview()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(reviewToEdit != nil ? "Сохранить" : "Опубликовать")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(!appState.canPublishReviews || text.trimmingCharacters(in: .whitespacesAndNewlines).count < 15 || isSubmitting)
                }
            }
        }
    }

    private func submitReview() {
        guard appState.canPublishReviews else {
            isError = true
            statusMessage = "Публикация отзывов отключена администратором."
            return
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 15 else { return }

        // Cooldown check (настраиваемый с сервера cooldown)
        let lastTime = UserDefaults.standard.double(forKey: "last_review_submit_time_\(appState.effectiveUserId)")
        let now = Date().timeIntervalSince1970
        let cooldown = Double(appState.reviewEditCooldownSeconds)
        if now - lastTime < cooldown {
            let remain = Int(ceil(cooldown - (now - lastTime)))
            isError = true
            statusMessage = "Пожалуйста, подождите \(remain) сек. перед отправкой или редактированием отзыва."
            return
        }

        isSubmitting = true
        statusMessage = "Проверка нейросетью..."
        isError = false

        Task {
            // Step 1: AI moderation through Groq
            let modResult = await GroqModerationService.shared.moderateReview(text: cleaned, userId: appState.effectiveUserId)
            guard modResult.allowed else {
                isSubmitting = false
                isError = true
                statusMessage = "Модерация не пройдена: \(modResult.reason ?? "Недопустимый текст")"
                return
            }

            statusMessage = "Сохранение в базу..."

            // Step 2: Save to Supabase (с корректным UUID subjectId и userId)
            let reviewId = reviewToEdit?.id ?? UUID().uuidString.lowercased()
            let review = TeacherReview(
                id: reviewId,
                userId: appState.effectiveUserId,
                teacherName: teacherName,
                subjectId: subjectId,
                subjectName: subjectName,
                text: cleaned,
                difficulty: difficulty,
                givesAvtomat: givesAvtomat,
                attendanceStrict: attendanceStrict,
                year: year
            )

            do {
                _ = try await SupabaseService.shared.addTeacherReview(review: review, userId: appState.effectiveUserId)
                UserDefaults.standard.set(now, forKey: "last_review_submit_time_\(appState.effectiveUserId)")

                isSubmitting = false
                isError = false
                statusMessage = reviewToEdit != nil ? "Отзыв успешно обновлён!" : "Отзыв успешно опубликован!"
                onReviewAdded()

                try? await Task.sleep(nanoseconds: 600_000_000)
                dismiss()
            } catch {
                isSubmitting = false
                isError = true
                statusMessage = "Ошибка сохранения: \(error.localizedDescription)"
            }
        }
    }
}
