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
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        TabView(selection: Binding(
            get: { model.tab },
            set: { new in
                if new == model.tab { model.reselect(new) }
                model.tab = new
            }
        )) {
            Tab("Contacts", systemImage: "person.2", value: AppTab.contacts) { ContactsView() }
            Tab("Events", systemImage: "calendar", value: AppTab.events) { EventsView() }
            Tab("Settings", systemImage: "slider.horizontal.3", value: AppTab.settings) { SettingsView() }
        }
        .overlay(alignment: .bottomTrailing) {
            // On iPhone the search button floats beside the tab bar. On iPad the tab bar is at the top, so
            // search lives in the Contacts toolbar instead.
            if sizeClass == .compact {
                Button { model.showSearch = true } label: {
                    Image(systemName: "magnifyingglass").font(.title3.weight(.medium)).frame(width: 50, height: 50)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Search")
                .padding(.trailing, 8)
                .padding(.bottom, 4)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { model.showSearch }, set: { model.showSearch = $0 })) {
            SearchScreen()
        }
    }
}
