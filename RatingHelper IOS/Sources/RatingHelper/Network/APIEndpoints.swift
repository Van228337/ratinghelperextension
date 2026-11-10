import Foundation

public enum APIEndpoints {
    public static let susuBase = "https://online.susu.ru"
    public static let loginPage = "https://online.susu.ru/login"
    public static let loginAPI = "https://online.susu.ru/microgateway/api/auth/login"
    public static let updateTokenAPI = "https://online.susu.ru/microgateway/api/auth/UpdateToken"

    public static func subjects(term: Int) -> String {
        "https://online.susu.ru/microgateway/api/StudyActivity/Subjects/\(term)/ru"
    }

    public static func journal(disciplineId: String, term: Int, isCourseWork: Bool = false) -> String {
        "https://online.susu.ru/microgateway/api/StudyActivity/Journal/\(disciplineId)/\(term)/IsCourseWorkOrProject/\(isCourseWork ? "true" : "false")/ru"
    }

    public static func groupSchedule(groupId: String) -> String {
        "https://online.susu.ru/microgateway/api/Schedule/GetGroupSchedule/\(groupId)"
    }

    public static let supabaseURL = "https://ysrkzvqzlvpoeyxmywdd.supabase.co"
    public static let supabaseKey = "sb_publishable_zmYaWaMZW0hEkDeb9R_N8Q_BPJXNG_F"

    // Public endpoint of the deployed Google Apps Script gateway. The value
    // from app_config remains preferred; this fallback keeps moderation
    // available if a device cannot read app_config during a transient outage.
    public static let googleAppsScriptGateway = "https://script.google.com/macros/s/AKfycbwYhcWQFDtdDxRF_E8JEh9GZOT7Ps-uvoYKyWxNWTUhv9qMoLzxgSyIUvVORM8FLGSWCg/exec"
}
