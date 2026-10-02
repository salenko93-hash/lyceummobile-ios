import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            if model.isAlarm {
                NavigationStack {
                    EmergencyView(model: model)
                }
            } else if model.isAllClear {
                AllClearView()
            } else if model.isSilence {
                MinuteSilenceView(model: model, isFullscreen: true)
            } else {
                TabView {
                    NavigationStack {
                        DashboardView(model: model)
                    }
                    .tabItem {
                        Label("Головна", systemImage: "house.fill")
                    }

                    NavigationStack {
                        TimetableView(model: model)
                    }
                    .tabItem {
                        Label("Розклад", systemImage: "calendar")
                    }

                    NavigationStack {
                        AnnouncementsView(model: model)
                    }
                    .tabItem {
                        Label("Оголошення", systemImage: "megaphone.fill")
                    }

                    NavigationStack {
                        MinuteSilenceView(model: model, isFullscreen: false)
                    }
                    .tabItem {
                        Label("Пам'ять", systemImage: "flame")
                    }

                    NavigationStack {
                        SettingsView(model: model)
                    }
                    .tabItem {
                        Label("Налаштування", systemImage: "gearshape.fill")
                    }
                }
                .tint(Brand.blue)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.isAlarm)
        .animation(.easeInOut(duration: 0.2), value: model.isSilence)
    }
}

struct AllClearView: View {
    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.40, blue: 0.28).ignoresSafeArea()
            VStack(spacing: 23) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 94))
                Text("ВІДБІЙ ПОВІТРЯНОЇ ТРИВОГИ")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Перевірено через alerts.in.ua • UID 81")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
    }
}
