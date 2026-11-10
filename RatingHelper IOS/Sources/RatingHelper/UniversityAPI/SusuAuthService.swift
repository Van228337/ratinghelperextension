import Foundation

public struct SusuStudentRaw: Codable, Sendable {
    public let unitId: String?
    public let unitName: String?
    public let unitShortName: String?
    public let parentId: String?
    public let parentName: String?
    public let parentShortName: String?
    public let educationLevel: String?
    public let specialityCode: String?
    public let specialityName: String?
    public let groupId: String?
    public let groupName: String?
    public let studyYears: String?
    public let educationForm: String?
    public let mobilePhone: String?

    enum CodingKeys: String, CodingKey {
        case unitId, unitName, unitShortName, parentId, parentName, parentShortName
        case educationLevel, specialityCode, specialityName, groupId, groupName
        case studyYears, educationForm, mobilePhone
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unitId = Self.decodeString(c, .unitId)
        unitName = try? c.decodeIfPresent(String.self, forKey: .unitName)
        unitShortName = try? c.decodeIfPresent(String.self, forKey: .unitShortName)
        parentId = Self.decodeString(c, .parentId)
        parentName = try? c.decodeIfPresent(String.self, forKey: .parentName)
        parentShortName = try? c.decodeIfPresent(String.self, forKey: .parentShortName)
        educationLevel = try? c.decodeIfPresent(String.self, forKey: .educationLevel)
        specialityCode = try? c.decodeIfPresent(String.self, forKey: .specialityCode)
        specialityName = try? c.decodeIfPresent(String.self, forKey: .specialityName)
        groupId = Self.decodeString(c, .groupId)
        groupName = try? c.decodeIfPresent(String.self, forKey: .groupName)
        studyYears = try? c.decodeIfPresent(String.self, forKey: .studyYears)
        educationForm = try? c.decodeIfPresent(String.self, forKey: .educationForm)
        mobilePhone = try? c.decodeIfPresent(String.self, forKey: .mobilePhone)
    }

    private static func decodeString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let s = try? c.decode(String.self, forKey: key) { return s }
        if let i = try? c.decode(Int.self, forKey: key) { return String(i) }
        return nil
    }

    public func toStudentProfile() -> StudentProfile {
        StudentProfile(
            unitId: unitId,
            unitName: unitName,
            unitShortName: unitShortName,
            parentId: parentId,
            parentName: parentName,
            parentShortName: parentShortName,
            educationLevel: educationLevel,
            specialityCode: specialityCode,
            specialityName: specialityName,
            groupId: groupId,
            groupName: groupName,
            studyYears: studyYears,
            educationForm: educationForm
        )
    }
}

public struct LoginResponse: Codable, Sendable {
    public let isLogged: Bool?
    public let accessToken: String?
    public let refreshToken: String?
    public let id: String?
    public let userName: String?
    public let email: String?
    public let susuEmail: String?
    public let photo: String?
    public let firstName: String?
    public let middleName: String?
    public let lastName: String?
    public let student: [SusuStudentRaw]?

    enum CodingKeys: String, CodingKey {
        case isLogged, accessToken, refreshToken, id, userName, email, susuEmail, photo
        case firstName, middleName, lastName, student
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isLogged = try? c.decodeIfPresent(Bool.self, forKey: .isLogged)
        accessToken = try? c.decodeIfPresent(String.self, forKey: .accessToken)
        refreshToken = try? c.decodeIfPresent(String.self, forKey: .refreshToken)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = nil
        }
        userName = try? c.decodeIfPresent(String.self, forKey: .userName)
        email = try? c.decodeIfPresent(String.self, forKey: .email)
        susuEmail = try? c.decodeIfPresent(String.self, forKey: .susuEmail)
        photo = try? c.decodeIfPresent(String.self, forKey: .photo)
        firstName = try? c.decodeIfPresent(String.self, forKey: .firstName)
        middleName = try? c.decodeIfPresent(String.self, forKey: .middleName)
        lastName = try? c.decodeIfPresent(String.self, forKey: .lastName)
        student = try? c.decodeIfPresent([SusuStudentRaw].self, forKey: .student)
    }
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
            if stored.rememberMe, let secureRefreshToken = keychain.readString(key: "susu_refresh_token") {
                session?.refreshToken = secureRefreshToken
            }
            if let savedIdentity = keychain.readString(key: "susu_identity"), !savedIdentity.isEmpty {
                session?.identity = savedIdentity
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
        let savedIdentity = keychain.readString(key: "susu_identity")
        let identity: String
        if let savedIdentity, !savedIdentity.isEmpty {
            identity = savedIdentity
        } else if let curId = session?.identity, !curId.isEmpty {
            identity = curId
            _ = keychain.saveString(key: "susu_identity", value: identity)
        } else {
            identity = generateIdentity()
            _ = keychain.saveString(key: "susu_identity", value: identity)
        }

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

        let profiles = resp.student?.map { $0.toStudentProfile() } ?? []
        let primaryProfile = profiles.first

        let fullName = [resp.lastName, resp.firstName, resp.middleName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let newSession = UserSession(
            username: resp.userName ?? login,
            identity: identity,
            accessToken: token,
            refreshToken: refreshToken,
            tokenExp: exp,
            rememberMe: rememberMe,
            lastLoginDate: Date(),
            externalUserId: resp.id,
            fullName: fullName.isEmpty ? nil : fullName,
            email: resp.email,
            susuEmail: resp.susuEmail,
            studentProfile: primaryProfile,
            allProfiles: profiles
        )

        self.session = newSession
        await store.saveSession(newSession)

        if let extId = resp.id {
            _ = keychain.saveString(key: "susu_external_user_id", value: extId)
        }

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
        if let newId = resp.id {
            current.externalUserId = newId
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
