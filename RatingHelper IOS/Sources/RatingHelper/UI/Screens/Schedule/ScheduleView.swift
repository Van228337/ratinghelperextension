import SwiftUI

public struct ScheduleView: View {
    @EnvironmentObject private var appState: AppState
    @State private var lessons: [ScheduleLesson] = []
    @State private var selectedDate: Date = Date()
    @State private var stripReferenceDate: Date = Date()
    @State private var swipeDirection: Int = 1
    @State private var isLoading: Bool = false
    @State private var isOffline: Bool = false
    @State private var lastSync: String? = nil
    @State private var errorMessage: String? = nil

    private var calendar: Calendar {
        SusuScheduleService.susuCalendar
    }

    private var currentGroupId: String? {
        appState.session?.studentProfile?.groupId
    }

    private var currentGroupName: String {
        appState.session?.studentProfile?.groupName ?? "ЮУрГУ"
    }

    private var selectedDateString: String {
        SusuScheduleService.formatDateString(selectedDate)
    }

    private var todayDateString: String {
        SusuScheduleService.todayDateString()
    }

    private var weekDays: [Date] {
        let cal = calendar
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: stripReferenceDate) else {
            return [stripReferenceDate]
        }
        var days: [Date] = []
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: i, to: weekInterval.start) {
                days.append(d)
            }
        }
        return days
    }

    private var dayLessons: [ScheduleLesson] {
        lessons
            .filter { $0.eventDate == selectedDateString }
            .sorted { $0.beginTime < $1.beginTime }
    }

    private var visibleMonthYearTitle: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let fMonth = calendar.component(.month, from: first)
        let lMonth = calendar.component(.month, from: last)
        let fYear = calendar.component(.year, from: first)
        let lYear = calendar.component(.year, from: last)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")

        if fMonth == lMonth && fYear == lYear {
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: first).capitalized
        } else if fYear == lYear {
            formatter.dateFormat = "LLL"
            let m1 = formatter.string(from: first).capitalized
            let m2 = formatter.string(from: last).capitalized
            return "\(m1) – \(m2) \(fYear)"
        } else {
            formatter.dateFormat = "LLL yyyy"
            let m1 = formatter.string(from: first).capitalized
            let m2 = formatter.string(from: last).capitalized
            return "\(m1) – \(m2)"
        }
    }

    private var isViewingCurrentWeek: Bool {
        calendar.isDate(stripReferenceDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Заголовок текущего месяца и года ленты
                monthYearBanner
                    .background(AppTheme.cardBackground)

                // Горизонтальная лента дней недели со стрелками прокрутки
                weekDaysHeader
                    .padding(.bottom, 8)
                    .background(AppTheme.cardBackground)

                // Офлайн статус
                if isOffline {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                        Text("Офлайн-режим • Синхронизировано: \(lastSync ?? "ранее")")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                }

                Divider()

                if isLoading && lessons.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Загрузка расписания занятий...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage, lessons.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Не удалось загрузить расписание")
                            .font(.headline)
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Повторить попытку") {
                            Task { await loadSchedule(forceRefresh: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.susuBluePrimary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    lessonsList
                }
            }
            .navigationTitle("Расписание (\(currentGroupName))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сегодня") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedDate = Date()
                            stripReferenceDate = Date()
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppTheme.susuBluePrimary)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await loadSchedule(forceRefresh: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadSchedule(forceRefresh: false)
            }
        }
    }

    // MARK: - Subviews
    private var monthYearBanner: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.susuBluePrimary)
                Text(visibleMonthYearTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.primary)
            }

            Spacer()

            if !isViewingCurrentWeek {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        stripReferenceDate = Date()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("К текущей неделе")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppTheme.susuBluePrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.susuBluePrimary.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var weekDaysHeader: some View {
        HStack(spacing: 4) {
            // Стрелка влево: смещает видимую ленту дат назад, НЕ меняя выбранный день
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    stripReferenceDate = calendar.date(byAdding: .day, value: -7, to: stripReferenceDate) ?? stripReferenceDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.susuBluePrimary)
                    .frame(width: 26, height: 42)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Лента дней недели (7 дней вокруг stripReferenceDate)
            HStack(spacing: 4) {
                ForEach(weekDays, id: \.self) { date in
                    let dateStr = SusuScheduleService.formatDateString(date)
                    let isSelected = (dateStr == selectedDateString)
                    let isToday = (dateStr == todayDateString)

                    Button {
                        // Только отдельное нажатие делает дату выбранной!
                        swipeDirection = date >= selectedDate ? 1 : -1
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedDate = date
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(weekdayShortName(for: date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isSelected ? .white : (isToday ? AppTheme.susuBluePrimary : .secondary))

                            Text(dayNumber(for: date))
                                .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected
                                ? AppTheme.susuBluePrimary
                                : (isToday ? AppTheme.susuBluePrimary.opacity(0.12) : Color.clear)
                        )
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Стрелка вправо: смещает видимую ленту дат вперёд, НЕ меняя выбранный день
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    stripReferenceDate = calendar.date(byAdding: .day, value: 7, to: stripReferenceDate) ?? stripReferenceDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.susuBluePrimary)
                    .frame(width: 26, height: 42)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
    }

    private var lessonsList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                Color.clear.frame(height: 0).id("schedule_top_anchor")

                VStack(spacing: 12) {
                    if dayLessons.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 42))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text("В этот день занятий нет")
                                .font(.headline.weight(.semibold))
                            Text("Отличный повод повторить пройденный материал или закрыть дедлайны в планировщике!")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(dayLessons) { lesson in
                            lessonCard(lesson)
                        }
                    }
                }
                .padding(16)
                .id(selectedDateString)
                .transition(.asymmetric(
                    insertion: .move(edge: swipeDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: swipeDirection > 0 ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .refreshable {
                await loadSchedule(forceRefresh: true)
            }
            // Свайпы в зоне расписания: свайп влево — следующий день, свайп вправо — предыдущий
            .highPriorityGesture(
                DragGesture(minimumDistance: 25)
                    .onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) * 1.3 && abs(value.translation.width) > 30 {
                            if value.translation.width < 0 {
                                switchToNextDay()
                            } else {
                                switchToPreviousDay()
                            }
                        }
                    }
            )
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTopTab)) { notif in
                if let tabIdx = notif.userInfo?["tabIndex"] as? Int, tabIdx == 1 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollProxy.scrollTo("schedule_top_anchor", anchor: .top)
                    }
                }
            }
        }
    }

    private func switchToNextDay() {
        guard let next = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        swipeDirection = 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            selectedDate = next
            ensureVisibleInStrip(next)
        }
    }

    private func switchToPreviousDay() {
        guard let prev = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        swipeDirection = -1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            selectedDate = prev
            ensureVisibleInStrip(prev)
        }
    }

    private func ensureVisibleInStrip(_ targetDate: Date) {
        let cal = calendar
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: stripReferenceDate) else { return }
        if targetDate < weekInterval.start || targetDate >= weekInterval.end {
            stripReferenceDate = targetDate
        }
    }

    private func lessonCard(_ lesson: ScheduleLesson) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(lesson.formattedTimeRange)
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(AppTheme.susuBluePrimary)
                .cornerRadius(8)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: lesson.eventTypeIcon)
                        .font(.caption2)
                    Text(lesson.eventType)
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(eventTypeColor(lesson.eventType).opacity(0.15))
                .foregroundColor(eventTypeColor(lesson.eventType))
                .cornerRadius(8)
            }

            Text(lesson.subject)
                .font(.headline.weight(.bold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 14) {
                if let inst = lesson.instructors.first {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(inst.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(inst.displayLocation)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Преподаватель и аудитория не указаны")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func eventTypeColor(_ type: String) -> Color {
        let l = type.lowercased()
        if l.contains("лекц") { return .purple }
        if l.contains("практ") { return .blue }
        if l.contains("лабор") { return .orange }
        if l.contains("экзам") || l.contains("зачет") || l.contains("зачёт") { return .red }
        return .green
    }

    private func weekdayShortName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = calendar.timeZone
        return f.string(from: date).capitalized
    }

    private func dayNumber(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.timeZone = calendar.timeZone
        return f.string(from: date)
    }

    private func loadSchedule(forceRefresh: Bool) async {
        guard let gId = currentGroupId, !gId.isEmpty else {
            errorMessage = "Не найден идентификатор академической группы. Войдите в учётную запись заново."
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await SusuScheduleService.shared.fetchSchedule(groupId: gId, forceRefresh: forceRefresh)
            let matched = SusuScheduleService.matchLessons(lessons: fetched, with: appState.subjects)
            self.lessons = matched
            self.isOffline = false
            self.lastSync = await LocalStore.shared.formattedLastSync(key: "schedule_\(gId)")
            isLoading = false
        } catch {
            if let cached = await LocalStore.shared.loadSchedule(groupId: gId), !cached.isEmpty {
                let matched = SusuScheduleService.matchLessons(lessons: cached, with: appState.subjects)
                self.lessons = matched
                self.isOffline = true
                self.lastSync = await LocalStore.shared.formattedLastSync(key: "schedule_\(gId)")
            } else {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
