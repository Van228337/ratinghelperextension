import SwiftUI

public struct AdminView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: AdminTab = .users
    @State private var users: [SupabaseAppUser] = []
    @State private var reviews: [TeacherReview] = []
    @State private var materials: [MaterialItem] = []
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil
    @State private var searchQuery: String = ""

    // Ban dialog state
    @State private var userToBan: SupabaseAppUser? = nil
    @State private var banReasonInput: String = "Нарушение правил сообщества"
    @State private var showingBanAlert: Bool = false

    public enum AdminTab: String, CaseIterable {
        case users = "Пользователи"
        case reviews = "Отзывы"
        case materials = "Материалы"
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Вкладка", selection: $selectedTab) {
                    ForEach(AdminTab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

                if let msg = statusMessage {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                        Text(msg)
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }

                if isLoading {
                    Spacer()
                    ProgressView("Загрузка...")
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
            .onChange(of: selectedTab) { _, _ in
                searchQuery = ""
                Task { await loadData() }
            }
            .alert("Блокировка пользователя", isPresented: $showingBanAlert) {
                TextField("Причина блокировки", text: $banReasonInput)
                Button("Заблокировать", role: .destructive) {
                    confirmBanUser()
                }
                Button("Отмена", role: .cancel) {
                    userToBan = nil
                }
            } message: {
                if let u = userToBan {
                    Text("Укажите причину блокировки для студента \(u.fullName ?? u.username ?? u.userId):")
                }
            }
        }
    }

    private var searchPrompt: String {
        switch selectedTab {
        case .users: return "Поиск по имени, логину, группе"
        case .reviews: return "Поиск по преподавателю или тексту"
        case .materials: return "Поиск по названию материала"
        }
    }

    private func loadData() async {
        isLoading = true
        statusMessage = nil
        switch selectedTab {
        case .users:
            users = await SupabaseService.shared.getAllUsers()
        case .reviews:
            reviews = await SupabaseService.shared.getAllReviews()
        case .materials:
            materials = await SupabaseService.shared.getAllMaterials()
        }
        isLoading = false
    }

    // MARK: - Users Section

    private var filteredUsers: [SupabaseAppUser] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return users }
        return users.filter { u in
            (u.fullName?.lowercased().contains(q) ?? false) ||
            (u.username?.lowercased().contains(q) ?? false) ||
            (u.groupName?.lowercased().contains(q) ?? false) ||
            (u.email?.lowercased().contains(q) ?? false) ||
            (u.susuEmail?.lowercased().contains(q) ?? false) ||
            (u.unitName?.lowercased().contains(q) ?? false) ||
            u.userId.lowercased().contains(q)
        }
    }

    private var usersSection: some View {
        Section(header: Text("Всего пользователей: \(filteredUsers.count)")) {
            ForEach(filteredUsers, id: \.userId) { u in
                userCard(u)
            }
        }
    }

    private func userCard(_ u: SupabaseAppUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with Full Name and Badges
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.fullName ?? "Студент ЮУрГУ")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let un = u.username, !un.isEmpty {
                        Text("@\(un)")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if u.isAdmin {
                    Text("👑 Админ")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }

                if u.isBanned {
                    Text("🚫 Заблокирован")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                } else {
                    Text("✅ Активен")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }
            }

            // Student university details
            VStack(alignment: .leading, spacing: 4) {
                if let grp = u.groupName, !grp.isEmpty {
                    Label(grp, systemImage: "person.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                }

                if let unit = u.unitName, !unit.isEmpty {
                    Label(unit, systemImage: "building.columns.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let spec = u.specialityName, !spec.isEmpty {
                    Label(spec, systemImage: "graduationcap.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let mail = u.susuEmail ?? u.email, !mail.isEmpty {
                    Label(mail, systemImage: "envelope.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    if let ver = u.appVersion, !ver.isEmpty {
                        Text("Версия: \(ver)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if let act = u.lastActive {
                        Text("Активность: \(act.prefix(10))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if let reason = u.banReason, !reason.isEmpty, u.isBanned {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundColor(.red)
                        Text("Причина: \(reason)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(6)
                }
            }

            Divider()

            // Actions row
            HStack(spacing: 8) {
                Button {
                    toggleUserMaterials(u)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: u.canViewMaterials ? "eye.slash" : "eye.fill")
                        Text(u.canViewMaterials ? "Скрыть работы" : "Открыть работы")
                    }
                    .font(.caption2.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(u.canViewMaterials ? .orange : .blue)

                Spacer()

                if u.isBanned {
                    Button("Разблокировать") {
                        unbanUser(u)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .font(.caption2.weight(.semibold))
                } else {
                    Button("Заблокировать") {
                        userToBan = u
                        banReasonInput = "Нарушение правил сообщества"
                        showingBanAlert = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .font(.caption2.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleUserMaterials(_ u: SupabaseAppUser) {
        let newVal = !u.canViewMaterials
        Task {
            do {
                _ = try await SupabaseService.shared.adminSetUserStatus(
                    adminUserId: appState.effectiveUserId,
                    targetUserId: u.userId,
                    canViewMaterials: newVal
                )
                if let idx = users.firstIndex(where: { $0.userId == u.userId }) {
                    users[idx].canViewMaterials = newVal
                }
                statusMessage = "Статус материалов для \(u.fullName ?? u.userId) обновлен"
            } catch {
                statusMessage = "Ошибка: \(error.localizedDescription)"
            }
        }
    }

    private func unbanUser(_ u: SupabaseAppUser) {
        Task {
            do {
                _ = try await SupabaseService.shared.adminSetUserStatus(
                    adminUserId: appState.effectiveUserId,
                    targetUserId: u.userId,
                    isBanned: false,
                    banReason: ""
                )
                if let idx = users.firstIndex(where: { $0.userId == u.userId }) {
                    users[idx].isBanned = false
                    users[idx].banReason = nil
                }
                statusMessage = "Пользователь \(u.fullName ?? u.userId) разблокирован"
            } catch {
                statusMessage = "Ошибка: \(error.localizedDescription)"
            }
        }
    }

    private func confirmBanUser() {
        guard let u = userToBan else { return }
        let reason = banReasonInput.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                _ = try await SupabaseService.shared.adminSetUserStatus(
                    adminUserId: appState.effectiveUserId,
                    targetUserId: u.userId,
                    isBanned: true,
                    banReason: reason.isEmpty ? "Блокировка администратором" : reason
                )
                if let idx = users.firstIndex(where: { $0.userId == u.userId }) {
                    users[idx].isBanned = true
                    users[idx].banReason = reason
                }
                statusMessage = "Пользователь \(u.fullName ?? u.userId) заблокирован"
            } catch {
                statusMessage = "Ошибка блокировки: \(error.localizedDescription)"
            }
            userToBan = nil
        }
    }

    // MARK: - Reviews Section

    private var filteredReviews: [TeacherReview] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return reviews }
        return reviews.filter { r in
            r.teacherName.lowercased().contains(q) ||
            r.text.lowercased().contains(q)
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

                    Text(r.text)
                        .font(.footnote)
                        .foregroundColor(.primary)

                    HStack {
                        Text("👍 \(r.likes)  👎 \(r.dislikes)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(role: .destructive) {
                            deleteReview(r)
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

    // MARK: - Materials Section

    private var filteredMaterials: [MaterialItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return materials }
        return materials.filter { m in
            m.title.lowercased().contains(q) ||
            m.fileName.lowercased().contains(q) ||
            (m.teacherName?.lowercased().contains(q) ?? false)
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

                    Text("\(m.fileName) • \(m.teacherName ?? "Без преподавателя")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            deleteMaterial(m)
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

    private func deleteReview(_ r: TeacherReview) {
        Task {
            do {
                try await SupabaseService.shared.deleteReview(id: r.id)
                reviews.removeAll(where: { $0.id == r.id })
                statusMessage = "Отзыв успешно удалён"
            } catch {
                statusMessage = "Ошибка удаления отзыва: \(error.localizedDescription)"
            }
        }
    }

    private func deleteMaterial(_ m: MaterialItem) {
        Task {
            do {
                try await SupabaseService.shared.deleteMaterial(id: m.id)
                materials.removeAll(where: { $0.id == m.id })
                statusMessage = "Материал успешно удалён"
            } catch {
                statusMessage = "Ошибка удаления материала: \(error.localizedDescription)"
            }
        }
    }
}
