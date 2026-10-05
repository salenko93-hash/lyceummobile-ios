import SwiftUI

struct MinuteSilenceView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: AppSettings
    let isFullscreen: Bool

    init(model: AppModel, isFullscreen: Bool) {
        self.model = model
        settings = model.settings
        self.isFullscreen = isFullscreen
    }

    private var secondsRemaining: Int {
        if let test = model.testSilenceUntil, test > model.now {
            return max(0, Int(ceil(test.timeIntervalSince(model.now))))
        }
        // Calendar minute respects Europe/Kyiv time zone, not the phone's travel time zone.
        let second = SchoolClock.calendar.component(.second, from: model.now)
        return SchoolClock.isDailySilence(model.now) ? (60 - second) : 60
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 30)
                Image(systemName: "flame.fill")
                    .font(.system(size: 96, weight: .light))
                    .foregroundStyle(Brand.gold)
                    .shadow(color: Brand.gold.opacity(0.4), radius: 25)
                    .accessibilityLabel("Свічка пам'яті")

                Text("ХВИЛИНА\nМОВЧАННЯ")
                    .font(.system(size: 37, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("Вшановуємо пам’ять загиблих")
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.86))

                Text(isFullscreen ? "\(secondsRemaining)" : "09:00 — 09:01")
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(Brand.gold)
                    .accessibilityLabel(isFullscreen
                                        ? "Залишилося \(secondsRemaining) секунд"
                                        : "Щодня з 9 до 9:01")

                Text("Метроном: 60 ударів за хвилину")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))

                if !isFullscreen {
                    VStack(spacing: 14) {
                        Text("Метроном автоматично працює тільки коли застосунок відкритий і показує хвилину мовчання.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        Toggle("Увімкнути метроном", isOn: $settings.metronomeEnabled)
                            .tint(Brand.gold)
                        HStack {
                            Text("Гучність")
                            Slider(value: $settings.metronomeVolume, in: 0...1, step: 0.05)
                                .tint(Brand.gold)
                            Text("\(Int(settings.metronomeVolume * 100))%")
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }
                        Button("Тестувати 60 секунд") {
                            model.beginSilenceTest()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.gold)
                        .foregroundStyle(Brand.navy)
                        .disabled(model.isAlarm)
                    }
                    .padding(20)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                } else if model.testSilenceUntil != nil {
                    Button("Завершити тест") {
                        model.endSilenceTest()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .padding(.top, 10)
                }
                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(25)
            .foregroundStyle(.white)
        }
        .background(Brand.deepNavy.ignoresSafeArea())
        .navigationTitle(isFullscreen ? "" : "Хвилина мовчання")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.metronomeEnabled) { _ in model.updateMetronome() }
        .onChange(of: settings.metronomeVolume) { _ in model.updateMetronome() }
    }
}
