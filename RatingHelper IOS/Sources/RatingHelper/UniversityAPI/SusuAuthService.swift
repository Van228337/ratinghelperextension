import Foundation

public struct LoginResponse: Codable, Sendable {
    public let isLogged: Bool?
    public let accessToken: String?
    public let refreshToken: String?
}

public actor SusuAuthService {
    public static let shared = SusuAuthService()

    private var session: UserSession?
    private let client = HTTPClient.shared
    private let store = LocalStore.shared
    private let keychain = KeychainHelper.shared

    private init() {}

    public func getSession() -> UserSession? {
        session
    }

    public func restoreSavedSession() async -> UserSession? {
        if let stored = await store.loadSession() {
            session = stored
            // If rememberMe was checked, try to read refresh_token from Keychain
            if stored.rememberMe, let secureRefreshToken = keychain.readString(key: "susu_refresh_token") {
                session?.refreshToken = secureRefreshToken
            }
            return session
        }
        return nil
    }

    private func generateIdentity(length: Int = 32) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    public func login(login: String, password: String, rememberMe: Bool) async throws -> UserSession {
        let identity = session?.identity.isEmpty == false ? (session?.identity ?? generateIdentity()) : generateIdentity()

        guard let url = URL(string: APIEndpoints.loginAPI) else {
            throw NetworkError.invalidURL(APIEndpoints.loginAPI)
        }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "identity", value: identity),
            URLQueryItem(name: "LoginForm[login]", value: login),
            URLQueryItem(name: "LoginForm[password]", value: password)
        ]
        let bodyData = components.percentEncodedQuery?.data(using: .utf8)

        let headers = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Origin": APIEndpoints.susuBase,
            "Referer": APIEndpoints.loginPage,
            "Accept": "application/json, text/plain, */*"
        ]

        let resp: LoginResponse = try await client.requestJSON(
            url: url,
            method: "POST",
            headers: headers,
            body: bodyData
        )

        guard resp.isLogged == true, let token = resp.accessToken, !token.isEmpty else {
            throw NetworkError.unauthorized("Не удалось войти: проверьте логин и пароль.")
        }

        let refreshToken = resp.refreshToken ?? ""
        let exp = UserSession.parseJWTExpiration(token)

        let newSession = UserSession(
            username: login,
            identity: identity,
            accessToken: token,
            refreshToken: refreshToken,
            tokenExp: exp,
            rememberMe: rememberMe,
            lastLoginDate: Date()
        )

        self.session = newSession
        await store.saveSession(newSession)

        if rememberMe {
            _ = keychain.saveString(key: "susu_username", value: login)
            _ = keychain.saveString(key: "susu_refresh_token", value: refreshToken)
            _ = keychain.saveString(key: "susu_password", value: password)
        } else {
            _ = keychain.delete(key: "susu_username")
            _ = keychain.delete(key: "susu_refresh_token")
            _ = keychain.delete(key: "susu_password")
        }

        return newSession
    }

    public func refreshToken() async throws -> UserSession {
        guard var current = session, !current.refreshToken.isEmpty else {
            throw NetworkError.unauthorized("Сессия завершена, необходим повторный вход.")
        }

        guard let url = URL(string: APIEndpoints.updateTokenAPI) else {
            throw NetworkError.invalidURL(APIEndpoints.updateTokenAPI)
        }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "userName", value: current.username),
            URLQueryItem(name: "identity", value: current.identity),
            URLQueryItem(name: "refreshToken", value: current.refreshToken)
        ]
        let bodyData = components.percentEncodedQuery?.data(using: .utf8)

        let headers = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Origin": APIEndpoints.susuBase,
            "Referer": APIEndpoints.loginPage,
            "Accept": "application/json, text/plain, */*"
        ]

        let resp: LoginResponse = try await client.requestJSON(
            url: url,
            method: "POST",
            headers: headers,
            body: bodyData
        )

        guard resp.isLogged == true, let token = resp.accessToken, !token.isEmpty else {
            throw NetworkError.unauthorized("Сессия истекла, пожалуйста войдите снова.")
        }

        current.accessToken = token
        current.tokenExp = UserSession.parseJWTExpiration(token)
        if let newRef = resp.refreshToken, !newRef.isEmpty {
            current.refreshToken = newRef
            if current.rememberMe {
                _ = keychain.saveString(key: "susu_refresh_token", value: newRef)
            }
        }

        self.session = current
        await store.saveSession(current)
        return current
    }

    public func validToken() async throws -> String {
        guard let current = session, !current.accessToken.isEmpty else {
            throw NetworkError.unauthorized("Требуется вход в аккаунт.")
        }

        if current.isExpired {
            let refreshed = try await refreshToken()
            return refreshed.accessToken
        }

        return current.accessToken
    }

    public func logout() async {
        session = nil
        await store.clearSession()
        _ = keychain.delete(key: "susu_username")
        _ = keychain.delete(key: "susu_refresh_token")
        _ = keychain.delete(key: "susu_password")
    }
}
