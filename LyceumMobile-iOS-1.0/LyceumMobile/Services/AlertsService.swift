import Foundation

// UID 81: Kropyvnytskyi district. No other automatic alarm source.
enum DistrictAlert: String {
    case unknown = "?"
    case active = "A"
    case partial = "P"
    case none = "N"

    var isAlarm: Bool { self == .active || self == .partial }

    var label: String {
        switch self {
        case .active: return "ПОВІТРЯНА ТРИВОГА"
        case .partial: return "ЧАСТКОВА ПОВІТРЯНА ТРИВОГА"
        case .none: return "Тривога не підтверджена як активна"
        case .unknown: return "Стан тривоги невідомий"
        }
    }

    static func fromAPIBody(_ data: Data) -> DistrictAlert? {
        // Endpoint may answer JSON "A" or bare A. Unknown responses never mean N.
        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .uppercased()
        guard let code = raw, let value = DistrictAlert(rawValue: code), value != .unknown
        else { return nil }
        return value
    }
}

enum AlertsService {
    static let endpoint =
        URL(string: "https://api.alerts.in.ua/v1/iot/active_air_raid_alerts/81.json")!

    static func poll(token: String) async throws -> DistrictAlert {
        guard !token.isEmpty else { throw NetworkError.invalidData }
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LyceumMobile/1.0 iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard http.statusCode == 200 else { throw NetworkError.httpStatus(http.statusCode) }
        guard data.count <= 1024 else { throw NetworkError.tooLarge }
        guard let parsed = DistrictAlert.fromAPIBody(data) else {
            throw NetworkError.invalidData
        }
        return parsed
    }
}
