import SwiftUI

struct TimetableView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var schedules: ScheduleStore
    @ObservedObject private var content: ContentService
    @State private var selectedDate = Date()
    @State private var showShelter = false

    init(model: AppModel) {
        self.model = model
        settings = model.settings
        schedules = model.schedules
        content = model.content
    }

    private var week: WeekType {
        WeekCycle.type(on: selectedDate, numeratorMonday: settings.validReferenceMonday)
    }

    private var schedule: ScheduleFile? {
        schedules.schedule(for: week, shelter: showShelter)
    }

    private var holiday: String? {
        schedules.holidayCalendar.label(for: SchoolClock.isoDate(selectedDate))
    }

    private var rows: [(BellSlot, [LessonEntry])] {
        guard let schedule = schedule else { return [] }
        return ScheduleEngine.lessons(in: schedule, on: selectedDate,
                className: settings.selectedClass,
                substitutions: content.feed.substitutions,
                shelter: showShelter, referenceMonday: settings.validReferenceMonday)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    DayHeader(date: selectedDate, week: week)
                    Spacer()
                    ClassPicker(settings: settings)
                }
                DatePicker("Дата", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .environment(\.timeZone, SchoolClock.kyiv)
                Picker("Тип розкладу", selection: $showShelter) {
                    Text("Звичайний").tag(false)
                    Text("Укриття").tag(true)
                }
                .pickerStyle(.segmented)

                if showShelter {
                    Label("Місця й дані укриття — тільки для авторизованих користувачів.",
                          systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(Brand.danger)
                }

                if let holiday = holiday {
                    SchoolCard {
                        Label(holiday, systemImage: "calendar.badge.exclamationmark")
                            .font(.headline)
                    }
                } else if schedule != nil {
                    LessonRows(rows: rows,
                               highlighted: SchoolClock.isoDate(selectedDate) == SchoolClock.isoDate(model.now)
                                    ? schedule.flatMap { ScheduleEngine.currentBell(in: $0, date: model.now)?.lesson }
                                    : nil,
                               emergency: showShelter)
                } else {
                    SchoolCard {
                        Label("Розклад недоступний", systemImage: "calendar.badge.exclamationmark")
                            .font(.headline)
                        Text("Перевірте вбудовані файли або синхронізацію.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Версія даних: \(schedules.version)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Brand.lightBackground)
        .navigationTitle("Розклад уроків")
        .navigationBarTitleDisplayMode(.inline)
    }
}
