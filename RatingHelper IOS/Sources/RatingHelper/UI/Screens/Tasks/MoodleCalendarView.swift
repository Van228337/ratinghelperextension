import SwiftUI

public struct MoodleCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var taskManager = TaskManager.shared

    @State private var selectedDate: Date = Date()
    @State private var events: [MoodleCalendarEvent] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var selectedCourse: String? = nil
    @State private var isOffline: Bool = false
    @State private var addedEventIds: Set<Int> = []

    private let moodleService = MoodleCalendarService.shared
    private let store = LocalStore.shared

    public init() {}

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Yekaterinburg") ?? .current
        cal.locale = Locale(identifier: "ru_RU")
        return cal
    }

    private var currentYear: Int {
        calendar.component(.year, from: selectedDate)
    }

    private var currentMonth: Int {
        calendar.component(.month, from: selectedDate)
    }

    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: "Asia/Yekaterinburg") ?? .current
        formatter.dateFormat = "LLLL yyyy"
        let str = formatter.string(from: selectedDate)
        return str.prefix(1).uppercased() + str.dropFirst()
    }

    private var availableCourses: [String] {
        let names = events.compactMap { $0.courseName }.filter { !$0.isEmpty }
        return Array(Set(names)).sorted()
    }

    private var filteredEvents: [MoodleCalendarEvent] {
        var list = events
        if let course = selectedCourse, !course.isEmpty {
            list = list.filter { $0.courseName == course }
        }
        return list.sorted { $0.timestart < $1.timestart }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month selector header
                monthSelectorHeader

                // Course filter
                if !availableCourses.isEmpty {
                    courseFilterBar
                }

                // Offline warning banner
                if isOffline {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                        Text("Офлайн-режим: показаны сохранённые дедлайны")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                }

                Divider()

                // Content
                contentView
            }
            .background(AppTheme.background)
            .navigationTitle("Дедлайны Moodle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadEvents(forceRefresh: true) }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                updateAddedEventIds()
                await loadEvents(forceRefresh: false)
            }
            .onChange(of: taskManager.tasks) { _ in
                updateAddedEventIds()
            }
        }
    }

    // MARK: - Subviews

    private var monthSelectorHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.bold))
                    .foregroundColor(AppTheme.susuBluePrimary)
                    .padding(8)
                    .background(Circle().fill(AppTheme.cardBackground))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(monthYearTitle)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Часовой пояс: Екатеринбург (UTC+5)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundColor(AppTheme.susuBluePrimary)
                    .padding(8)
                    .background(Circle().fill(AppTheme.cardBackground))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
    }

    private var courseFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Все курсы (\(events.count))",
                    isSelected: selectedCourse == nil
                ) {
                    selectedCourse = nil
                }

                ForEach(availableCourses, id: \.self) { course in
                    let count = events.filter { $0.courseName == course }.count
                    FilterChip(
                        title: "\(course) (\(count))",
                        isSelected: selectedCourse == course
                    ) {
                        if selectedCourse == course {
                            selectedCourse = nil
                        } else {
                            selectedCourse = course
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(AppTheme.cardBackground)
    }

    private var contentView: some View {
        Group {
            if isLoading && events.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загрузка дедлайнов из Moodle...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, events.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundColor(AppTheme.warningOrange)

                    Text("Не удалось загрузить дедлайны")
                        .font(.headline)

                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button {
                        Task { await loadEvents(forceRefresh: true) }
                    } label: {
                        Text("Повторить попытку")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppTheme.susuBluePrimary)
                            .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.susuBluePrimary.opacity(0.8))

                    Text("Нет дедлайнов в этом месяце")
                        .font(.headline)

                    Text("В выбранном месяце нет заданий или тестов со сроком сдачи на edu.susu.ru")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredEvents) { event in
                        moodleEventRow(event)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await loadEvents(forceRefresh: true)
                }
            }
        }
    }

    private func moodleEventRow(_ event: MoodleCalendarEvent) -> some View {
        let isAdded = addedEventIds.contains(event.id)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                // Event Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(event.isQuizClose ? Color.purple.opacity(0.15) : AppTheme.susuBluePrimary.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: event.isQuizClose ? "questionmark.circle.fill" : "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundColor(event.isQuizClose ? .purple : AppTheme.susuBluePrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if let course = event.courseName, !course.isEmpty {
                        Text(course)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            Divider()

            // Date & Remaining Time
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatEventDate(event.deadlineDate))
                            .font(.caption.weight(.medium))
                            .foregroundColor(.primary)
                    }

                    Text(timeRemainingDescription(to: event.deadlineDate))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(remainingColor(to: event.deadlineDate))
                }

                Spacer()

                // Actions: Link to Moodle & Add to Plan
                HStack(spacing: 8) {
                    if let urlString = event.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text("В Moodle")
                            }
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .cornerRadius(8)
                        }
                    }

                    Button {
                        Task { await addEventToPlan(event) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(isAdded ? "В плане" : "В план")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(isAdded ? .white : AppTheme.susuBluePrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isAdded ? Color.green : AppTheme.susuBluePrimary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .disabled(isAdded)
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Actions & Logic

    private func changeMonth(by delta: Int) {
        if let newDate = calendar.date(byAdding: .month, value: delta, to: selectedDate) {
            selectedDate = newDate
            selectedCourse = nil
            Task {
                await loadEvents(forceRefresh: false)
            }
        }
    }

    private func loadEvents(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil

        let cacheKey = "moodle_events_\(currentYear)_\(currentMonth).json"

        // 1. If not forcing refresh, attempt to load from local cache first
        if !forceRefresh {
            if let cached = await store.readCustom([MoodleCalendarEvent].self, from: cacheKey), !cached.isEmpty {
                self.events = cached
                self.isOffline = false
                self.isLoading = false
                return
            }
        }

        // 2. Fetch from Moodle API
        do {
            let fetched = try await moodleService.fetchMonthlyEvents(year: currentYear, month: currentMonth)
            self.events = fetched
            self.isOffline = false
            await store.writeCustom(fetched, to: cacheKey)
        } catch {
            // Check fallback to cache
            if let cached = await store.readCustom([MoodleCalendarEvent].self, from: cacheKey), !cached.isEmpty {
                self.events = cached
                self.isOffline = true
            } else {
                self.errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func addEventToPlan(_ event: MoodleCalendarEvent) async {
        let task = event.toStudyTask()
        await taskManager.addTask(task)
        updateAddedEventIds()
    }

    private func updateAddedEventIds() {
        let existingMoodleIds = taskManager.tasks
            .filter { $0.externalSource == .moodle }
            .compactMap { task -> Int? in
                guard let ext = task.externalId, ext.hasPrefix("moodle_") else { return nil }
                return Int(ext.dropFirst("moodle_".count))
            }
        self.addedEventIds = Set(existingMoodleIds)
    }

    // MARK: - Helpers

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: "Asia/Yekaterinburg") ?? .current
        formatter.dateFormat = "d MMMM, HH:mm"
        return formatter.string(from: date)
    }

    private func timeRemainingDescription(to date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval < 0 {
            return "Срок сдачи истёк"
        }

        let secondsInHour: Double = 3600
        let secondsInDay: Double = 86400

        let days = Int(interval / secondsInDay)
        let hours = Int((interval.truncatingRemainder(dividingBy: secondsInDay)) / secondsInHour)

        if days > 0 {
            return "Осталось: \(days) дн. \(hours) ч."
        } else if hours > 0 {
            return "Осталось: \(hours) ч."
        } else {
            let minutes = Int(interval / 60)
            return "Осталось: \(minutes) мин."
        }
    }

    private func remainingColor(to date: Date) -> Color {
        let interval = date.timeIntervalSince(Date())
        if interval < 0 {
            return AppTheme.dangerRed
        } else if interval < 86400 * 2 {
            return .orange
        } else {
            return .secondary
        }
    }
}
