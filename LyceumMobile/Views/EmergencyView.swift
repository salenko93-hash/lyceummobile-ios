import SwiftUI

struct EmergencyView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var schedules: ScheduleStore
    @ObservedObject private var content: ContentService

    init(model: AppModel) {
        self.model = model
        settings = model.settings
        schedules = model.schedules
        content = model.content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 70))
                    .padding(.top, 25)
                    .accessibilityHidden(true)
                Text(model.alert.label)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                Text("Кропивницький район • alerts.in.ua UID 81")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)

                if !model.alertIsCurrent {
                    Label("Дані можуть бути застарілими. Дотримуйтесь офіційних сповіщень.",
                          systemImage: "wifi.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(.black.opacity(0.22),
                                    in: RoundedRectangle(cornerRadius: 14))
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("РОЗКЛАД УКРИТТЯ")
                            .font(.headline.weight(.heavy))
                        Spacer()
                        ClassPicker(settings: settings)
                    }
                    .foregroundStyle(Brand.navy)

                    Text("\(model.currentWeek.rawValue) · \(settings.selectedClass)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Brand.danger)
                    if let timetable = schedules.schedule(for: model.currentWeek, shelter: true) {
                        let rows = ScheduleEngine.lessons(in: timetable, on: model.now,
                                className: settings.selectedClass,
                                substitutions: content.feed.substitutions, shelter: true,
                                referenceMonday: settings.validReferenceMonday)
                        LessonRows(rows: rows,
                                   highlighted: ScheduleEngine.currentBell(in: timetable,
                                                                           date: model.now)?.lesson,
                                   emergency: true)
                    } else {
                        Text("Локальний розклад укриття недоступний. Виконуйте вказівки персоналу.")
                            .font(.subheadline)
                            .foregroundStyle(Brand.navy)
                    }
                }
                .padding(15)
                .foregroundStyle(Brand.navy)
                .background(Brand.lightBackground,
                            in: RoundedRectangle(cornerRadius: 24))

                Text("Цей застосунок є допоміжним. Орієнтуйтеся на офіційні канали тривоги та інструкції відповідальних осіб.")
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 22)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
        }
        .background(Brand.danger.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
