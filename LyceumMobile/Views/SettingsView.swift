import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var schedules: ScheduleStore
    @ObservedObject private var content: ContentService

    @State private var newToken = ""
    @State private var tokenMessage = ""
    @State private var showingDeleteToken = false

    init(model: AppModel) {
        self.model = model
        settings = model.settings
        schedules = model.schedules
        content = model.content
    }

    var body: some View {
        Form {
            Section("Мій клас") {
                Picker("Клас", selection: $settings.selectedClass) {
                    ForEach(ScheduleEngine.classNames, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                TextField("Базовий понеділок чисельника", text: $settings.referenceMonday)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
                Text("YYYY-MM-DD. Чинна дата: \(settings.validReferenceMonday)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Label("Район UID 81", systemImage: "shield.fill")
                    Spacer()
                    Text("Кропивницький").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Останній стан")
                    Spacer()
                    Text(model.alert.isAlarm ? "Тривога" :
                            (model.alertIsCurrent ? "Перевірено" : "Невідомо / застаріло"))
                        .foregroundStyle(model.alert.isAlarm ? Brand.danger : .secondary)
                }
                if let verified = model.alertLastVerified {
                    Text("Перевірено: \(verified.formatted(date: .abbreviated, time: .standard))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                SecureField("Новий токен alerts.in.ua", text: $newToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Зберегти API-токен у Keychain") {
                    if KeychainTokenStore.save(newToken) {
                        newToken = ""
                        tokenMessage = "Токен збережено. Перевіряю UID 81…"
                        model.didChangeAlertToken()
                    } else {
                        tokenMessage = "Токен порожній або не вдалося його зберегти"
                    }
                }
                .disabled(newToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Перевірити alerts.in.ua зараз") {
                    Task { await model.refreshAlert() }
                }
                Text(model.alertStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !tokenMessage.isEmpty {
                    Text(tokenMessage)
                        .font(.footnote)
                }
                Button("Видалити токен", role: .destructive) {
                    showingDeleteToken = true
                }
                .confirmationDialog("Видалити токен із цього iPhone?",
                                    isPresented: $showingDeleteToken) {
                    Button("Видалити", role: .destructive) {
                        if KeychainTokenStore.clear() {
                            tokenMessage = "Токен видалено."
                            model.didChangeAlertToken()
                        }
                    }
                    Button("Скасувати", role: .cancel) {}
                }
            } header: {
                Text("Тривоги — тільки alerts.in.ua")
            } footer: {
                Text("Працює лише під час відкритого застосунку. Не є офіційним засобом сповіщення.")
            }

            Section("Google Sheets") {
                TextField("HTTPS URL Google Apps Script /exec", text: $settings.googleSheetsURL,
                          axis: .vertical)
                    .lineLimit(2...4)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Оновити оголошення") {
                    Task { await content.refresh(from: settings.googleSheetsURL) }
                }
                Text(content.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Дистанційне оновлення розкладів") {
                Picker("Джерело", selection: $settings.source) {
                    Text("GitHub").tag("GITHUB")
                    Text("Локальний HTTPS-сервер").tag("LOCAL")
                }
                TextField(settings.source == "GITHUB"
                          ? "GitHub Raw HTTPS /content_manifest.json"
                          : "Локальний HTTPS /content_manifest.json",
                          text: settings.source == "GITHUB"
                          ? $settings.githubManifestURL
                          : $settings.localManifestURL,
                          axis: .vertical)
                    .lineLimit(2...4)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Синхронізувати всі дані") {
                    Task { await model.refreshEverything() }
                }
                .disabled(model.isSyncing)
                if model.isSyncing { ProgressView("Синхронізація…") }
                Text("Версія: \(schedules.version)")
                    .font(.footnote)
                Text(schedules.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Оновлення розкладів відкладено без свіжого підтвердження відсутності тривоги.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Хвилина мовчання") {
                Toggle("Метроном 60 ударів/хв", isOn: $settings.metronomeEnabled)
                HStack {
                    Text("Гучність")
                    Slider(value: $settings.metronomeVolume, in: 0...1, step: 0.05)
                    Text("\(Int(settings.metronomeVolume * 100))%")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                Button("Тестувати хвилину мовчання • 60 с") {
                    model.beginSilenceTest()
                }
                .disabled(model.isAlarm)
            }

            Section("Про застосунок") {
                LabeledContent("Версія", value: "LyceumMobile iOS 1.0")
                LabeledContent("Оповіщення", value: "alerts.in.ua • UID 81")
                Text("Розроблено на основі LyceumTV 2.7.0.2. Локальний кеш, чотири розклади та заміни.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Push-повідомлення у фоновому режимі в цій версії відсутні. Використовуйте офіційні системи сповіщення.")
                    .font(.caption)
                    .foregroundStyle(Brand.danger)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Brand.lightBackground)
        .navigationTitle("Налаштування")
        .onChange(of: settings.metronomeEnabled) { _ in model.updateMetronome() }
        .onChange(of: settings.metronomeVolume) { _ in model.updateMetronome() }
    }
}
