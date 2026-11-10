import SwiftUI

public struct TasksView: View {
    @StateObject private var taskManager = TaskManager.shared
    @EnvironmentObject private var appState: AppState

    @State private var viewMode: TaskViewMode = .list
    @State private var showingCreateSheet: Bool = false
    @State private var showingMoodleSheet: Bool = false
    @State private var editingTask: StudyTask? = nil
    @State private var showCompletedSection: Bool = false

    public enum TaskViewMode: String, CaseIterable {
        case list = "Список"
        case calendar = "Календарь"
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Верхний переключатель режима (Список / Календарь)
                HStack {
                    Picker("Режим", selection: $viewMode) {
                        ForEach(TaskViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)

                    Spacer()

                    // Краткая статистика
                    HStack(spacing: 6) {
                        if taskManager.overdueTasksCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text("\(taskManager.overdueTasksCount)")
                                    .fontWeight(.bold)
                            }
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.dangerRed)
                            .clipShape(Capsule())
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "checklist")
                            Text("\(taskManager.activeTasksCount)")
                                .fontWeight(.semibold)
                        }
                        .font(.caption2)
                        .foregroundColor(AppTheme.susuBluePrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.susuBluePrimary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(AppTheme.cardBackground)

                // Фильтры по дисциплинам текущего семестра
                subjectFilterBar

                Divider()

                // Основное содержимое
                if viewMode == .calendar {
                    TasksCalendarView()
                } else {
                    taskListView
                }
            }
            .navigationTitle("Учебный план")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .searchable(text: $taskManager.searchQuery, prompt: "Поиск по названию или предмету")
            .sheet(isPresented: $showingCreateSheet) {
                CreateTaskSheet()
            }
            .sheet(isPresented: $showingMoodleSheet) {
                MoodleCalendarView()
            }
            .sheet(item: $editingTask) { task in
                CreateTaskSheet(initialTask: task)
            }
        }
    }

    private var subjectFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Все дисциплины",
                    isSelected: taskManager.selectedDisciplineFilter == nil
                ) {
                    taskManager.selectedDisciplineFilter = nil
                }

                ForEach(appState.subjects) { sub in
                    FilterChip(
                        title: sub.disciplineName,
                        isSelected: taskManager.selectedDisciplineFilter == sub.disciplineName
                    ) {
                        if taskManager.selectedDisciplineFilter == sub.disciplineName {
                            taskManager.selectedDisciplineFilter = nil
                        } else {
                            taskManager.selectedDisciplineFilter = sub.disciplineName
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(AppTheme.cardBackground)
    }

    @ViewBuilder
    private var taskListView: some View {
        if taskManager.filteredTasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 52))
                        .foregroundColor(AppTheme.susuBluePrimary.opacity(0.8))

                    Text("Задач пока нет")
                        .font(.headline)

                    Text("Планируйте сдачу лабораторных, зачётов и экзаменов. Задачи можно создавать прямо из контрольных точек дисциплин!")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)

                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("Создать задачу", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppTheme.susuBluePrimary)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        Color.clear.frame(height: 0).id("tasks_top_anchor")
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)

                        // 1. Просроченные задачи
                    if !taskManager.overdueTasks.isEmpty {
                        Section {
                            ForEach(taskManager.overdueTasks) { task in
                                taskRow(task)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.dangerRed)
                                Text("Просроченные (\(taskManager.overdueTasks.count))")
                                    .foregroundColor(AppTheme.dangerRed)
                            }
                        }
                    }

                    // 2. Сегодня
                    if !taskManager.todayTasks.isEmpty {
                        Section("Сегодня") {
                            ForEach(taskManager.todayTasks) { task in
                                taskRow(task)
                            }
                        }
                    }

                    // 3. Ближайшие (на этой неделе)
                    if !taskManager.upcomingTasks.isEmpty {
                        Section("Ближайшие 7 дней") {
                            ForEach(taskManager.upcomingTasks) { task in
                                taskRow(task)
                            }
                        }
                    }

                    // 4. Позже / без срока
                    if !taskManager.laterTasks.isEmpty {
                        Section("Позже") {
                            ForEach(taskManager.laterTasks) { task in
                                taskRow(task)
                            }
                        }
                    }

                    // 5. Выполненные (скрываются/раскрываются)
                    if !taskManager.completedTasks.isEmpty {
                        Section {
                            DisclosureGroup(
                                isExpanded: $showCompletedSection,
                                content: {
                                    ForEach(taskManager.completedTasks) { task in
                                        taskRow(task)
                                    }
                                },
                                label: {
                                    HStack {
                                        Text("Выполненные (\(taskManager.completedTasks.count))")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .onReceive(NotificationCenter.default.publisher(for: .scrollToTopTab)) { notif in
                    if let tabIdx = notif.userInfo?["tabIndex"] as? Int, tabIdx == 2 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("tasks_top_anchor", anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private func taskRow(_ task: StudyTask) -> some View {
        TaskCardView(
            task: task,
            onToggleStatus: {
                Task { await taskManager.toggleTaskCompletion(task) }
            },
            onEdit: {
                editingTask = task
            },
            onDelete: {
                Task { await taskManager.deleteTask(id: task.id) }
            },
            onPostpone: { days in
                Task { await taskManager.postponeTask(id: task.id, days: days) }
            }
        )
    }
}
