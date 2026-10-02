import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var selectedClass: String {
        didSet { defaults.set(selectedClass, forKey: "selectedClass") }
    }
    @Published var referenceMonday: String {
        didSet { defaults.set(referenceMonday, forKey: "referenceMonday") }
    }
    @Published var googleSheetsURL: String {
        didSet { defaults.set(googleSheetsURL.trimmingCharacters(in: .whitespacesAndNewlines),
                             forKey: "googleSheetsURL") }
    }
    @Published var githubManifestURL: String {
        didSet { defaults.set(githubManifestURL.trimmingCharacters(in: .whitespacesAndNewlines),
                             forKey: "githubManifestURL") }
    }
    @Published var localManifestURL: String {
        didSet { defaults.set(localManifestURL.trimmingCharacters(in: .whitespacesAndNewlines),
                             forKey: "localManifestURL") }
    }
    @Published var source: String {
        didSet { defaults.set(source, forKey: "source") }
    }
    @Published var metronomeEnabled: Bool {
        didSet { defaults.set(metronomeEnabled, forKey: "metronomeEnabled") }
    }
    @Published var metronomeVolume: Double {
        didSet { defaults.set(metronomeVolume, forKey: "metronomeVolume") }
    }

    init() {
        let defaults = UserDefaults.standard
        selectedClass = defaults.string(forKey: "selectedClass") ?? "10-А"
        referenceMonday = defaults.string(forKey: "referenceMonday") ?? WeekCycle.defaultReference
        googleSheetsURL = defaults.string(forKey: "googleSheetsURL") ?? ""
        githubManifestURL = defaults.string(forKey: "githubManifestURL") ?? ""
        localManifestURL = defaults.string(forKey: "localManifestURL") ?? ""
        source = defaults.string(forKey: "source") ?? "GITHUB"
        metronomeEnabled = defaults.object(forKey: "metronomeEnabled") as? Bool ?? true
        metronomeVolume = defaults.object(forKey: "metronomeVolume") as? Double ?? 0.25
    }

    var manifestURL: String {
        source == "LOCAL" ? localManifestURL : githubManifestURL
    }

    var validReferenceMonday: String {
        let candidate = SchoolClock.fromISO(referenceMonday)
        guard let monday = candidate,
              SchoolClock.calendar.component(.weekday, from: monday) == 2
        else { return WeekCycle.defaultReference }
        return referenceMonday
    }
}
