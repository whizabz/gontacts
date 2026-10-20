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

    private var usesFloatingBar: Bool { sizeClass == .compact }

    var body: some View {
        TabView(selection: Binding(get: { model.tab }, set: select)) {
            Tab("Contacts", systemImage: "person.2", value: AppTab.contacts) { ContactsView().hidingSystemTabBar(usesFloatingBar) }
            Tab("Events", systemImage: "calendar", value: AppTab.events) { EventsView().hidingSystemTabBar(usesFloatingBar) }
            Tab("Settings", systemImage: "slider.horizontal.3", value: AppTab.settings) { SettingsView().hidingSystemTabBar(usesFloatingBar) }
        }
        // On iPhone we draw the tab bar ourselves: a tab pill plus a separate search circle. The system's own
        // search tab renders differently between iOS 26 releases (on some it becomes a fourth tab icon).
        .toolbarVisibility(usesFloatingBar ? .hidden : .automatic, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if usesFloatingBar { FloatingTabBar(selection: Binding(get: { model.tab }, set: select)) { model.showSearch = true } }
        }
        .fullScreenCover(isPresented: Binding(get: { model.showSearch }, set: { model.showSearch = $0 })) {
            SearchScreen()
        }
    }

    private func select(_ new: AppTab) {
        if new == model.tab { model.reselect(new) }
        model.tab = new
    }
}

/// The tab pill and the separate round search button, as in the design.
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    let onSearch: () -> Void

    private struct Item: Identifiable { let tab: AppTab; let title: String; let symbol: String; var id: AppTab { tab } }
    private let items = [
        Item(tab: .contacts, title: "Contacts", symbol: "person.2.fill"),
        Item(tab: .events, title: "Events", symbol: "calendar"),
        Item(tab: .settings, title: "Settings", symbol: "slider.horizontal.3"),
    ]

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    ForEach(items) { item in
                        Button { selection = item.tab } label: {
                            VStack(spacing: 2) {
                                Image(systemName: item.symbol).font(.system(size: 20, weight: .medium))
                                Text(item.title).font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(selection == item.tab ? Color.accentColor : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background {
                                if selection == item.tab { Capsule().fill(Color.accentColor.opacity(0.16)) }
                            }
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title)
                        .accessibilityAddTraits(selection == item.tab ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(4)
                .frame(height: 62)
                .glassEffect(.regular, in: .capsule)

                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass").font(.system(size: 22, weight: .medium)).foregroundStyle(.primary)
                        .frame(width: 62, height: 62)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Search")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
    }
}

private extension View {
    func hidingSystemTabBar(_ hide: Bool) -> some View {
        toolbarVisibility(hide ? .hidden : .automatic, for: .tabBar)
    }
}
