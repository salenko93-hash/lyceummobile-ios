import Foundation

enum NetworkError: LocalizedError {
    case requiresHTTPS
    case invalidResponse
    case httpStatus(Int)
    case tooLarge
    case invalidData
    case checksum
    case alarmBlocksUpdate

    var errorDescription: String? {
        switch self {
        case .requiresHTTPS: return "Потрібна коректна HTTPS-адреса."
        case .invalidResponse: return "Сервер повернув некоректну відповідь."
        case .httpStatus(let status): return "Помилка сервера HTTP \(status)."
        case .tooLarge: return "Розмір файлу перевищує встановлений ліміт."
        case .invalidData: return "JSON не відповідає формату LyceumTV."
        case .checksum: return "Контрольна сума файлу не збігається."
        case .alarmBlocksUpdate: return "Оновлення розкладу відкладено під час тривоги."
        }
    }
}

enum HTTPSClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    static func validatedURL(_ text: String) throws -> URL {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = URL(string: clean), value.scheme?.lowercased() == "https",
              value.host != nil, value.user == nil, value.password == nil
        else { throw NetworkError.requiresHTTPS }
        return value
    }

    static func fetch(_ url: URL, maxBytes: Int) async throws -> Data {
        guard url.scheme?.lowercased() == "https", url.host != nil else {
            throw NetworkError.requiresHTTPS
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard http.statusCode == 200 else { throw NetworkError.httpStatus(http.statusCode) }
        guard bytes.count <= maxBytes else { throw NetworkError.tooLarge }
        return bytes
    }

    static func resolve(_ path: String, relativeTo manifestURL: URL) throws -> URL {
        guard let resolved = URL(string: path, relativeTo: manifestURL)?.absoluteURL,
              resolved.scheme?.lowercased() == "https", resolved.host != nil,
              resolved.user == nil, resolved.password == nil
        else { throw NetworkError.requiresHTTPS }
        return resolved
    }
}
