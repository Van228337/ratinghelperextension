import SwiftUI

@main
public struct RatingHelperApp: App {
    @StateObject private var appState = AppState()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .preferredColorScheme(appState.themeMode.colorScheme)
                .tint(AppTheme.susuBluePrimary)
        }
    }
}
