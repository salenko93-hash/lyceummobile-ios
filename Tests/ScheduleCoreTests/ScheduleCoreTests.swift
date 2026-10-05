import XCTest
@testable import LyceumMobileCore

final class ScheduleCoreTests: XCTestCase {
    func date(_ iso: String) -> Date {
        guard let parsed = SchoolClock.fromISO(iso) else {
            fatalError("Bad test fixture: \(iso)")
        }
        return parsed
    }

    func testWeekRotationDSTSafe() {
        XCTAssertEqual(WeekCycle.type(on: date("2026-08-31"), numeratorMonday: "2026-08-31"), .numerator)
        XCTAssertEqual(WeekCycle.type(on: date("2026-09-07"), numeratorMonday: "2026-08-31"), .denominator)
        XCTAssertEqual(WeekCycle.type(on: date("2026-09-14"), numeratorMonday: "2026-08-31"), .numerator)
        XCTAssertEqual(WeekCycle.type(on: date("2026-10-02"), numeratorMonday: "2026-08-31"), .numerator)
        XCTAssertEqual(WeekCycle.type(on: date("2026-08-24"), numeratorMonday: "2026-08-31"), .denominator)
        XCTAssertEqual(WeekCycle.type(on: date("2026-10-26"), numeratorMonday: "2026-08-31"), .numerator)
    }

    func testBellEnDashAndBoundaries() {
        let bell = BellSlot(lesson: 2, time: "08:55–09:40")
        XCTAssertEqual(bell.minuteBounds?.start, 8 * 60 + 55)
        XCTAssertEqual(bell.minuteBounds?.end, 9 * 60 + 40)
        XCTAssertNil(BellSlot(lesson: 1, time: "invalid").minuteBounds)
    }

    func testAndroidJSONAndLatestSubstitutions() throws {
        let json = """
        {
          "weekType":"NUMERATOR",
          "bellSchedule":[{"lesson":1,"time":"08:00–08:45"}],
          "days":{"MONDAY":{"1":{"10-А":[{"subject":"Алгебра","room":"7","teacher":"A"}]}}}
        }
        """
        let schedule = try JSONDecoder().decode(ScheduleFile.self, from: Data(json.utf8))
        XCTAssertEqual(schedule.entries(day: "MONDAY", lesson: 1, className: "10-А").first?.subject, "Алгебра")
        let override = Substitution(date: "2026-08-31", week: "numerator", day: "MONDAY",
                                    lesson: 1, className: "10-А", scope: "both", active: true,
                                    entries: [LessonEntry(subject: "Історія", room: "2", teacher: "B")])
        let result = ScheduleEngine.lessons(in: schedule, on: date("2026-08-31"),
                                            className: "10-А", substitutions: [override],
                                            shelter: false, referenceMonday: "2026-08-31")
        XCTAssertEqual(result.first?.1.first?.subject, "Історія")
        let cancel = Substitution(date: "2026-08-31", week: "all", day: "MONDAY",
                                  lesson: 1, className: "10-А", scope: "normal",
                                  active: true, entries: [])
        let cancelled = ScheduleEngine.lessons(in: schedule, on: date("2026-08-31"),
                                               className: "10-А", substitutions: [override, cancel],
                                               shelter: false, referenceMonday: "2026-08-31")
        XCTAssertEqual(cancelled.first?.1.count, 0)
        let shelter = ScheduleEngine.lessons(in: schedule, on: date("2026-08-31"),
                                             className: "10-А", substitutions: [override, cancel],
                                             shelter: true, referenceMonday: "2026-08-31")
        XCTAssertEqual(shelter.first?.1.first?.subject, "Історія")
    }

    func testFeedDefaultsAndSchoolCalendar() throws {
        let data = Data(#"{"announcements":[{"title":"Оголошення","message":"Тест","priority":"NORMAL","active":true}],"substitutions":[]}"#.utf8)
        let feed = try JSONDecoder().decode(ContentFeed.self, from: data)
        XCTAssertEqual(feed.announcements.count, 1)
        XCTAssertEqual(feed.events.count, 0)
        XCTAssertEqual(feed.substitutions.count, 0)
        let calendar = try JSONDecoder().decode(SchoolCalendar.self, from: Data("""
            {"daysOff":[{"date":"2026-10-14","label":"Вихідний"}],
             "ranges":[{"from":"2026-12-21","to":"2027-01-08","label":"Канікули"}]}
            """.utf8))
        XCTAssertEqual(calendar.label(for: "2026-10-14"), "Вихідний")
        XCTAssertEqual(calendar.label(for: "2027-01-01"), "Канікули")
    }

    func testKyivTimezoneFallbackIsSafe() {
        // Must never depend on force-unwrapping a timezone identifier.
        XCTAssertFalse(SchoolClock.kyiv.identifier.isEmpty)
        XCTAssertNotEqual(SchoolClock.displayTime(Date(timeIntervalSince1970: 0)), "")
    }
}
