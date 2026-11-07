import SwiftUI

public struct TaskCardView: View {
    public let task: StudyTask
    public let onToggleStatus: () -> Void
    public let onEdit: () -> Void
    public let onDelete: () -> Void
    public let onPostpone: (Int) -> Void

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button {
                onToggleStatus()
            } label: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : (task.status == .inProgress ? "clock.circle.fill" : "circle"))
                    .font(.system(size: 22))
                    .foregroundColor(task.status == .completed ? AppTheme.successGreen : (task.status == .inProgress ? AppTheme.warningOrange : .secondary))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(task.status == .completed ? .secondary : .primary)
                        .strikethrough(task.status == .completed)
                        .lineLimit(2)

                    Spacer()

                    // Priority Icon
                    if task.priority != .normal {
                        Image(systemName: task.priority.icon)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(task.priority.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(task.priority.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                // Discipline & Checkpoint Tags
                if let disc = task.disciplineName, !disc.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10))
                        Text(disc)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)

                        if let cp = task.checkpointTitle, !cp.isEmpty {
                            Text("•")
                                .font(.caption2)
                            Text(cp)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(AppTheme.susuBluePrimary)
                }

                // Notes snippet
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Due Date Pill
                if let due = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(formatDueDate(due))
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundColor(dueDateColor(due))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(dueDateColor(due).opacity(0.12))
                    .cornerRadius(6)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .contextMenu {
            Button {
                onToggleStatus()
            } label: {
                Label(task.status == .completed ? "Вернуть в активные" : "Отметить выполненной",
                      systemImage: task.status == .completed ? "arrow.uturn.backward" : "checkmark.circle")
            }

            Menu("Перенести дедлайн") {
                Button("+1 день") { onPostpone(1) }
                Button("+3 дня") { onPostpone(3) }
                Button("+1 неделя") { onPostpone(7) }
            }

            Button {
                onEdit()
            } label: {
                Label("Редактировать", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить задачу", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                onToggleStatus()
            } label: {
                Label(task.status == .completed ? "В работу" : "Готово",
                      systemImage: task.status == .completed ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(task.status == .completed ? .orange : .green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }

            Button {
                onPostpone(1)
            } label: {
                Label("+1 день", systemImage: "clock.arrow.2.circlepath")
            }
            .tint(.blue)
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let timeStr = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
            return "Сегодня в \(timeStr)"
        } else if cal.isDateInTomorrow(date) {
            let timeStr = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
            return "Завтра в \(timeStr)"
        } else if cal.isDateInYesterday(date) {
            return "Вчера (просрочено)"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "d MMM, HH:mm"
            return formatter.string(from: date)
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        if task.status == .completed { return .secondary }
        if task.isOverdue { return AppTheme.dangerRed }
        if task.isDueToday { return AppTheme.warningOrange }
        return AppTheme.susuBluePrimary
    }
}
