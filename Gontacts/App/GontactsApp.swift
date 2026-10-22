import SwiftUI

@main
struct GontactsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active, model.hasOnboarded else { return }
                    model.store.refreshToday()
                    Task {
                        await model.store.flushPending()
                        await model.store.sync(userInitiated: false)
                        model.rescheduleReminders()
                    }
                }
                .onChange(of: model.store.sourceVersion) { _, _ in model.resetNavigation() }
                .onChange(of: model.store.revision) { _, _ in
                    if model.hasOnboarded { model.rescheduleReminders() }
                }
                .alert("Something went wrong", isPresented: Binding(get: { model.store.errorMessage != nil }, set: { if !$0 { model.store.errorMessage = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.store.errorMessage ?? "")
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.hasOnboarded {
            HomeView()
        } else {
            OnboardingFlow()
        }
    }
}

