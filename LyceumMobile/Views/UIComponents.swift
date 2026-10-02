import SwiftUI

enum Brand {
    static let navy = Color(red: 0.045, green: 0.145, blue: 0.305)
    static let deepNavy = Color(red: 0.022, green: 0.080, blue: 0.18)
    static let blue = Color(red: 0.11, green: 0.39, blue: 0.76)
    static let gold = Color(red: 0.96, green: 0.72, blue: 0.22)
    static let lightBackground = Color(red: 0.953, green: 0.969, blue: 0.988)
    static let danger = Color(red: 0.68, green: 0.09, blue: 0.15)
}

struct SchoolCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .shadow(color: Brand.navy.opacity(0.07), radius: 12, y: 4)
    }
}

struct SectionCaption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(Brand.blue)
    }
}

struct ClassPicker: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Menu {
            ForEach(ScheduleEngine.classNames, id: \.self) { name in
                Button(name) { settings.selectedClass = name }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "person.2.fill")
                Text(settings.selectedClass)
                    .fontWeight(.bold)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(Brand.navy)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(.white, in: Capsule())
        }
        .accessibilityLabel("Вибрати клас, зараз \(settings.selectedClass)")
    }
}

struct DayHeader: View {
    let date: Date
    let week: WeekType

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(SchoolClock.displayDate(date))
                        .font(.title3.weight(.bold))
            .foregroundStyle(Brand.navy)
            Text(week.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Brand.blue)
        }
    }
}

struct LessonRows: View {
    let rows: [(BellSlot, [LessonEntry])]
    let highlighted: Int?
    var emergency = false

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { index in
                let bell = rows[index].0
                let subjects = rows[index].1
                HStack(alignment: .top, spacing: 12) {
                    Text("\(bell.lesson)")
                        .font(.title3.weight(.heavy))
                        .frame(width: 35, height: 39)
                        .background(
                            highlighted == bell.lesson
                                ? (emergency ? Brand.danger : Brand.blue)
                                : Brand.lightBackground,
                            in: RoundedRectangle(cornerRadius: 11)
                        )
                        .foregroundStyle(highlighted == bell.lesson ? .white : Brand.navy)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bell.time)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                        if subjects.isEmpty || subjects.allSatisfy({ $0.subject.isEmpty }) {
                            Text("Немає уроку")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(subjects.indices, id: \.self) { subjectIndex in
                                let entry = subjects[subjectIndex]
                                VStack(alignment: .leading, spacing: 2) {
                                    if !entry.subject.isEmpty {
                                        Text(entry.subject)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Brand.navy)
                                    }
                                    let details = [entry.room.isEmpty ? "" : "Каб. \(entry.room)",
                                                   entry.teacher]
                                        .filter { !$0.isEmpty }
                                        .joined(separator: " · ")
                                    if !details.isEmpty {
                                        Text(details)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if subjectIndex < subjects.count - 1 {
                                    Divider()
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    if highlighted == bell.lesson {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .foregroundStyle(emergency ? Brand.danger : Brand.blue)
                            .accessibilityLabel("Поточний урок")
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    highlighted == bell.lesson
                        ? (emergency ? Color.red.opacity(0.08) : Color.blue.opacity(0.07))
                        : Color.white,
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
        }
    }
}
