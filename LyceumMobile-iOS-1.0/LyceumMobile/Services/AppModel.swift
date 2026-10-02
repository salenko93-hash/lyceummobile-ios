import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    let settings = AppSettings()
    let schedules = ScheduleStore()
    let content = ContentService()
    let weather = WeatherService()
    private let metronome = SilenceMetronome()

    @Published private(set) var now = Date()
    @Published private(set) var alert: DistrictAlert
    @Published private(set) var alertOnline = false
    @Published private(set) var alertLastVerified: Date?
    @Published private(set) var alertStatus = "Перевірка стану тривоги"
    @Published private(set) var allClearUntil: Date?
    @Published private(set) var testSilenceUntil: Date?
    @Published private(set) var isSyncing = false

    private var foreground = false
    private var clockTimer: Timer?
    private var alertTask: Task<Void, Never>?
    private var contentTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?
    private var weatherTask: Task<Void, Never>?
    private var alertRequestInProgress = false

    init() {
        // Only a previously CONFIRMED state is loaded. Its age is shown clearly.
        let defaults = UserDefaults.standard
        alert = DistrictAlert(rawValue: defaults.string(forKey: "lastDistrictAlert") ?? "") ?? .unknown
        alertLastVerified = defaults.object(forKey: "lastDistrictAlertVerified") as? Date
        alertStatus = alert == .unknown ? "API-токен не перевірено" : "Попередній підтверджений стан"
    }

    var alertIsCurrent: Bool {
        guard alertOnline, let time = alertLastVerified else { return false }
        return Date().timeIntervalSince(time) < 60
    }

    var isAlarm: Bool { alert.isAlarm }

    var isAllClear: Bool {
        guard !isAlarm, let deadline = allClearUntil else { return false }
        return deadline > now
    }

    var isSilence: Bool {
        guard !isAlarm, !isAllClear else { return false }
        return SchoolClock.isDailySilence(now) ||
            (testSilenceUntil.map { $0 > now } ?? false)
    }

    var currentWeek: WeekType {
        WeekCycle.type(on: now, numeratorMonday: settings.validReferenceMonday)
    }

    var todayHoliday: String? {
        schedules.holidayCalendar.label(for: SchoolClock.isoDate(now))
    }

    var activeTimetable: ScheduleFile? {
        schedules.schedule(for: currentWeek, shelter: isAlarm)
    }

    func appDidBecomeActive() {
        guard !foreground else { return }
        foreground = true
        now = Date()
        if clockTimer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.now = Date()
                    self.updateMetronome()
                }
            }
            clockTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        startPeriodicTasks()
        updateMetronome()
    }

    func appDidEnterBackground() {
        foreground = false
        metronome.stop()
        clockTimer?.invalidate()
        clockTimer = nil
        alertTask?.cancel()
        contentTask?.cancel()
        scheduleTask?.cancel()
        weatherTask?.cancel()
        alertTask = nil
        contentTask = nil
        scheduleTask = nil
        weatherTask = nil
        // iOS deliberately does not claim continuous background alert polling.
    }

    private func startPeriodicTasks() {
        alertTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshAlert()
                try? await Task.sleep(nanoseconds: 12_000_000_000)
            }
        }
        contentTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                await self.content.refresh(from: self.settings.googleSheetsURL)
                try? await Task.sleep(nanoseconds: 300_000_000_000)
            }
        }
        scheduleTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshSchedules()
                try? await Task.sleep(nanoseconds: 900_000_000_000)
            }
        }
        weatherTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.weather.refresh()
                try? await Task.sleep(nanoseconds: 1_800_000_000_000)
            }
        }
    }

    func refreshAlert() async {
        guard !alertRequestInProgress, foreground else { return }
        guard let token = KeychainTokenStore.load(), !token.isEmpty else {
            alertOnline = false
            alertStatus = "Укажи токен alerts.in.ua в налаштуваннях"
            return
        }
        alertRequestInProgress = true
        defer { alertRequestInProgress = false }
        do {
            let result = try await AlertsService.poll(token: token)
            if alert.isAlarm && result == .none {
                allClearUntil = Date().addingTimeInterval(15)
            }
            if result.isAlarm {
                allClearUntil = nil
                testSilenceUntil = nil
                metronome.stop()
            }
            alert = result
            alertOnline = true
            alertLastVerified = Date()
            alertStatus = "alerts.in.ua • UID 81 • оновлено"
            UserDefaults.standard.set(result.rawValue, forKey: "lastDistrictAlert")
            UserDefaults.standard.set(alertLastVerified, forKey: "lastDistrictAlertVerified")
            updateMetronome()
        } catch {
            // Error does NOT create "N" and does not clear a last-confirmed alarm.
            alertOnline = false
            alertStatus = "OFFLINE — збережено останній підтверджений стан"
        }
    }

    func refreshSchedules() async {
        let source = settings.source
        await schedules.refresh(from: settings.manifestURL) { [weak self] in
            guard let self = self else { return false }
            return self.foreground && self.alert == .none &&
                self.alertIsCurrent && !self.isAllClear && source == self.settings.source
        }
    }

    func refreshEverything() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        await refreshAlert()
        await content.refresh(from: settings.googleSheetsURL)
        await refreshSchedules()
        await weather.refresh()
    }

    func beginSilenceTest() {
        guard !isAlarm else { return }
        testSilenceUntil = Date().addingTimeInterval(60)
        now = Date()
        updateMetronome()
    }

    func endSilenceTest() {
        testSilenceUntil = nil
        updateMetronome()
    }

    func updateMetronome() {
        metronome.setActive(foreground && isSilence && settings.metronomeEnabled,
                            volume: settings.metronomeVolume) { [weak self] in
            guard let self = self else { return false }
            // Re-evaluate state and exact 09:01/time limit before each beat.
            let current = Date()
            let timed = SchoolClock.isDailySilence(current) ||
                (self.testSilenceUntil.map { $0 > current } ?? false)
            return self.foreground && !self.isAlarm && !self.isAllClear &&
                self.settings.metronomeEnabled && self.settings.metronomeVolume > 0 &&
                timed
        }
    }

    func didChangeAlertToken() {
        // Different credentials must not inherit a previous token's cached status.
        alert = .unknown
        alertOnline = false
        alertLastVerified = nil
        allClearUntil = nil
        testSilenceUntil = nil
        metronome.stop()
        UserDefaults.standard.removeObject(forKey: "lastDistrictAlert")
        UserDefaults.standard.removeObject(forKey: "lastDistrictAlertVerified")
        Task { await refreshAlert() }
    }
}
