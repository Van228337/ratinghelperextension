import SwiftUI

public struct AdminView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var selectedTab: AdminTab = .users
    @State private var users: [SupabaseAppUser] = []
    @State private var reviews: [TeacherReview] = []
    @State private var materials: [MaterialItem] = []
    @State private var auditLogs: [AdminAuditLogItem] = []
    @State private var stats: AdminInfrastructureStats? = nil

    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil
    @State private var searchQuery: String = ""

    // Permissions management state
    @State private var selectedUserForPermissions: SupabaseAppUser? = nil
    @State private var editCanUpload: Bool = true
    @State private var editCanView: Bool = true
    @State private var editCanReview: Bool = true
    @State private var editCooldownSeconds: Int = 60
    @State private var editSanctionReason: String = ""
    @State private var editDurationHours: Int = 0
    @State private var showingPermissionsSheet: Bool = false

    // Deletion states
    @State private var reviewToDelete: TeacherReview? = nil
    @State private var showingDeleteReviewAlert: Bool = false
    @State private var materialToDelete: MaterialItem? = nil
    @State private var showingDeleteMaterialAlert: Bool = false

    private var masterSecret: String {
        UserDefaults.standard.string(forKey: "saved_admin_master_key") ?? "rh_admin_susu_2026"
    }

    public enum AdminTab: String, CaseIterable, Identifiable {
        case users = "Пользователи"
        case reviews = "Отзывы"
        case materials = "Материалы"
        case groq = "Groq"
        case audit = "Аудит"
        case stats = "Инфраструктура"

        public var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Tab Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(AdminTab.allCases) { tab in
                            Button {
                                selectedTab = tab
                                searchQuery = ""
                            } label: {
                                Text(tab.rawValue)
                                    .font(.caption.weight(selectedTab == tab ? .bold : .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selectedTab == tab ? Color.purple : Color(uiColor: .secondarySystemFill))
                                    .foregroundColor(selectedTab == tab ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if let msg = statusMessage {
                    HStack {
                        Image(systemName: "info.circle.fill")
                        Text(msg)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }

                if isLoading {
                    Spacer()
                    ProgressView("Синхронизация с сервером...")
                    Spacer()
                } else {
                    List {
                        switch selectedTab {
                        case .users:
                            usersSection
                        case .reviews:
                            reviewsSection
                        case .materials:
                            materialsSection
                        case .groq:
                            groqSection
                        case .audit:
                            auditSection
                        case .stats:
                            statsSection
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchQuery, prompt: searchPrompt)
                }
            }
            .navigationTitle("Панель администратора")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadData()
            }
            .sheet(isPresented: $showingPermissionsSheet) {
                permissionsSheet
            }
            .alert("Удалить отзыв?", isPresented: $showingDeleteReviewAlert, presenting: reviewToDelete) { rev in
                Button("Удалить", role: .destructive) {
                    Task { await confirmDeleteReview(rev) }
                }
                Button("Отмена", role: .cancel) {}
            } message: { rev in
                Text("Отзыв по преподавателю «\(rev.teacherName)» будет удалён из базы.")
            }
            .alert("Удалить материал?", isPresented: $showingDeleteMaterialAlert, presenting: materialToDelete) { mat in
                Button("Удалить", role: .destructive) {
                    Task { await confirmDeleteMaterial(mat) }
                }
                Button("Отмена", role: .cancel) {}
            } message: { mat in
                Text("Материал «\(mat.title)» будет удалён из базы и очищен с диска.")
            }
        }
    }

    private var searchPrompt: String {
        switch selectedTab {
        case .users: return "Поиск по UUID, логину, группе"
        case .reviews: return "Поиск по преподавателю, предмету, тексту"
        case .materials: return "Поиск по названию файла"
        case .groq: return "Поиск пользователя в квотах"
        case .audit: return "Поиск действия в журнале"
        case .stats: return "Поиск"
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        statusMessage = nil

        // Попытка загрузить полный административный дашборд через RPC
        if let data = try? await SupabaseService.shared.getAdminDashboardData(secret: masterSecret) {
            self.users = data.users
            self.auditLogs = data.auditLogs
            self.stats = data.stats
        } else {
            // Fallback REST
            self.users = await SupabaseService.shared.getAllUsers()
        }

        // Загрузка отзывов и материалов
        self.reviews = await SupabaseService.shared.getAllReviews()
        self.materials = await SupabaseService.shared.getAllMaterials()

        isLoading = false
    }

    // MARK: - Users Tab

    private var filteredUsers: [SupabaseAppUser] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return users }
        return users.filter { u in
            u.userId.lowercased().contains(q) ||
            (u.username?.lowercased().contains(q) ?? false) ||
            (u.groupName?.lowercased().contains(q) ?? false)
        }
    }

    private var usersSection: some View {
        Section(header: Text("Пользователи (\(filteredUsers.count))")) {
            ForEach(filteredUsers, id: \.userId) { u in
                userCard(u)
            }
        }
    }

    private func userCard(_ u: SupabaseAppUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: User identity without personal data
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("@\(u.username ?? "user")")
                            .font(.headline)
                        if u.isAdmin {
                            Text("👑 Админ")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .cornerRadius(6)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("UUID:")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text(u.userId.prefix(8) + "...")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                        Button {
                            UIPasteboard.general.string = u.userId
                            statusMessage = "UUID скопирован в буфер обмена"
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                if let grp = u.groupName, !grp.isEmpty {
                    Text(grp)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }

            // Permissions Status Indicators
            HStack(spacing: 8) {
                permissionPill(title: "Загрузка", allowed: u.canUploadFiles, icon: "arrow.up.doc")
                permissionPill(title: "Просмотр", allowed: u.canViewMaterials, icon: "eye")
                permissionPill(title: "Отзывы", allowed: u.canPublishReviews, icon: "pencil.line")
            }

            // User activity & usage statistics
            HStack(spacing: 12) {
                Label("\(u.uploadCount) файн.", systemImage: "folder")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Label("\(u.reviewsCount) отз.", systemImage: "bubble.left")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Label("\(u.groqModerationCalls) Groq", systemImage: "cpu")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let reason = u.sanctionReason, !reason.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundColor(.orange)
                    Text("Санкция: \(reason)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            }

            Divider()

            HStack {
                Text(u.lastActive != nil ? "Активен: \(u.lastActive!.prefix(10))" : "Недавно")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    openPermissionsEditor(for: u)
                } label: {
                    Label("Настроить права", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            }
        }
        .padding(.vertical, 6)
    }

    private func permissionPill(title: String, allowed: Bool, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: allowed ? icon : "xmark.shield.fill")
                .font(.system(size: 9))
            Text(title)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(allowed ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
        .foregroundColor(allowed ? .green : .red)
        .cornerRadius(6)
    }

    // MARK: - Permissions Editor Sheet

    private func openPermissionsEditor(for u: SupabaseAppUser) {
        self.selectedUserForPermissions = u
        self.editCanUpload = u.canUploadFiles
        self.editCanView = u.canViewMaterials
        self.editCanReview = u.canPublishReviews
        self.editCooldownSeconds = u.reviewEditCooldownSeconds
        self.editSanctionReason = u.sanctionReason ?? ""
        self.editDurationHours = 0
        self.showingPermissionsSheet = true
    }

    private var permissionsSheet: some View {
        NavigationStack {
            Form {
                if let u = selectedUserForPermissions {
                    Section(header: Text("Пользователь")) {
                        Text("@\(u.username ?? "user")")
                            .font(.headline)
                        Text("UUID: \(u.userId)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        if let g = u.groupName {
                            Text("Группа: \(g)")
                                .font(.footnote)
                        }
                    }

                    Section(header: Text("Независимые разрешения")) {
                        Toggle("Загрузка файлов (can_upload_files)", isOn: $editCanUpload)
                        Toggle("Просмотр материалов (can_view_materials)", isOn: $editCanView)
                        Toggle("Публикация отзывов (can_publish_reviews)", isOn: $editCanReview)
                    }

                    Section(header: Text("Защита от спама отзывов")) {
                        Stepper("Кулдаун между отзывами: \(editCooldownSeconds) сек.", value: $editCooldownSeconds, in: 10...600, step: 10)
                    }

                    Section(header: Text("Параметры ограничения")) {
                        TextField("Причина ограничения / санкции", text: $editSanctionReason)

                        Picker("Срок действия", selection: $editDurationHours) {
                            Text("Бессрочно").tag(0)
                            Text("1 час").tag(1)
                            Text("24 часа (сутки)").tag(24)
                            Text("7 дней (неделя)").tag(168)
                        }
                    }

                    Section {
                        Button("Сбросить все ограничения") {
                            editCanUpload = true
                            editCanView = true
                            editCanReview = true
                            editSanctionReason = ""
                            editDurationHours = 0
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Управление доступом")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { showingPermissionsSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        savePermissions()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func savePermissions() {
        guard let u = selectedUserForPermissions else { return }
        let durationParam = editDurationHours > 0 ? editDurationHours : nil
        let reasonParam = editSanctionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editSanctionReason

        Task {
            do {
                _ = try await SupabaseService.shared.adminSetUserPermissions(
                    masterSecret: masterSecret,
                    adminUserId: appState.effectiveUserId,
                    targetUserId: u.userId,
                    canUploadFiles: editCanUpload,
                    canViewMaterials: editCanView,
                    canPublishReviews: editCanReview,
                    cooldownSeconds: editCooldownSeconds,
                    sanctionReason: reasonParam,
                    sanctionDurationHours: durationParam
                )

                if let idx = users.firstIndex(where: { $0.userId == u.userId }) {
                    users[idx].canUploadFiles = editCanUpload
                    users[idx].canViewMaterials = editCanView
                    users[idx].canPublishReviews = editCanReview
                    users[idx].reviewEditCooldownSeconds = editCooldownSeconds
                    users[idx].sanctionReason = reasonParam
                }

                statusMessage = "Права пользователя @\(u.username ?? u.userId) успешно сохранены"
                showingPermissionsSheet = false
            } catch {
                statusMessage = "Ошибка сохранения: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Reviews Tab

    private var filteredReviews: [TeacherReview] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return reviews }
        return reviews.filter { r in
            r.teacherName.lowercased().contains(q) ||
            (r.subjectName?.lowercased().contains(q) ?? false) ||
            r.text.lowercased().contains(q) ||
            (r.userId?.lowercased().contains(q) ?? false)
        }
    }

    private var reviewsSection: some View {
        Section(header: Text("Всего отзывов: \(filteredReviews.count)")) {
            ForEach(filteredReviews) { r in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("👨‍🏫 \(r.teacherName)")
                            .font(.headline)
                        Spacer()
                        Text("📅 \(r.year)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let subj = r.subjectName, !subj.isEmpty {
                        Text("Дисциплина: \(subj)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Text(r.text)
                        .font(.footnote)
                        .foregroundColor(.primary)

                    HStack {
                        if r.editCount > 0 {
                            Text("Правки: \(r.editCount)")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.orange)
                        }

                        if let author = r.userId {
                            Text("Автор: \(author.prefix(8))...")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            reviewToDelete = r
                            showingDeleteReviewAlert = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func confirmDeleteReview(_ r: TeacherReview) async {
        do {
            try await SupabaseService.shared.deleteReview(id: r.id, userId: appState.effectiveUserId, isAdmin: true)
            reviews.removeAll(where: { $0.id == r.id })
            statusMessage = "Отзыв успешно удалён"
        } catch {
            statusMessage = "Ошибка удаления отзыва: \(error.localizedDescription)"
        }
    }

    // MARK: - Materials Tab

    private var filteredMaterials: [MaterialItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return materials }
        return materials.filter { m in
            m.title.lowercased().contains(q) ||
            m.fileName.lowercased().contains(q) ||
            (m.teacherName?.lowercased().contains(q) ?? false) ||
            (m.userId?.lowercased().contains(q) ?? false)
        }
    }

    private var materialsSection: some View {
        Section(header: Text("Всего материалов: \(filteredMaterials.count)")) {
            ForEach(filteredMaterials) { m in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("📄 \(m.title)")
                            .font(.headline)
                        Spacer()
                        Text("📅 \(m.year)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text(m.fileName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if m.fileSizeBytes > 0 {
                            Text(String(format: "• %.2f МБ", Double(m.fileSizeBytes) / 1024.0 / 1024.0))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }

                    HStack {
                        if let author = m.userId {
                            Text("Автор: \(author.prefix(8))...")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            materialToDelete = m
                            showingDeleteMaterialAlert = true
                        } label: {
                            Label("Удалить файл", systemImage: "trash")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func confirmDeleteMaterial(_ m: MaterialItem) async {
        do {
            // Удаление из БД
            try await SupabaseService.shared.deleteMaterial(id: m.id)

            // Если есть Drive file ID, удаляем и с Google Drive
            if let driveId = m.driveFileId, !driveId.isEmpty {
                await GoogleDriveService.shared.deleteFile(fileId: driveId)
            }

            materials.removeAll(where: { $0.id == m.id })
            statusMessage = "Материал успешно удалён"
        } catch {
            statusMessage = "Ошибка удаления материала: \(error.localizedDescription)"
        }
    }

    // MARK: - Groq Quota Tab

    private var groqSection: some View {
        Group {
            Section(header: Text("Сводка использования Groq")) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Всего вызовов")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(stats?.totalGroqCalls ?? users.reduce(0, { $0 + $1.groqModerationCalls }))")
                            .font(.title2.weight(.bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Потреблено токенов")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(stats?.totalGroqTokens ?? users.reduce(0, { $0 + $1.groqTokensUsed }))")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.purple)
                    }
                }
                .padding(.vertical, 4)

                Text("Бесплатный тариф Groq: 30 запросов в минуту, до 14 400 запросов в сутки. Все запросы модерируются через pre-filter и 6-часовой кэш Google Apps Script.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Пользователи с наибольшим расходом")) {
                let sortedByGroq = users.sorted(by: { $0.groqModerationCalls > $1.groqModerationCalls })
                ForEach(sortedByGroq.prefix(15), id: \.userId) { u in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(u.username ?? "user")")
                                .font(.subheadline.weight(.semibold))
                            Text("UUID: \(u.userId.prefix(8))...")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(u.groqModerationCalls) запросов")
                                .font(.subheadline.weight(.bold))
                            Text("\(u.groqTokensUsed) токенов")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Audit Log Tab

    private var auditSection: some View {
        Section(header: Text("Журнал действий администраторов (\(auditLogs.count))")) {
            if auditLogs.isEmpty {
                Text("Журнал аудита пуст.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(auditLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.action)
                                .font(.caption.weight(.bold))
                                .foregroundColor(.purple)
                            Spacer()
                            Text(log.createdAt.prefix(19).replacingOccurrences(of: "T", with: " "))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        if let target = log.targetUserId {
                            Text("Целевой пользователь: \(target.prefix(8))...")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.primary)
                        }

                        if let reason = log.reason, !reason.isEmpty {
                            Text("Детали: \(reason)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Infrastructure Tab

    private var statsSection: some View {
        Group {
            Section(header: Text("Показатели платформы")) {
                metricRow(title: "Всего пользователей", value: "\(stats?.totalUsers ?? users.count)")
                metricRow(title: "Активных за 24 часа", value: "\(stats?.activeUsers24h ?? 0)")
                metricRow(title: "Пользователей с ограничениями", value: "\(stats?.sanctionedUsers ?? users.filter({ !$0.canUploadFiles || !$0.canPublishReviews || !$0.canViewMaterials }).count)")
                metricRow(title: "Опубликовано отзывов", value: "\(stats?.totalReviews ?? reviews.count)")
                metricRow(title: "Загружено материалов", value: "\(stats?.totalMaterials ?? materials.count)")
                if let bytes = stats?.totalStorageBytes {
                    metricRow(title: "Занято на Google Drive", value: String(format: "%.2f МБ / 15 360 МБ", Double(bytes) / 1024.0 / 1024.0))
                }
            }

            Section(header: Text("Статус бесплатной инфраструктуры")) {
                serviceStatusRow(service: "Supabase PostgreSQL", desc: "База данных (Free Tier, 500 МБ лимит)", status: "OK")
                serviceStatusRow(service: "Google Drive Storage", desc: "Файловое хранилище (15 ГБ бесплатно)", status: "OK")
                serviceStatusRow(service: "Google Apps Script", desc: "Серверный шлюз и кэш", status: "OK")
                serviceStatusRow(service: "Groq Llama 3.3 70B", desc: "Модерация и саммари (Free API)", status: "OK")
            }
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primary)
        }
    }

    private func serviceStatusRow(service: String, desc: String, status: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(service)
                    .font(.subheadline.weight(.medium))
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(status)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .foregroundColor(.green)
                .cornerRadius(6)
        }
    }
}
