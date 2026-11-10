import SwiftUI

public struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    public var initialTask: StudyTask?
    public var prefilledSubject: Subject?
    public var prefilledCheckpoint: CheckpointItem?
    public var onSaved: (() -> Void)?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedSubjectId: String = ""
    @State private var selectedSubjectName: String = ""
    @State private var selectedCheckpointTitle: String = ""
    @State private var selectedCheckpointId: String = ""
    @State private var hasDueDate: Bool = true
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var priority: TaskPriority = .normal
    @State private var status: TaskStatus = .notStarted
    @State private var selectedReminders: Set<TaskReminderOption> = [.onDay, .dayBefore]

    public init(
        initialTask: StudyTask? = nil,
        prefilledSubject: Subject? = nil,
        prefilledCheckpoint: CheckpointItem? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.initialTask = initialTask
        self.prefilledSubject = prefilledSubject
        self.prefilledCheckpoint = prefilledCheckpoint
        self.onSaved = onSaved
    }

    private var availableCheckpoints: [String] {
        availableCheckpointItems.map { $0.title }
    }

    private var availableCheckpointItems: [CheckpointItem] {
        if let j = appState.currentJournal, j.disciplineId == selectedSubjectId {
            return j.allContinuousAssignments + j.attestation
        }
        return []
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Main Task Information
                Section(header: Text("Задача")) {
                    TextField("Название (например, Лабораторная №2)", text: $title)
                        .font(.body.weight(.medium))

                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Подробные требования, заметки или ссылка...")
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 70)
                    }
                }

                // Section 2: University Linkage
                Section(header: Text("Учебная привязка")) {
                    Picker("Дисциплина", selection: $selectedSubjectId) {
                        Text("Без предмета").tag("")
                        ForEach(appState.subjects) { sub in
                            Text(sub.disciplineName).tag(sub.disciplineId)
                        }
                    }
                    .onChange(of: selectedSubjectId) { _, newId in
                        if let match = appState.subjects.first(where: { $0.disciplineId == newId }) {
                            selectedSubjectName = match.disciplineName
                        } else {
                            selectedSubjectName = ""
                        }
                        selectedCheckpointTitle = ""
                        selectedCheckpointId = ""
                    }

                    if !availableCheckpoints.isEmpty {
                        Picker("Контрольная точка", selection: $selectedCheckpointTitle) {
                            Text("Без контрольной точки").tag("")
                            ForEach(availableCheckpoints, id: \.self) { cp in
                                Text(cp).tag(cp)
                            }
                        }
                        .onChange(of: selectedCheckpointTitle) { _, newTitle in
                            if let match = availableCheckpointItems.first(where: { $0.title == newTitle }) {
                                selectedCheckpointId = match.backendId ?? ""
                                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || availableCheckpoints.contains(title) {
                                    title = match.title
                                }
                            }
                        }
                    } else if !selectedCheckpointTitle.isEmpty {
                        HStack {
                            Text("Контрольная точка")
                            Spacer()
                            Text(selectedCheckpointTitle)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Section 3: Deadlines & Reminders
                Section(header: Text("Сроки и напоминания")) {
                    Toggle("Установить дедлайн", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Срок сдачи", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            .environment(\.locale, Locale(identifier: "ru_RU"))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Напоминания:")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)

                            ForEach(TaskReminderOption.allCases) { opt in
                                Button {
                                    if selectedReminders.contains(opt) {
                                        selectedReminders.remove(opt)
                                    } else {
                                        selectedReminders.insert(opt)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: selectedReminders.contains(opt) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(selectedReminders.contains(opt) ? AppTheme.susuBluePrimary : .secondary)
                                        Text(opt.title)
                                            .font(.footnote)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Section 4: Priority & Status
                Section(header: Text("Параметры")) {
                    Picker("Приоритет", selection: $priority) {
                        ForEach(TaskPriority.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Статус", selection: $status) {
                        ForEach(TaskStatus.allCases) { st in
                            Text(st.title).tag(st)
                        }
                    }
                }
            }
            .navigationTitle(initialTask != nil ? "Редактирование задачи" : "Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveTask()
                    }
                    .fontWeight(.bold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                setupInitialData()
            }
        }
    }

    private func setupInitialData() {
        if let existing = initialTask {
            self.title = existing.title
            self.notes = existing.notes
            self.selectedSubjectId = existing.disciplineId ?? ""
            self.selectedSubjectName = existing.disciplineName ?? ""
            self.selectedCheckpointTitle = existing.checkpointTitle ?? ""
            self.selectedCheckpointId = existing.checkpointId ?? ""
            self.hasDueDate = existing.dueDate != nil
            self.dueDate = existing.dueDate ?? Date()
            self.priority = existing.priority
            self.status = existing.status
            self.selectedReminders = Set(existing.reminderOptions)
        } else {
            if let sub = prefilledSubject {
                self.selectedSubjectId = sub.disciplineId
                self.selectedSubjectName = sub.disciplineName
            }
            if let cp = prefilledCheckpoint {
                self.selectedCheckpointTitle = cp.title
                self.selectedCheckpointId = cp.backendId ?? ""
                if self.title.isEmpty {
                    self.title = cp.title
                }
            }
        }
    }

    private func saveTask() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let finalDue = hasDueDate ? dueDate : nil
        let reminders = hasDueDate ? Array(selectedReminders) : []

        Task {
            // Запрос разрешений на уведомления, если выбраны напоминания
            if !reminders.isEmpty {
                _ = await TaskNotificationManager.shared.requestAuthorization()
            }

            if let existing = initialTask {
                var updated = existing
                updated.title = cleanTitle
                updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.disciplineId = selectedSubjectId.isEmpty ? nil : selectedSubjectId
                updated.disciplineName = selectedSubjectName.isEmpty ? nil : selectedSubjectName
                updated.checkpointTitle = selectedCheckpointTitle.isEmpty ? nil : selectedCheckpointTitle
                updated.checkpointId = selectedCheckpointId.isEmpty ? nil : selectedCheckpointId
                updated.customDeadline = finalDue
                updated.dueDate = finalDue
                updated.priority = priority
                updated.status = status
                updated.reminderOptions = reminders
                if status == .completed && existing.completedAt == nil {
                    updated.completedAt = Date()
                } else if status != .completed {
                    updated.completedAt = nil
                }

                await TaskManager.shared.updateTask(updated)
            } else {
                let newTask = StudyTask(
                    title: cleanTitle,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    disciplineId: selectedSubjectId.isEmpty ? nil : selectedSubjectId,
                    disciplineName: selectedSubjectName.isEmpty ? nil : selectedSubjectName,
                    checkpointId: selectedCheckpointId.isEmpty ? nil : selectedCheckpointId,
                    checkpointTitle: selectedCheckpointTitle.isEmpty ? nil : selectedCheckpointTitle,
                    termNumber: appState.selectedTerm,
                    sourceDeadline: finalDue,
                    customDeadline: finalDue,
                    dueDate: finalDue,
                    externalSource: selectedCheckpointId.isEmpty ? .manual : .checkpoint,
                    externalId: selectedCheckpointId.isEmpty ? nil : "checkpoint_\(selectedCheckpointId)",
                    priority: priority,
                    status: status,
                    reminderOptions: reminders
                )
                await TaskManager.shared.addTask(newTask)
            }

            onSaved?()
            dismiss()
        }
    }
}
