import Foundation
import SwiftUI
import Combine

@MainActor
public final class TaskManager: ObservableObject {
    public static let shared = TaskManager()

    @Published public var tasks: [StudyTask] = []
    @Published public var selectedDisciplineFilter: String? = nil
    @Published public var searchQuery: String = ""

    private let store = LocalStore.shared
    private let notifications = TaskNotificationManager.shared
    private let filename = "study_tasks.json"

    private init() {
        Task {
            await loadTasks()
        }
    }

    public func loadTasks() async {
        let loaded = await store.readCustom([StudyTask].self, from: filename) ?? []
        self.tasks = loaded.sorted {
            ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture)
        }
    }

    public func saveTasks() async {
        await store.writeCustom(tasks, to: filename)
    }

    public func addTask(_ task: StudyTask) async {
        tasks.append(task)
        tasks.sort {
            ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture)
        }
        await saveTasks()
        notifications.scheduleReminders(for: task)
    }

    public func updateTask(_ task: StudyTask) async {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
            tasks.sort {
                ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture)
            }
            await saveTasks()
            notifications.scheduleReminders(for: task)
        }
    }

    public func deleteTask(id: UUID) async {
        notifications.cancelReminders(for: id)
        tasks.removeAll(where: { $0.id == id })
        await saveTasks()
    }

    public func toggleTaskCompletion(_ task: StudyTask) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        if tasks[idx].status == .completed {
            tasks[idx].status = .inProgress
            tasks[idx].completedAt = nil
            notifications.scheduleReminders(for: tasks[idx])
        } else {
            tasks[idx].status = .completed
            tasks[idx].completedAt = Date()
            notifications.cancelReminders(for: tasks[idx].id)
        }
        await saveTasks()
    }

    public func postponeTask(id: UUID, days: Int) async {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let currentDue = tasks[idx].dueDate ?? Date()
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: currentDue) {
            tasks[idx].dueDate = newDate
            await saveTasks()
            notifications.scheduleReminders(for: tasks[idx])
        }
    }

    // Фильтрация
    public var filteredTasks: [StudyTask] {
        var result = tasks

        if let disc = selectedDisciplineFilter, !disc.isEmpty {
            result = result.filter { $0.disciplineName == disc }
        }

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.notes.lowercased().contains(q) ||
                ($0.disciplineName?.lowercased().contains(q) ?? false) ||
                ($0.checkpointTitle?.lowercased().contains(q) ?? false)
            }
        }

        return result
    }

    public var overdueTasks: [StudyTask] {
        filteredTasks.filter { $0.isOverdue }
    }

    public var todayTasks: [StudyTask] {
        filteredTasks.filter { $0.isDueToday }
    }

    public var upcomingTasks: [StudyTask] {
        filteredTasks.filter { $0.isDueUpcoming }
    }

    public var laterTasks: [StudyTask] {
        filteredTasks.filter { $0.isDueLater || ($0.dueDate == nil && $0.status != .completed) }
    }

    public var completedTasks: [StudyTask] {
        filteredTasks.filter { $0.status == .completed }
    }

    public var activeTasksCount: Int {
        tasks.filter { $0.status != .completed }.count
    }

    public var overdueTasksCount: Int {
        tasks.filter { $0.isOverdue }.count
    }
}
