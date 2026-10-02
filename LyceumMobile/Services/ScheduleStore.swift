import Foundation
import Combine
import CryptoKit

struct ContentManifest: Decodable {
    struct Resource: Decodable {
        let url: String
        let sha256: String
    }
    let version: String
    let schedules: [String: Resource]
    let calendar: Resource?
}

@MainActor
final class ScheduleStore: ObservableObject {
    static let filenames = [
        "schedule_numerator.json", "schedule_denominator.json",
        "shelter_numerator.json", "shelter_denominator.json"
    ]

    @Published private(set) var version = "Вбудований"
    @Published private(set) var status = "Вбудований розклад"
    @Published private(set) var timetables: [String: ScheduleFile] = [:]
    @Published private(set) var holidayCalendar = SchoolCalendar()

    private let fm = FileManager.default
    private let cacheRoot: URL
    private let current: URL

    init() {
        let home = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        cacheRoot = home.appendingPathComponent("schedule-bundles", isDirectory: true)
        current = cacheRoot.appendingPathComponent("current", isDirectory: true)
        try? fm.createDirectory(at: cacheRoot, withIntermediateDirectories: true)

        // Bundled schedules remain available if remote sync or cached bundle fails.
        timetables = Self.loadBundled()
        holidayCalendar = Self.loadBundledCalendar()
        loadCachedIfValid()
    }

    private static func loadBundled() -> [String: ScheduleFile] {
        var data: [String: ScheduleFile] = [:]
        for name in filenames {
            guard let path = Bundle.main.url(forResource: String(name.dropLast(5)),
                                             withExtension: "json"),
                  let bytes = try? Data(contentsOf: path),
                  let parsed = try? JSONDecoder().decode(ScheduleFile.self, from: bytes)
            else { continue }
            data[name] = parsed
        }
        return data
    }

    private static func loadBundledCalendar() -> SchoolCalendar {
        guard let path = Bundle.main.url(forResource: "calendar", withExtension: "json"),
              let bytes = try? Data(contentsOf: path),
              let parsed = try? JSONDecoder().decode(SchoolCalendar.self, from: bytes)
        else { return SchoolCalendar() }
        return parsed
    }

    private func loadCachedIfValid() {
        let new = try? Self.decodeFolder(current)
        if let new = new {
            timetables = new.schedules
            holidayCalendar = new.calendar ?? Self.loadBundledCalendar()
            version = (try? String(contentsOf: current.appendingPathComponent("version.txt"),
                                   encoding: .utf8)) ?? "Збережений"
            status = "Збережений розклад: \(version)"
        }
    }

    private static func decodeFolder(_ directory: URL)
        throws -> (schedules: [String: ScheduleFile], calendar: SchoolCalendar?) {
        var parsed: [String: ScheduleFile] = [:]
        for name in filenames {
            let data = try Data(contentsOf: directory.appendingPathComponent(name))
            parsed[name] = try JSONDecoder().decode(ScheduleFile.self, from: data)
            guard let timetable = parsed[name],
                  timetable.bellSchedule.count == 8,
                  !timetable.days.isEmpty else {
                throw NetworkError.invalidData
            }
        }
        let optional = directory.appendingPathComponent("calendar.json")
        let calendar = (try? Data(contentsOf: optional))
            .flatMap { try? JSONDecoder().decode(SchoolCalendar.self, from: $0) }
        return (parsed, calendar)
    }

    func schedule(for week: WeekType, shelter: Bool) -> ScheduleFile? {
        let prefix = shelter ? "shelter_" : "schedule_"
        return timetables[prefix + week.fileSuffix + ".json"]
    }

    func refresh(from manifestAddress: String, allowedToInstall: () -> Bool) async {
        guard !manifestAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "Адресу віддалених розкладів не налаштовано"
            return
        }
        guard allowedToInstall() else {
            status = "Оновлення відкладено, доки стан тривоги не підтверджено"
            return
        }
        do {
            let manifestURL = try HTTPSClient.validatedURL(manifestAddress)
            let manifestData = try await HTTPSClient.fetch(manifestURL, maxBytes: 250_000)
            let manifest = try JSONDecoder().decode(ContentManifest.self, from: manifestData)
            guard !manifest.version.isEmpty, manifest.version.count <= 80,
                  manifest.version != version else {
                status = "Розклади актуальні"
                return
            }

            // Fetch and SHA-256 validate EVERY timetable before changing any cache.
            var downloaded: [String: Data] = [:]
            for name in Self.filenames {
                guard let description = manifest.schedules[name] else {
                    throw NetworkError.invalidData
                }
                downloaded[name] = try await verifiedDownload(description, manifestURL: manifestURL,
                                                             maxBytes: 700_000)
            }
            if let calendar = manifest.calendar {
                downloaded["calendar.json"] = try await verifiedDownload(calendar,
                                                                         manifestURL: manifestURL,
                                                                         maxBytes: 150_000)
            }
            for name in Self.filenames {
                guard let bytes = downloaded[name],
                      let decoded = try? JSONDecoder().decode(ScheduleFile.self, from: bytes),
                      decoded.bellSchedule.count == 8, !decoded.days.isEmpty
                else { throw NetworkError.invalidData }
            }
            if let data = downloaded["calendar.json"] {
                _ = try JSONDecoder().decode(SchoolCalendar.self, from: data)
            }
            guard allowedToInstall() else { throw NetworkError.alarmBlocksUpdate }

            // Stage all validated data and activate the directory as one bundle.
            let staging = cacheRoot.appendingPathComponent("staging-\(UUID().uuidString)",
                                                            isDirectory: true)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            do {
                for (name, bytes) in downloaded {
                    try bytes.write(to: staging.appendingPathComponent(name),
                                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                }
                // Carry old calendar forward if new manifest omits it.
                if downloaded["calendar.json"] == nil,
                   let old = try? Data(contentsOf: current.appendingPathComponent("calendar.json")) {
                    try old.write(to: staging.appendingPathComponent("calendar.json"),
                                  options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                }
                try manifest.version.write(to: staging.appendingPathComponent("version.txt"),
                                           atomically: true, encoding: .utf8)
                let validated = try Self.decodeFolder(staging)
                guard allowedToInstall() else { throw NetworkError.alarmBlocksUpdate }

                let backup = cacheRoot.appendingPathComponent("previous", isDirectory: true)
                if fm.fileExists(atPath: backup.path) { try fm.removeItem(at: backup) }
                let hadCurrent = fm.fileExists(atPath: current.path)
                if hadCurrent { try fm.moveItem(at: current, to: backup) }
                do {
                    try fm.moveItem(at: staging, to: current)
                } catch {
                    if hadCurrent { try? fm.moveItem(at: backup, to: current) }
                    throw error
                }
                timetables = validated.schedules
                holidayCalendar = validated.calendar ?? Self.loadBundledCalendar()
                version = manifest.version
                status = "Оновлено: \(version)"
            } catch {
                try? fm.removeItem(at: staging)
                throw error
            }
        } catch {
            status = "Нові файли не встановлено: \(error.localizedDescription)"
        }
    }

    private func verifiedDownload(_ spec: ContentManifest.Resource, manifestURL: URL,
                                  maxBytes: Int) async throws -> Data {
        let hash = spec.sha256.lowercased()
        guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else {
            throw NetworkError.checksum
        }
        let url = try HTTPSClient.resolve(spec.url, relativeTo: manifestURL)
        let bytes = try await HTTPSClient.fetch(url, maxBytes: maxBytes)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard digest == hash else { throw NetworkError.checksum }
        return bytes
    }
}
