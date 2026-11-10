import Foundation

public struct StudentProfile: Codable, Hashable, Sendable {
    public var unitId: String?
    public var unitName: String?
    public var unitShortName: String?
    public var parentId: String?
    public var parentName: String?
    public var parentShortName: String?
    public var educationLevel: String?
    public var specialityCode: String?
    public var specialityName: String?
    public var groupId: String?
    public var groupName: String?
    public var studyYears: String?
    public var educationForm: String?

    public init(
        unitId: String? = nil,
        unitName: String? = nil,
        unitShortName: String? = nil,
        parentId: String? = nil,
        parentName: String? = nil,
        parentShortName: String? = nil,
        educationLevel: String? = nil,
        specialityCode: String? = nil,
        specialityName: String? = nil,
        groupId: String? = nil,
        groupName: String? = nil,
        studyYears: String? = nil,
        educationForm: String? = nil
    ) {
        self.unitId = unitId
        self.unitName = unitName
        self.unitShortName = unitShortName
        self.parentId = parentId
        self.parentName = parentName
        self.parentShortName = parentShortName
        self.educationLevel = educationLevel
        self.specialityCode = specialityCode
        self.specialityName = specialityName
        self.groupId = groupId
        self.groupName = groupName
        self.studyYears = studyYears
        self.educationForm = educationForm
    }
}

public struct UserSession: Codable, Hashable, Sendable {
    public var username: String
    public var identity: String
    public var accessToken: String
    public var refreshToken: String
    public var tokenExp: Int64
    public var rememberMe: Bool
    public var lastLoginDate: Date
    public var externalUserId: String?
    public var fullName: String?
    public var email: String?
    public var susuEmail: String?
    public var studentProfile: StudentProfile?
    public var allProfiles: [StudentProfile]

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
        lastLoginDate: Date = Date(),
        externalUserId: String? = nil,
        fullName: String? = nil,
        email: String? = nil,
        susuEmail: String? = nil,
        studentProfile: StudentProfile? = nil,
        allProfiles: [StudentProfile] = []
    ) {
        self.username = username
        self.identity = identity
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExp = tokenExp
        self.rememberMe = rememberMe
        self.lastLoginDate = lastLoginDate
        self.externalUserId = externalUserId
        self.fullName = fullName
        self.email = email
        self.susuEmail = susuEmail
        self.studentProfile = studentProfile
        self.allProfiles = allProfiles
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
