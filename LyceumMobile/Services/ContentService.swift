import Foundation
import Combine

@MainActor
final class ContentService: ObservableObject {
    @Published private(set) var feed = ContentFeed()
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var status = "Локальна копія"
    private let storageURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storageURL = directory.appendingPathComponent("lyceummobile-content.json")
        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(ContentFeed.self, from: data) {
            feed = decoded
            status = "Збережені оголошення"
        }
    }

    func refresh(from address: String) async {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "Укажи адресу Google Apps Script у налаштуваннях."
            return
        }
        do {
            let url = try HTTPSClient.validatedURL(address)
            let data = try await HTTPSClient.fetch(url, maxBytes: 400_000)
            let decoded = try JSONDecoder().decode(ContentFeed.self, from: data)
            // Only replace the cached feed after successful decoding.
            try data.write(to: storageURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            feed = decoded
            lastUpdated = Date()
            status = "Оголошення та заміни оновлено"
        } catch {
            status = "Мережа недоступна — показано збережені оголошення"
        }
    }
}
