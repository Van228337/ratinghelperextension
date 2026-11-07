import Foundation

public enum NetworkError: LocalizedError, Sendable {
    case invalidURL(String)
    case unauthorized(String)
    case notFound(String)
    case serverError(Int, String, endpoint: String?)
    case decodingError(String)
    case tlsOrSecurityError(String, endpoint: String?)
    case networkFailure(String, endpoint: String?)

    public static func serverError(_ code: Int, _ msg: String) -> NetworkError {
        .serverError(code, msg, endpoint: nil)
    }

    public static func networkFailure(_ msg: String) -> NetworkError {
        .networkFailure(msg, endpoint: nil)
    }

    public static func tlsOrSecurityError(_ msg: String) -> NetworkError {
        .tlsOrSecurityError(msg, endpoint: nil)
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Некорректный адрес запроса: \(url)"
        case .unauthorized(let msg):
            return msg.isEmpty ? "Сессия истекла. Пожалуйста, выполните повторный вход." : msg
        case .notFound(let msg):
            return msg.isEmpty ? "Запрашиваемый ресурс не найден." : msg
        case .serverError(let code, let msg, let endpoint):
            let epInfo = endpoint != nil ? " [\(endpoint!)]" : ""
            return "Ошибка сервера (\(code))\(epInfo): \(msg)"
        case .decodingError(let msg):
            return "Не удалось обработать ответ сервера: \(msg)"
        case .tlsOrSecurityError(let msg, let endpoint):
            let epInfo = endpoint != nil ? " [\(endpoint!)]" : ""
            return "Ошибка безопасного TLS-подключения\(epInfo): \(msg). Проверьте интернет-соединение или настройки VPN/прокси."
        case .networkFailure(let msg, let endpoint):
            let epInfo = endpoint != nil ? " [\(endpoint!)]" : ""
            return "Ошибка сети\(epInfo): \(msg)"
        }
    }
}

public final class HTTPClient: Sendable {
    public static let shared = HTTPClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        // Allow the Apps Script moderation gateway to complete its Groq retry
        // cycle; individual requests keep their own shorter timeout unless
        // explicitly overridden.
        config.timeoutIntervalForResource = 120
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        self.session = URLSession(configuration: config)
    }

    public func request(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        if let timeoutInterval {
            req.timeoutInterval = timeoutInterval
        }
        for (k, v) in headers {
            req.setValue(v, forHTTPHeaderField: k)
        }

        let host = url.host ?? url.absoluteString

        do {
            let (data, response) = try await session.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.networkFailure("Сервер вернул некорректный ответ", endpoint: host)
            }
            return (data, httpResponse)
        } catch let error as NetworkError {
            throw error
        } catch let urlErr as URLError {
            let code = urlErr.code
            let desc = urlErr.localizedDescription
            if code == .secureConnectionFailed || code == .serverCertificateUntrusted ||
               code == .serverCertificateHasBadDate || code == .serverCertificateNotYetValid ||
               code == .clientCertificateRejected {
                throw NetworkError.tlsOrSecurityError("\(desc) (код: \(code.rawValue))", endpoint: host)
            } else if code == .timedOut {
                throw NetworkError.networkFailure("Превышено время ожидания ответа (тайм-аут)", endpoint: host)
            } else if code == .notConnectedToInternet {
                throw NetworkError.networkFailure("Отсутствует подключение к интернету", endpoint: host)
            } else {
                throw NetworkError.networkFailure("\(desc) (код: \(code.rawValue))", endpoint: host)
            }
        } catch {
            throw NetworkError.networkFailure(error.localizedDescription, endpoint: host)
        }
    }

    public func requestJSON<T: Decodable>(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        decoder: JSONDecoder = JSONDecoder(),
        timeoutInterval: TimeInterval? = nil
    ) async throws -> T {
        let host = url.host ?? url.absoluteString
        let (data, response) = try await request(
            url: url,
            method: method,
            headers: headers,
            body: body,
            timeoutInterval: timeoutInterval
        )

        if response.statusCode == 401 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw NetworkError.unauthorized(msg)
        } else if response.statusCode == 404 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw NetworkError.notFound(msg)
        } else if response.statusCode < 200 || response.statusCode >= 300 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(response.statusCode)"
            throw NetworkError.serverError(response.statusCode, msg, endpoint: host)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw NetworkError.decodingError("\(error.localizedDescription). Ответ [\(host)]: \(bodyStr.prefix(250))")
        }
    }
}
