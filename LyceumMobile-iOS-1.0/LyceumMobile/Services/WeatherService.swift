import Foundation
import Combine

@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var temperature: Double?
    @Published private(set) var description = "Погода недоступна"
    @Published private(set) var lastUpdated: Date?

    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        let current: Current
    }

    func refresh() async {
        guard let url = URL(string:
            "https://api.open-meteo.com/v1/forecast?latitude=48.50834&longitude=32.26618&current=temperature_2m,weather_code&timezone=Europe%2FKyiv")
        else { return }
        do {
            let data = try await HTTPSClient.fetch(url, maxBytes: 24_000)
            let current = try JSONDecoder().decode(Response.self, from: data).current
            temperature = current.temperature_2m
            switch current.weather_code {
            case 0: description = "Ясно"
            case 1...3: description = "Мінлива хмарність"
            case 45, 48: description = "Туман"
            case 51...67: description = "Дощ"
            case 71...77: description = "Сніг"
            case 80...82: description = "Зливи"
            case 95...99: description = "Гроза"
            default: description = "Кропивницький"
            }
            lastUpdated = Date()
        } catch {
            description = temperature == nil ? "Погода недоступна" : "Збережена погода"
        }
    }
}
