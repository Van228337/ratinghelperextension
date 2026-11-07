import Foundation

public struct UserSession: Codable, Hashable, Sendable {
    public var username: String
    public var identity: String
    public var accessToken: String
    public var refreshToken: String
    public var tokenExp: Int64
    public var rememberMe: Bool
    public var lastLoginDate: Date

    public var isExpired: Bool {
        guard tokenExp > 0 else { return true }
        let now = Int64(Date().timeIntervalSince1970)
        return now >= (tokenExp - 60)
    }

    public init(
        username: String = "",
        identity: String = "",
        accessToken: String = "",
        refreshToken: String = "",
        tokenExp: Int64 = 0,
        rememberMe: Bool = false,
        lastLoginDate: Date = Date()
    ) {
        self.username = username
        self.identity = identity
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExp = tokenExp
        self.rememberMe = rememberMe
        self.lastLoginDate = lastLoginDate
    }

    public static func parseJWTExpiration(_ token: String) -> Int64 {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return 0 }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else {
            return 0
        }
        return Int64(exp)
    }
}
