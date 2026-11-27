import SwiftUI

@main
public struct RatingHelperApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .preferredColorScheme(appState.themeMode.colorScheme)
                .tint(AppTheme.susuBluePrimary)
                .onAppear {
                    TaskNotificationManager.shared.clearBadgeAndDeliveredNotifications()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        TaskNotificationManager.shared.clearBadgeAndDeliveredNotifications()
                    }
                }
        }
    }
}
