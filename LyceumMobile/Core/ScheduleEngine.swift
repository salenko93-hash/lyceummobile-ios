import Foundation

public enum SchoolClock {
    public static let kyiv: TimeZone = {
        if let value = TimeZone(identifier: "Europe/Kyiv") {
            return value
        }
        // Older iOS 15 timezone databases may still use the legacy IANA name.
        if let value = TimeZone(identifier: "Europe/Kiev") {
            return value
        }
        // Last-resort fallback prevents an immediate launch crash.
        return TimeZone.current
    }()

    public static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = kyiv
        value.firstWeekday = 2
        value.minimumDaysInFirstWeek = 4
        return value
    }

    public static func isoDate(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    public static func fromISO(_ iso: String) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else {
            return nil
        }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1],
                                                  day: parts[2], hour: 12))
    }

    public static func dayKey(_ date: Date) -> String? {
        switch calendar.component(.weekday, from: date) {
        case 1: return "SUNDAY"
        case 2: return "MONDAY"
        case 3: return "TUESDAY"
        case 4: return "WEDNESDAY"
        case 5: return "THURSDAY"
        case 6: return "FRIDAY"
        case 7: return "SATURDAY"
        default: return nil
        }
    }

    public static func minuteOfDay(_ date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    public static func isDailySilence(_ date: Date) -> Bool {
        minuteOfDay(date) == 9 * 60
    }

    public static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.timeZone = kyiv
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }

    public static func displayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.timeZone = kyiv
        formatter.calendar = calendar
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

public enum WeekType: String, Equatable {
    case numerator = "ЧИСЕЛЬНИК"
    case denominator = "ЗНАМЕННИК"

    public var fileSuffix: String {
        self == .numerator ? "numerator" : "denominator"
    }
}

public enum WeekCycle {
    // Default numerator reference Monday carried from LyceumTV 2.7.0.2.
    public static let defaultReference = "2026-08-31"

    public static func type(on date: Date, numeratorMonday reference: String) -> WeekType {
        guard let ref = SchoolClock.fromISO(reference) else { return .numerator }
        let cal = SchoolClock.calendar
        let first = cal.dateInterval(of: .weekOfYear, for: ref)?.start ?? ref
        let target = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        // Calendar arithmetic accounts for 23/25-hour daylight-saving days.
        let days = cal.dateComponents([.day], from: first, to: target).day ?? 0
        let weeks = Int(floor(Double(days) / 7.0))
        return ((weeks % 2) + 2) % 2 == 0 ? .numerator : .denominator
    }
}

public enum ScheduleEngine {
    public static let classNames = ["10-А", "10-Б", "10-В", "10-Г",
                                    "11-А", "11-Б", "11-В", "11-Г"]

    public static func currentBell(in schedule: ScheduleFile, date: Date) -> BellSlot? {
        let current = SchoolClock.minuteOfDay(date)
        return schedule.bellSchedule.first {
            guard let range = $0.minuteBounds else { return false }
            return range.start <= current && current < range.end
        }
    }

    public static func nextBell(in schedule: ScheduleFile, date: Date) -> BellSlot? {
        let current = SchoolClock.minuteOfDay(date)
        return schedule.bellSchedule.first {
            guard let range = $0.minuteBounds else { return false }
            return range.start > current
        }
    }

    public static func lessons(in schedule: ScheduleFile, on date: Date,
                               className: String, substitutions: [Substitution],
                               shelter: Bool, referenceMonday: String) -> [(BellSlot, [LessonEntry])] {
        guard let day = SchoolClock.dayKey(date) else { return [] }
        let week = WeekCycle.type(on: date, numeratorMonday: referenceMonday)
        let iso = SchoolClock.isoDate(date)

        return schedule.bellSchedule.map { bell in
            var entries = schedule.entries(day: day, lesson: bell.lesson, className: className)
            // Match Android: latest matching substitution wins, even if entries == [].
            for row in substitutions.reversed() {
                guard row.active, row.lesson == bell.lesson, row.className == className else { continue }
                if let date = row.date, !date.isEmpty, date != iso { continue }
                if let rowDay = row.day, !rowDay.isEmpty, rowDay.uppercased() != day { continue }
                let scope = (row.scope ?? "normal").lowercased()
                guard scope == "both" || scope == (shelter ? "shelter" : "normal") else { continue }
                let choice = (row.week ?? "all").uppercased()
                guard choice == "ALL" ||
                      (week == .numerator && (choice == "NUMERATOR" || choice == "ЧИСЕЛЬНИК")) ||
                      (week == .denominator && (choice == "DENOMINATOR" || choice == "ЗНАМЕННИК"))
                else { continue }
                entries = row.entries
                break
            }
            return (bell, entries)
        }
    }
}
