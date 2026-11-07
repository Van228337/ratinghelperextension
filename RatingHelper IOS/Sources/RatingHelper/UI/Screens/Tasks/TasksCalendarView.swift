import SwiftUI

public struct TasksCalendarView: View {
    @ObservedObject var taskManager = TaskManager.shared
    @State private var selectedDate: Date = Date()
    @State private var showingCreateTask: Bool = false
    @State private var taskToEdit: StudyTask? = nil

    private var tasksOnSelectedDate: [StudyTask] {
        taskManager.filteredTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDate(due, inSameDayAs: selectedDate)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Графический календарь iOS
                DatePicker(
                    "Календарь дедлайнов",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .tint(AppTheme.susuBluePrimary)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(14)
                .padding(.horizontal)

                // Список задач на выбранный день
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(formatSelectedDate(selectedDate))
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Button {
                            showingCreateTask = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Добавить")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundColor(AppTheme.susuBluePrimary)
                        }
                    }
                    .padding(.horizontal)

                    if tasksOnSelectedDate.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("На эту дату дедлайнов нет")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(tasksOnSelectedDate) { task in
                                TaskCardView(
                                    task: task,
                                    onToggleStatus: {
                                        Task { await taskManager.toggleTaskCompletion(task) }
                                    },
                                    onEdit: {
                                        taskToEdit = task
                                    },
                                    onDelete: {
                                        Task { await taskManager.deleteTask(id: task.id) }
                                    },
                                    onPostpone: { days in
                                        Task { await taskManager.postponeTask(id: task.id, days: days) }
                                    }
                                )
                                .padding()
                                .background(AppTheme.cardBackground)
                                .cornerRadius(12)

                                if task.id != tasksOnSelectedDate.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingCreateTask) {
            CreateTaskSheet(prefilledSubject: nil, prefilledCheckpoint: nil)
        }
        .sheet(item: $taskToEdit) { task in
            CreateTaskSheet(initialTask: task)
        }
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, EEEE"
        return formatter.string(from: date).capitalized
    }
}
