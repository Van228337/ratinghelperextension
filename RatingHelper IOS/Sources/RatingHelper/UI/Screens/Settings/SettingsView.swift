import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showingAdminPrompt: Bool = false
    @State private var adminPinInput: String = ""
    @State private var adminAuthError: String? = nil
    @State private var showingAdminView: Bool = false
    @State private var versionTapCount: Int = 0

    // Backup & Restore
    @State private var backupURL: URL? = nil
    @State private var showingShareBackup: Bool = false
    @State private var showingRestoreImporter: Bool = false
    @State private var backupStatusMessage: String? = nil

    public var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    // User Session Section
                    Section(header: Text("Учётная запись ЮУрГУ").id("settings_top_anchor")) {
                    if let session = appState.session {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.username)
                                    .font(.headline)
                                Text(session.rememberMe ? "Сессия сохранена (Keychain)" : "Временная сессия")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        Button(role: .destructive) {
                            Task {
                                await appState.logout()
                            }
                        } label: {
                            Label("Выйти из системы", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        Text("Вход не выполнен")
                            .foregroundColor(.secondary)
                    }
                }

                // Theme Mode Section
                Section(header: Text("Тема оформления")) {
                    Picker("Тема", selection: Binding(
                        get: { appState.themeMode },
                        set: { newMode in appState.setThemeMode(newMode) }
                    )) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Features Configuration
                Section(header: Text("Функции и отображение")) {
                    Toggle("Калькулятор целей", isOn: $appState.settings.targetCalc)
                    Toggle("Прогноз диапазона (Мин / Макс)", isOn: $appState.settings.rangeForecast)
                    Toggle("Быстрые действия («Всё на max»)", isOn: $appState.settings.quickActions)
                    Toggle("Оценка по шкале БРС", isOn: $appState.settings.academicGrade)
                    Toggle("Учёт экзамена / дифзачёта", isOn: $appState.settings.examMode)
                    Toggle("Сводка семестра (Дашборд)", isOn: $appState.settings.semesterDashboard)
                    Toggle("Сохранение планов моделирования", isOn: $appState.settings.saveDrafts)
                    Toggle("База студенческих работ", isOn: $appState.settings.communityMaterials)
                    Toggle("Отзывы о преподавателях", isOn: $appState.settings.teacherReviews)
                }
                .onChange(of: appState.settings) { _, newSettings in
                    Task {
                        await appState.updateSettings(newSettings)
                    }
                }

                // Documents
                Section(header: Text("Документы")) {
                    NavigationLink {
                        TranscriptSettingsView()
                    } label: {
                        Label("Выписка с оценками", systemImage: "doc.richtext")
                    }
                }

                // Backup and Restore Section
                Section(header: Text("Резервное копирование данных"), footer: Text("Используйте экспорт перед повторной переустановкой приложения через xtool для 100% сохранности всех смоделированных планов.")) {
                    Button {
                        exportBackup()
                    } label: {
                        Label("Экспорт резервной копии (JSON)", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingRestoreImporter = true
                    } label: {
                        Label("Восстановить из файла", systemImage: "square.and.arrow.down")
                    }

                    if let msg = backupStatusMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                // Admin Button if already unlocked
                if appState.appUser?.isAdmin == true {
                    Section(header: Text("Администрирование")) {
                        Button {
                            showingAdminView = true
                        } label: {
                            Label("Панель администратора", systemImage: "shield.lefthalf.filled")
                                .foregroundColor(.purple)
                        }
                    }
                }

                // Version and Secret Trigger
                Section {
                    VStack(alignment: .center, spacing: 4) {
                        Text("Rating Helper — Калькулятор БРС")
                            .font(.subheadline.weight(.semibold))

                        Button {
                            handleVersionTap()
                        } label: {
                            Text("Версия 2.1.0 (xtool native build)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text("Разработано для личного использования на iPhone")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Настройки")
            .sheet(isPresented: $showingShareBackup) {
                if let url = backupURL {
                    ActivityView(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showingRestoreImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let fileURL = urls.first else { return }
                    restoreBackup(from: fileURL)
                case .failure(let err):
                    backupStatusMessage = "Ошибка выбора файла: \(err.localizedDescription)"
                }
            }
            .alert("Вход администратора", isPresented: $showingAdminPrompt) {
                SecureField("Мастер-ключ", text: $adminPinInput)
                Button("Отмена", role: .cancel) {
                    adminPinInput = ""
                    adminAuthError = nil
                }
                Button("Войти") {
                    verifyAdminPin()
                }
            } message: {
                Text(adminAuthError ?? "Введите ключ доступа к панели администратора:")
            }
            .sheet(isPresented: $showingAdminView) {
                AdminView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTopTab)) { notif in
                if let tabIdx = notif.userInfo?["tabIndex"] as? Int, tabIdx == 4 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo("settings_top_anchor", anchor: .top)
                    }
                }
            }
        }
        }
    }

    private func handleVersionTap() {
        versionTapCount += 1
        if versionTapCount >= 5 {
            versionTapCount = 0
            adminPinInput = ""
            adminAuthError = nil
            showingAdminPrompt = true
        }
    }

    private func verifyAdminPin() {
        let pin = adminPinInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pin.isEmpty else { return }

        Task {
            let isValid = await SupabaseService.shared.verifyAdminMasterKey(secret: pin)
            if isValid {
                UserDefaults.standard.set(pin, forKey: "saved_admin_master_key")
                if var user = appState.appUser {
                    user.isAdmin = true
                    appState.appUser = user
                }
                showingAdminView = true
            } else {
                adminAuthError = "Неверный ключ доступа."
                showingAdminPrompt = true
            }
        }
    }

    private func exportBackup() {
        Task {
            if let url = await BackupService.shared.createBackup() {
                self.backupURL = url
                self.showingShareBackup = true
                self.backupStatusMessage = "Резервная копия подготовлена"
            } else {
                self.backupStatusMessage = "Не удалось создать копию"
            }
        }
    }

    private func restoreBackup(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            backupStatusMessage = "Нет доступа к файлу"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        Task {
            do {
                _ = try await BackupService.shared.restore(from: url)
                await appState.initialize()
                backupStatusMessage = "Данные успешно восстановлены!"
            } catch {
                backupStatusMessage = "Ошибка восстановления: \(error.localizedDescription)"
            }
        }
    }
}
