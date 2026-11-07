import Foundation
import CryptoKit

public struct GoogleDriveUploadResponse: Codable, Sendable {
    public let success: Bool
    public let downloadUrl: String?
    public let error: String?
}

public actor GoogleDriveService {
    public static let shared = GoogleDriveService()

    private let supabase = SupabaseService.shared
    private let client = HTTPClient.shared
    private var cachedScriptUrl: String?

    private init() {}

    private func getScriptUrl() async -> String? {
        if let cached = cachedScriptUrl, !cached.isEmpty {
            return cached
        }
        let url = await supabase.getConfig(key: "google_drive_script_url")
        self.cachedScriptUrl = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cachedScriptUrl
    }

    public func upload(
        data: Data,
        fileName: String,
        mimeType: String,
        subjectId: String,
        checkpointId: String
    ) async throws -> String {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let cacheKey = "drive_upload_\(subjectId)_\(checkpointId)_\(digest)"
        if let cached = UserDefaults.standard.string(forKey: cacheKey), !cached.isEmpty {
            return cached
        }
        let gasUrlStr = await getScriptUrl()

        // 1. Try Google Apps Script / Google Drive
        if let gasUrlStr = gasUrlStr, let gasUrl = URL(string: gasUrlStr) {
            let base64 = data.base64EncodedString()
            let payload: [String: Any] = [
                "fileName": fileName,
                "fileData": base64,
                "mimeType": mimeType
            ]

            if let bodyData = try? JSONSerialization.data(withJSONObject: payload) {
                do {
                    let resp: GoogleDriveUploadResponse = try await client.requestJSON(
                        url: gasUrl,
                        method: "POST",
                        headers: ["Content-Type": "text/plain"],
                        body: bodyData
                    )
                    if resp.success, let dl = resp.downloadUrl, !dl.isEmpty {
                        UserDefaults.standard.set(dl, forKey: cacheKey)
                        return dl
                    }
                } catch {
                    print("Google Drive upload failed, falling back to Supabase Storage: \(error)")
                }
            }
        }

        // 2. Fallback: Supabase Storage
        let sanitized = fileName.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
        // Both directories are UUIDs after metadata sync. Keep the fallback
        // path URL-safe so non-ASCII journal titles never reach Storage.
        let storagePath = "\(subjectId)/\(checkpointId)/\(Int64(Date().timeIntervalSince1970))_\(sanitized)"
        let storageUrlStr = "\(APIEndpoints.supabaseURL)/storage/v1/object/materials/\(storagePath)"

        guard let storageUrl = URL(string: storageUrlStr) else {
            throw NetworkError.invalidURL(storageUrlStr)
        }

        let headers = [
            "apikey": APIEndpoints.supabaseKey,
            "Authorization": "Bearer \(APIEndpoints.supabaseKey)",
            "Content-Type": mimeType
        ]

        let (_, httpResp) = try await client.request(
            url: storageUrl,
            method: "POST",
            headers: headers,
            body: data
        )

        guard httpResp.statusCode >= 200 && httpResp.statusCode < 300 else {
            throw NetworkError.serverError(httpResp.statusCode, "Не удалось загрузить файл в хранилище Supabase")
        }

        let publicURL = "\(APIEndpoints.supabaseURL)/storage/v1/object/public/materials/\(storagePath)"
        UserDefaults.standard.set(publicURL, forKey: cacheKey)
        return publicURL
    }
}
