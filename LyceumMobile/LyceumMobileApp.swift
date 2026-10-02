import SwiftUI

@main
@MainActor
struct LyceumMobileApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .task {
                    if scenePhase == .active {
                        model.appDidBecomeActive()
                    }
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        model.appDidBecomeActive()
                    } else {
                        model.appDidEnterBackground()
                    }
                }
        }
    }
}
