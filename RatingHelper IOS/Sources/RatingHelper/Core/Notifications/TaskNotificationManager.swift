import Foundation
import UserNotifications

public final class TaskNotificationManager: Sendable {
    public static let shared = TaskNotificationManager()

    private init() {}

    public func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Ошибка запроса разрешения на уведомления: \(error)")
            return false
        }
    }

    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    public func scheduleReminders(for task: StudyTask) {
        // Отменяем существующие напоминания для этой задачи перед перепланированием
        cancelReminders(for: task.id)

        // Для завершенных задач или задач без срока напоминания не устанавливаем
        guard task.status != .completed, let dueDate = task.dueDate else { return }

        let center = UNUserNotificationCenter.current()
        let now = Date()

        for option in task.reminderOptions {
            guard let triggerDate = option.triggerDate(from: dueDate), triggerDate > now else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = task.title
            if let disc = task.disciplineName, !disc.isEmpty {
                if let cp = task.checkpointTitle, !cp.isEmpty {
                    content.subtitle = "\(disc) • \(cp)"
                } else {
                    content.subtitle = disc
                }
            } else if let cp = task.checkpointTitle, !cp.isEmpty {
                content.subtitle = cp
            }

            content.body = "Напоминание по дедлайну задачи. Срок сдачи: \(formatDate(dueDate))."
            content.sound = .default
            content.badge = 1

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let identifier = "task_\(task.id.uuidString)_\(option.rawValue)"

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request) { error in
                if let err = error {
                    print("Ошибка планирования уведомления: \(err)")
                }
            }
        }

        // Пользовательское напоминание
        if let custom = task.customReminderDate, custom > now {
            let content = UNMutableNotificationContent()
            content.title = task.title
            content.subtitle = task.disciplineName ?? "Учебная задача"
            content.body = "Запланированное напоминание: \(task.notes.isEmpty ? task.title : task.notes)"
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: custom)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let identifier = "task_\(task.id.uuidString)_custom"

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    public func cancelReminders(for taskId: UUID) {
        let center = UNUserNotificationCenter.current()
        let prefix = "task_\(taskId.uuidString)"
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
