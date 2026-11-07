import SwiftUI

public struct AdminView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AdminTab = .users
    @State private var users: [SupabaseAppUser] = []
    @State private var reviews: [TeacherReview] = []
    @State private var materials: [MaterialItem] = []
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil

    public enum AdminTab: String, CaseIterable {
        case users = "Пользователи"
        case reviews = "Отзывы"
        case materials = "Материалы"
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Вкладка", selection: $selectedTab) {
                    ForEach(AdminTab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if let msg = statusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.bottom, 6)
                }

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Task { await loadData() }
            }
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

    private var usersSection: some View {
        ForEach(users, id: \.userId) { u in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                    Text("Студент")
                        .font(.headline)
                    if u.isAdmin {
                        Text("👑 Админ")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.purple)
                    }
                    Spacer()
                    if let act = u.lastActive {
                        Text(act.prefix(10))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Text(u.userId)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Button(u.canViewMaterials ? "👀 Работы: ВКЛ" : "🙈 Работы: СКРЫТЫ") {
                        toggleUserMaterials(u)
                    }
                    .buttonStyle(.bordered)
                    .tint(u.canViewMaterials ? .blue : .gray)
                    .font(.caption2)

                    Button(u.isBanned ? "🚫 Забанен" : "✅ Активен") {
                        toggleUserBan(u)
                    }
                    .buttonStyle(.bordered)
                    .tint(u.isBanned ? .red : .green)
                    .font(.caption2)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var reviewsSection: some View {
        ForEach(reviews) { r in
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

    private var materialsSection: some View {
        ForEach(materials) { m in
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

    private func toggleUserMaterials(_ u: SupabaseAppUser) {
        Task {
            do {
                let newVal = !u.canViewMaterials
                try await SupabaseService.shared.updateUser(userId: u.userId, updates: ["can_view_materials": newVal])
                if let idx = users.firstIndex(where: { $0.userId == u.userId }) {
                    users[idx].canViewMaterials = newVal
                }
            } catch {
                statusMessage = "Ошибка: \(error.localizedDescription)"
            }
        }
    }

    private func toggleUserBan(_ u: SupabaseAppUser) {
        Task {
            do {
                let newVal = !u.isBanned
                try await SupabaseService.shared.updateUser(userId: u.userId, updates: ["is_banned": newVal])
                if let idx = users.firstIndex(where: { $0.userId == u.userId }) {
                    users[idx].isBanned = newVal
                }
            } catch {
                statusMessage = "Ошибка: \(error.localizedDescription)"
            }
        }
    }

    private func deleteReview(_ r: TeacherReview) {
        Task {
            do {
                try await SupabaseService.shared.deleteReview(id: r.id)
                reviews.removeAll(where: { $0.id == r.id })
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
            } catch {
                statusMessage = "Ошибка удаления материала: \(error.localizedDescription)"
            }
        }
    }
}
