import SwiftUI

public struct AddReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let teacherName: String
    public let subjectName: String
    public let subjectId: String?
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
        onReviewAdded: @escaping () -> Void
    ) {
        self.teacherName = teacherName
        self.subjectName = subjectName
        self.subjectId = subjectId
        self.onReviewAdded = onReviewAdded
    }

    public var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("Новый совет")
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
                            Text("Опубликовать")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 15 || isSubmitting)
                }
            }
        }
    }

    private func submitReview() {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 15 else { return }

        // Cooldown check
        let lastTime = UserDefaults.standard.double(forKey: "last_review_submit_time")
        let now = Date().timeIntervalSince1970
        let cooldown: Double = 30.0
        if now - lastTime < cooldown {
            let remain = Int(ceil(cooldown - (now - lastTime)))
            isError = true
            statusMessage = "Пожалуйста, подождите \(remain) сек. перед отправкой следующего отзыва."
            return
        }

        isSubmitting = true
        statusMessage = "Проверка нейросетью..."
        isError = false

        Task {
            // Step 1: AI moderation through Groq
            let modResult = await GroqModerationService.shared.moderateReview(text: cleaned)
            guard modResult.allowed else {
                isSubmitting = false
                isError = true
                statusMessage = "Модерация не пройдена: \(modResult.reason ?? "Недопустимый текст")"
                return
            }

            statusMessage = "Сохранение в базу..."

            // Step 2: Save to Supabase (с корректным UUID subjectId)
            let review = TeacherReview(
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
                _ = try await SupabaseService.shared.addTeacherReview(review: review)
                UserDefaults.standard.set(now, forKey: "last_review_submit_time")

                // Step 3: Check if summary needs regeneration
                let (reviews, _) = await SupabaseService.shared.getTeacherReviews(teacherName: teacherName)
                if reviews.count == 1 || reviews.count % 5 == 0 {
                    if let summary = await GroqModerationService.shared.generateTeacherSummary(teacherName: teacherName, reviews: reviews) {
                        await SupabaseService.shared.saveTeacherSummary(teacherName: teacherName, summaryText: summary, count: reviews.count)
                    }
                }

                isSubmitting = false
                isError = false
                statusMessage = "Отзыв успешно опубликован!"
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
