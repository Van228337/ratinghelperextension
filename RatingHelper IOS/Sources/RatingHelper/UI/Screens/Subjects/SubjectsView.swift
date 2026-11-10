import SwiftUI

public struct SubjectsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: SubjectTab = .active
    @State private var searchText: String = ""

    public enum SubjectTab: String, CaseIterable {
        case active = "Активные"
        case archived = "Архив"
    }

    private var filteredSubjects: [Subject] {
        let list = appState.subjects.filter {
            selectedTab == .active ? !$0.isHidden : $0.isHidden
        }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return list
        }
        let query = searchText.lowercased()
        return list.filter {
            $0.disciplineName.lowercased().contains(query) ||
            $0.instructor.lowercased().contains(query) ||
            $0.controlType.lowercased().contains(query)
        }
    }

    private var groupedSubjects: [(AssessmentType, [Subject])] {
        let order: [AssessmentType] = [.coursework, .exam, .zachet, .diffZachet, .practice, .courseProject, .unknown]
        return order.compactMap { type in
            let items = filteredSubjects.filter { $0.assessmentType == type }
            return items.isEmpty ? nil : (type, items)
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Селектор семестра и фильтр архива
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(AppTheme.susuBluePrimary)
                        Text("Семестр:")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)

                        Picker("Семестр", selection: $appState.selectedTerm) {
                            ForEach(1...10, id: \.self) { term in
                                Text("\(term)").tag(term)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.susuBluePrimary)
                        .onChange(of: appState.selectedTerm) { _, newTerm in
                            Task {
                                await appState.changeTerm(newTerm)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .cornerRadius(10)

                    Spacer()

                    Picker("Вкладка", selection: $selectedTab) {
                        ForEach(SubjectTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                    .onChange(of: selectedTab) { _, newTab in
                        appState.setArchiveTab(newTab == .archived ? "archived" : "active")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)

                // Индикатор синхронизации и офлайн-режима
                if appState.isOfflineMode {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                        Text("Офлайн-режим • Синхронизировано: \(appState.lastSyncDescription ?? "сохранено ранее")")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                } else if let sync = appState.lastSyncDescription {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.successGreen)
                        Text("Синхронизировано: \(sync)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)
                    .padding(.vertical, 3)
                }

                Divider()

                if appState.isLoading && appState.subjects.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Загрузка дисциплин ЮУрГУ...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredSubjects.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: selectedTab == .active ? "books.vertical.fill" : "archivebox.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(selectedTab == .active ? "Нет активных дисциплин" : "Архив пуст")
                            .font(.headline)
                        Text(selectedTab == .active
                             ? "В этом семестре предметы не найдены или скрыты в архив."
                             : "Скрытые предметы появятся здесь.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        List {
                            Color.clear.frame(height: 0).id("subjects_top_anchor")
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)

                            ForEach(groupedSubjects, id: \.0) { group in
                            Section {
                                ForEach(group.1) { subject in
                                    if subject.hasJournal {
                                        NavigationLink {
                                            JournalView(subject: subject)
                                        } label: {
                                            SubjectCardView(subject: subject) {
                                                Task {
                                                    await appState.toggleSubjectHidden(subject)
                                                }
                                            }
                                        }
                                    } else {
                                        SubjectCardView(subject: subject) {
                                            Task {
                                                await appState.toggleSubjectHidden(subject)
                                            }
                                        }
                                    }
                                }
                            } header: {
                                HStack(spacing: 8) {
                                    Image(systemName: group.0.icon)
                                    Text(group.0 == .unknown ? "Другие дисциплины" : group.0.rawValue)
                                }
                                .font(.headline)
                                .foregroundStyle(group.0.badgeColor)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await appState.loadSubjects(forceRefresh: true)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToTopTab)) { notif in
                        if let tabIdx = notif.userInfo?["tabIndex"] as? Int, tabIdx == 0 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo("subjects_top_anchor", anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Дисциплины")
        .searchable(text: $searchText, prompt: "Поиск предмета или преподавателя")
        .onAppear {
            if appState.selectedArchiveTab == "archived" {
                selectedTab = .archived
            } else {
                selectedTab = .active
            }
        }
    }
}
}
