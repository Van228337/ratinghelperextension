import SwiftUI

public struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    public var body: some View {
        Group {
            if !appState.isLoggedIn {
                LoginView()
            } else {
                TabView {
                    SubjectsView()
                        .tabItem {
                            Label("Дисциплины", systemImage: "books.vertical.fill")
                        }

                    ScheduleView()
                        .tabItem {
                            Label("Расписание", systemImage: "calendar")
                        }

                    TasksView()
                        .tabItem {
                            Label("План", systemImage: "checklist")
                        }

                    if appState.settings.semesterDashboard {
                        SemesterDashboardView()
                            .tabItem {
                                Label("Сводка", systemImage: "chart.bar.xaxis")
                            }
                    }

                    SettingsView()
                        .tabItem {
                            Label("Настройки", systemImage: "gearshape.fill")
                        }
                }
            }
        }
    }
}
