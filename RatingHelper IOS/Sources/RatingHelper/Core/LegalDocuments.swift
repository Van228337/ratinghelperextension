import Foundation

/// Единая точка хранения адресов правовых документов.
///
/// При смене домена или адреса GitHub Pages достаточно изменить `baseURL` —
/// все ссылки в приложении обновятся автоматически.
public enum LegalDocuments {

    /// Базовый адрес опубликованных документов (GitHub Pages).
    public static let baseURL = URL(string: "https://van228337.github.io/ratinghelperextension/")!

    /// Опубликованный документ.
    public enum Document: String, CaseIterable, Identifiable {
        case privacyPolicy = "privacy-policy"
        case personalDataConsent = "personal-data-consent"
        case userAgreement = "user-agreement"

        public var id: String { rawValue }

        /// Название строки в настройках.
        public var title: String {
            switch self {
            case .privacyPolicy:
                return "Политика конфиденциальности"
            case .personalDataConsent:
                return "Согласие на обработку персональных данных"
            case .userAgreement:
                return "Пользовательское соглашение"
            }
        }

        /// Постоянная ссылка на опубликованную страницу документа.
        public var url: URL {
            LegalDocuments.baseURL.appendingPathComponent("\(rawValue).html")
        }
    }
}
