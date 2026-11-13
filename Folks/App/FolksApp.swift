import SwiftUI

@main
struct FolksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { url in
                    // Widgets open the app on a contact.
                    if let id = WidgetStore.cardID(from: url) { model.open(cardID: id) }
                    if let id = WidgetStore.contactID(from: url) { model.open(contactID: id, wish: false) }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active, model.hasOnboarded else { return }
                    model.store.refreshToday()
                    Task {
                        await model.store.flushPending()
                        await model.store.sync(userInitiated: false)
                        model.rescheduleReminders()
                    }
                }
                .task(id: model.qrCardSnapshots) { WidgetPublisher.publishCards(model.qrCardSnapshots) }
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
        .commands {
            // Menu bar items on the Mac (and shortcuts with an iPad keyboard).
            CommandGroup(replacing: .newItem) {
                Button("New Contact") { NotificationCenter.default.post(name: .folksNewContact, object: nil) }
                    .keyboardShortcut("n")
                    .disabled(!model.hasOnboarded)
            }
            CommandGroup(after: .textEditing) {
                Button("Find") { NotificationCenter.default.post(name: .folksFind, object: nil) }
                    .keyboardShortcut("f")
                    .disabled(!model.hasOnboarded)
            }
        }
    }
}

extension Notification.Name {
    static let folksNewContact = Notification.Name("folks.newContact")
    static let folksFind = Notification.Name("folks.find")
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

