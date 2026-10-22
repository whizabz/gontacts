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
            MainTabs()
        } else {
            OnboardingFlow()
        }
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // The system tab bar: floating Liquid Glass, morphing selection, minimize-on-scroll and the search tab
        // all come from it, so they animate the way iOS does everywhere else.
        TabView(selection: Binding(get: { model.tab }, set: select)) {
            Tab("Contacts", systemImage: "person.2", value: AppTab.contacts) { ContactsView() }
            Tab("Events", systemImage: "calendar", value: AppTab.events) { EventsView() }
            Tab("Settings", systemImage: "slider.horizontal.3", value: AppTab.settings) { SettingsView() }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private func select(_ new: AppTab) {
        if new == model.tab { model.reselect(new) }
        model.tab = new
    }
}
