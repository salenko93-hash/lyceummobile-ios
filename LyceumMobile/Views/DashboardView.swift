import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var schedules: ScheduleStore
    @ObservedObject private var content: ContentService
    @ObservedObject private var weather: WeatherService

    init(model: AppModel) {
        self.model = model
        settings = model.settings
        schedules = model.schedules
        content = model.content
        weather = model.weather
    }

    private var rows: [(BellSlot, [LessonEntry])] {
        guard let schedule = schedules.schedule(for: model.currentWeek, shelter: false) else {
            return []
        }
        return ScheduleEngine.lessons(in: schedule, on: model.now,
                className: settings.selectedClass, substitutions: content.feed.substitutions,
                shelter: false, referenceMonday: settings.validReferenceMonday)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Label("КРОПИВНИЦЬКИЙ", systemImage: "location.fill")
                                .font(.caption2.weight(.bold))
                                .kerning(1.4)
                                .foregroundStyle(Brand.gold)
                            Text("Мій ліцей")
                                .font(.largeTitle.weight(.heavy))
                            Text(SchoolClock.displayDate(model.now))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        ClassPicker(settings: settings)
                    }

                    HStack(alignment: .bottom, spacing: 12) {
                        Text(SchoolClock.displayTime(model.now))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if let temperature = weather.temperature {
                            VStack(alignment: .trailing) {
                                Text(String(format: "%.0f°", temperature))
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                Text(weather.description).font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    Label(model.currentWeek.rawValue, systemImage: "calendar")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Brand.gold)
                }
                .foregroundStyle(.white)
                .padding(21)
                .background(
                    LinearGradient(colors: [Brand.navy, Brand.blue],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )

                SchoolCard {
                    HStack {
                        Image(systemName: model.alert.isAlarm
                              ? "exclamationmark.triangle.fill"
                              : "shield.lefthalf.filled")
                            .font(.title3)
                            .foregroundStyle(model.alertOnline && model.alert == .none
                                             ? Color.green : Color.orange)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Безпека · UID 81")
                                .font(.headline)
                                .foregroundStyle(Brand.navy)
                            Text(model.alertOnline && model.alert == .none
                                 ? "За останньою перевіркою активної тривоги немає"
                                 : model.alertStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let date = model.alertLastVerified {
                                Text("Останнє підтвердження: \(date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("Не замінює офіційні оповіщення ДСНС та персоналу ліцею.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let holiday = model.todayHoliday {
                    SchoolCard {
                        SectionCaption(text: "Календар")
                        Text(holiday).font(.headline)
                    }
                } else {
                    SchoolCard {
                        SectionCaption(text: "Сьогодні · \(settings.selectedClass)")
                        if let schedule = schedules.schedule(for: model.currentWeek,
                                                              shelter: false) {
                            if let bell = ScheduleEngine.currentBell(in: schedule, date: model.now),
                               let row = rows.first(where: { $0.0.lesson == bell.lesson }) {
                                Text("Зараз \(bell.time)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Brand.blue)
                                Text(row.1.isEmpty ? "Немає уроку" :
                                        row.1.map(\.subject).filter { !$0.isEmpty }.joined(separator: " / "))
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Brand.navy)
                            } else {
                                Text("Зараз перерва або занять немає.")
                                    .font(.subheadline)
                            }

                            if let next = ScheduleEngine.nextBell(in: schedule, date: model.now),
                               let row = rows.first(where: { $0.0.lesson == next.lesson }) {
                                Divider()
                                Text("Далі о \(next.time)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(row.1.isEmpty ? "Немає уроку" :
                                        row.1.map(\.subject).filter { !$0.isEmpty }.joined(separator: " / "))
                                    .font(.headline)
                                    .foregroundStyle(Brand.navy)
                            }
                        } else {
                            Text("Розклад недоступний.")
                        }
                    }
                }

                if let notice = content.feed.announcements.first(where: { $0.active }) {
                    SchoolCard {
                        SectionCaption(text: "Оголошення")
                        Text(notice.title).font(.headline).foregroundStyle(Brand.navy)
                        Text(notice.message).font(.subheadline)
                    }
                }

                Text("Розклад: \(schedules.version) · Оновлення тільки при підтвердженому стані без тривоги")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(Brand.lightBackground)
        .navigationTitle("Головна")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await model.refreshEverything() }
                } label: {
                    if model.isSyncing { ProgressView() }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .disabled(model.isSyncing)
                .accessibilityLabel("Синхронізувати")
            }
        }
    }
}
