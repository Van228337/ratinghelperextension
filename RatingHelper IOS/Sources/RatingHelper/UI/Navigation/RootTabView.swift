import SwiftUI

extension Notification.Name {
    public static let scrollToTopTab = Notification.Name("scrollToTopTab")
}

public struct RootTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Int = 0

    private var tabSelectionBinding: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    NotificationCenter.default.post(
                        name: .scrollToTopTab,
                        object: nil,
                        userInfo: ["tabIndex": newTab]
                    )
                }
                selectedTab = newTab
            }
        )
    }

    public var body: some View {
        Group {
            if !appState.isLoggedIn {
                LoginView()
            } else {
                TabView(selection: tabSelectionBinding) {
                    SubjectsView()
                        .tabItem {
                            Label("Дисциплины", systemImage: "books.vertical.fill")
                        }
                        .tag(0)

                    ScheduleView()
                        .tabItem {
                            Label("Расписание", systemImage: "calendar")
                        }
                        .tag(1)

                    TasksView()
                        .tabItem {
                            Label("План", systemImage: "checklist")
                        }
                        .tag(2)

                    if appState.settings.semesterDashboard {
                        SemesterDashboardView()
                            .tabItem {
                                Label("Сводка", systemImage: "chart.bar.xaxis")
                            }
                            .tag(3)
                    }

                    SettingsView()
                        .tabItem {
                            Label("Настройки", systemImage: "gearshape.fill")
                        }
                        .tag(4)
                }
            }
        }
    }
}
