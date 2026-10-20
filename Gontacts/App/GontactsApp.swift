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
                        await model.store.sync()
                        model.rescheduleReminders()
                    }
                }
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
        TabView(selection: Binding(
            get: { model.tab },
            set: { new in
                // The search tab is only a button: it opens our own search screen and the selected tab
                // doesn't change, so closing search lands you back exactly where you were.
                if new == .search {
                    model.showSearch = true
                    return
                }
                if new == model.tab { model.reselect(new) }
                model.tab = new
            }
        )) {
            Tab("Contacts", systemImage: "person.2", value: AppTab.contacts) { ContactsView() }
            Tab("Events", systemImage: "calendar", value: AppTab.events) { EventsView() }
            Tab("Settings", systemImage: "slider.horizontal.3", value: AppTab.settings) { SettingsView() }
            Tab(value: AppTab.search, role: .search) { Color.clear }
        }
        .fullScreenCover(isPresented: Binding(get: { model.showSearch }, set: { model.showSearch = $0 })) {
            SearchScreen()
        }
    }
}
