import SwiftUI

public enum AppThemeMode: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public struct AppTheme {
    // ЮУрГУ Фирменный синий (адаптируется под тему)
    public static let susuBlue = Color("SusuBlue", bundle: nil)
    public static let susuBluePrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.55, blue: 0.96, alpha: 1.0) // #478CF5
            : UIColor(red: 0.08, green: 0.33, blue: 0.65, alpha: 1.0) // #1554A6 (Классический синий ЮУрГУ)
    })

    public static let susuAccent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.65, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.05, green: 0.40, blue: 0.80, alpha: 1.0)
    })

    // Поверхности и карточки (Native iOS)
    public static let background = Color(uiColor: .systemGroupedBackground)
    public static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    public static let tertiaryBackground = Color(uiColor: .tertiarySystemGroupedBackground)

    // Разделители и границы
    public static let separator = Color(uiColor: .separator)
    public static let subtleBorder = Color(uiColor: .separator).opacity(0.3)

    // Текст
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary

    // Статусы и шкалы
    public static let successGreen = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
            : UIColor(red: 0.13, green: 0.65, blue: 0.27, alpha: 1.0)
    })

    public static let warningOrange = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.62, blue: 0.18, alpha: 1.0)
            : UIColor(red: 0.92, green: 0.50, blue: 0.05, alpha: 1.0)
    })

    public static let dangerRed = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 1.0)
            : UIColor(red: 0.88, green: 0.18, blue: 0.18, alpha: 1.0)
    })
}
