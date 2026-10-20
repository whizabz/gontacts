import Observation
import SwiftUI
import UserNotifications

enum AppTab: Hashable { case contacts, events, settings, search }

@MainActor @Observable
final class AppModel {
    let store = ContactsStore()
    let settings = ReminderSettings()

    var tab: AppTab = .contacts
    var contactsSelection: String?
    /// Set when a notification asks to open the wish composer for a contact.
    var wishRequestID: String?

    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "hasOnboarded") }
    }

    init() {
        hasOnboarded = UserDefaults.standard.bool(forKey: "hasOnboarded") && store.isSignedIn
        ReminderScheduler.registerCategories()
        AppDelegate.onNotification = { [weak self] contactID, wish in
            self?.open(contactID: contactID, wish: wish)
        }
    }

    func open(contactID: String, wish: Bool) {
        tab = .contacts
        contactsSelection = contactID
        wishRequestID = wish ? contactID : nil
    }

    func rescheduleReminders() {
        let contacts = store.contacts
        Task { await ReminderScheduler.reschedule(contacts: contacts, settings: settings) }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor static var onNotification: ((String, Bool) -> Void)?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["contactID"] as? String else { return }
        let wish = response.actionIdentifier == ReminderSchedulerConstants.wishAction
        await MainActor.run { Self.onNotification?(id, wish) }
    }
}

enum ReminderSchedulerConstants {
    static let wishAction = "WISH"
}
