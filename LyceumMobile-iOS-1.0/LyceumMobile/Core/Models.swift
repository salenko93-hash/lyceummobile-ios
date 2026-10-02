import Foundation

// Format-compatible with LyceumTV 2.7.0.2 (Android) timetable JSON files.
public struct LessonEntry: Codable, Equatable {
    public let subject: String
    public let room: String
    public let teacher: String

    public init(subject: String, room: String, teacher: String) {
        self.subject = subject
        self.room = room
        self.teacher = teacher
    }
}

public struct BellSlot: Codable, Equatable, Identifiable {
    public let lesson: Int
    public let time: String
    public var id: Int { lesson }

    public init(lesson: Int, time: String) {
        self.lesson = lesson
        self.time = time
    }

    // Handles the original en dash in Android bell times: "08:00–08:45".
    public var minuteBounds: (start: Int, end: Int)? {
        let pattern = #"\b([0-2]\d):([0-5]\d)\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let text = time as NSString
        let matches = expression.matches(in: time, range: NSRange(location: 0, length: text.length))
        guard matches.count == 2 else { return nil }
        func minutes(_ match: NSTextCheckingResult) -> Int {
            let hour = Int(text.substring(with: match.range(at: 1))) ?? 0
            let minute = Int(text.substring(with: match.range(at: 2))) ?? 0
            return hour * 60 + minute
        }
        let first = minutes(matches[0])
        let second = minutes(matches[1])
        guard first < second, second <= 1440 else { return nil }
        return (first, second)
    }
}

public struct ScheduleFile: Codable {
    public let weekType: String
    public let source: String?
    public let title: String?
    public let bellSchedule: [BellSlot]
    // days.MONDAY["1"]["10-А"] = [ {subject, room, teacher}, ... ]
    public let days: [String: [String: [String: [LessonEntry]]]]

    public init(weekType: String, source: String?, title: String?,
                bellSchedule: [BellSlot], days: [String: [String: [String: [LessonEntry]]]]) {
        self.weekType = weekType
        self.source = source
        self.title = title
        self.bellSchedule = bellSchedule
        self.days = days
    }

    public func entries(day: String, lesson: Int, className: String) -> [LessonEntry] {
        days[day]?[String(lesson)]?[className] ?? []
    }
}

public struct Announcement: Codable, Equatable {
    public let active: Bool
    public let title: String
    public let message: String
    public let priority: String

    enum CodingKeys: String, CodingKey { case active, title, message, priority }

    public init(active: Bool, title: String, message: String, priority: String) {
        self.active = active
        self.title = title
        self.message = message
        self.priority = priority
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        priority = try c.decodeIfPresent(String.self, forKey: .priority) ?? "NORMAL"
    }
}

public struct SchoolEvent: Codable {
    public let active: Bool
    public let title: String
    public let date: String
    public let time: String
    public let location: String

    enum CodingKeys: String, CodingKey { case active, title, date, time, location }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        time = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
    }
}

public struct Substitution: Codable {
    public let date: String?
    public let week: String?
    public let day: String?
    public let lesson: Int
    public let className: String
    public let scope: String?
    public let active: Bool
    public let entries: [LessonEntry]

    enum CodingKeys: String, CodingKey {
        case date, week, day, lesson, scope, active, entries
        case className = "class"
    }

    public init(date: String?, week: String?, day: String?, lesson: Int,
                className: String, scope: String?, active: Bool, entries: [LessonEntry]) {
        self.date = date
        self.week = week
        self.day = day
        self.lesson = lesson
        self.className = className
        self.scope = scope
        self.active = active
        self.entries = entries
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decodeIfPresent(String.self, forKey: .date)
        week = try c.decodeIfPresent(String.self, forKey: .week)
        day = try c.decodeIfPresent(String.self, forKey: .day)
        lesson = try c.decodeIfPresent(Int.self, forKey: .lesson) ?? 0
        className = try c.decodeIfPresent(String.self, forKey: .className) ?? ""
        scope = try c.decodeIfPresent(String.self, forKey: .scope)
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        entries = try c.decodeIfPresent([LessonEntry].self, forKey: .entries) ?? []
    }
}

public struct ContentFeed: Codable {
    public let announcements: [Announcement]
    public let events: [SchoolEvent]
    public let substitutions: [Substitution]

    enum CodingKeys: String, CodingKey { case announcements, events, substitutions }

    public init(announcements: [Announcement] = [], events: [SchoolEvent] = [],
                substitutions: [Substitution] = []) {
        self.announcements = announcements
        self.events = events
        self.substitutions = substitutions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        announcements = try c.decodeIfPresent([Announcement].self, forKey: .announcements) ?? []
        events = try c.decodeIfPresent([SchoolEvent].self, forKey: .events) ?? []
        substitutions = try c.decodeIfPresent([Substitution].self, forKey: .substitutions) ?? []
    }
}

public struct SchoolCalendar: Codable {
    public struct DayOff: Codable {
        public let date: String
        public let label: String?
    }
    public struct Range: Codable {
        public let from: String
        public let to: String
        public let label: String?
    }
    public let daysOff: [DayOff]
    public let ranges: [Range]

    public init(daysOff: [DayOff] = [], ranges: [Range] = []) {
        self.daysOff = daysOff
        self.ranges = ranges
    }

    public func label(for isoDate: String) -> String? {
        if let day = daysOff.first(where: { $0.date == isoDate }) {
            return day.label ?? "Навчальних занять немає"
        }
        if let range = ranges.first(where: { $0.from <= isoDate && isoDate <= $0.to }) {
            return range.label ?? "Канікули"
        }
        return nil
    }
}
