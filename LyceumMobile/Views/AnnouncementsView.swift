import SwiftUI

struct AnnouncementsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var content: ContentService

    init(model: AppModel) {
        self.model = model
        content = model.content
    }

    private var notices: [Announcement] {
        content.feed.announcements.filter(\.active)
    }

    private var events: [SchoolEvent] {
        content.feed.events.filter(\.active)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Оголошення")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundStyle(Brand.navy)
                        Text("Інформація з Google Таблиці")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await content.refresh(from: model.settings.googleSheetsURL) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .padding(12)
                            .background(.white, in: Circle())
                    }
                    .accessibilityLabel("Оновити оголошення")
                }

                Text(content.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if notices.isEmpty {
                    SchoolCard {
                        Image(systemName: "megaphone")
                            .font(.largeTitle)
                            .foregroundStyle(Brand.blue)
                        Text("Активних оголошень немає")
                            .font(.headline)
                            .foregroundStyle(Brand.navy)
                        Text("Додайте рядок із TRUE у вкладку Announcements Google Таблиці.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(notices.indices, id: \.self) { index in
                        let notice = notices[index]
                        SchoolCard {
                            HStack {
                                SectionCaption(text: notice.priority.uppercased() == "HIGH" ||
                                               notice.priority.uppercased() == "URGENT"
                                               ? "Важливо" : "Оголошення")
                                Spacer()
                                Image(systemName: "megaphone.fill")
                                    .foregroundStyle(Brand.blue)
                            }
                            Text(notice.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Brand.navy)
                            Text(notice.message)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                if !events.isEmpty {
                    SectionCaption(text: "Події")
                        .padding(.top, 5)
                    ForEach(events.indices, id: \.self) { index in
                        let event = events[index]
                        SchoolCard {
                            Label(event.title, systemImage: "calendar")
                                .font(.headline)
                                .foregroundStyle(Brand.navy)
                            Text([event.date, event.time, event.location]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Brand.lightBackground)
        .navigationTitle("Оголошення")
        .navigationBarTitleDisplayMode(.inline)
    }
}
