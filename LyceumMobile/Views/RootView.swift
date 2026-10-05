import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            if model.isAlarm {
                NavigationView {
                    EmergencyView(model: model)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            } else if model.isAllClear {
                AllClearView()
            } else if model.isSilence {
                MinuteSilenceView(model: model, isFullscreen: true)
            } else {
                TabView {
                    NavigationView {
                        DashboardView(model: model)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("Головна", systemImage: "house.fill")
                    }

                    NavigationView {
                        TimetableView(model: model)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("Розклад", systemImage: "calendar")
                    }

                    NavigationView {
                        AnnouncementsView(model: model)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("Оголошення", systemImage: "megaphone.fill")
                    }

                    NavigationView {
                        MinuteSilenceView(model: model, isFullscreen: false)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("Пам'ять", systemImage: "flame")
                    }

                    NavigationView {
                        SettingsView(model: model)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
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
