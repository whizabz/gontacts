import Observation
import SwiftUI
import UserNotifications

enum HomeMode: String, CaseIterable, Identifiable {
    case contacts = "Contacts", events = "Events"
    var id: String { rawValue }
}

@MainActor @Observable
final class AppModel {
    let store = ContactsStore()
    let settings = ReminderSettings()

    /// Which list the segmented control at the top is showing.
    var homeMode: HomeMode = .contacts
    var contactsSelection: String?
    /// Selected event occurrence id (contactID|event|time).
    var eventsSelection: String?
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

    /// Drops open contacts and sheets, e.g. when the contacts on screen are swapped (Demo Mode, sign in/out).
    func resetNavigation() {
        contactsSelection = nil
        eventsSelection = nil
        wishRequestID = nil
    }

    func open(contactID: String, wish: Bool) {
        homeMode = .contacts
        contactsSelection = contactID
        wishRequestID = wish ? contactID : nil
    }

    func rescheduleReminders() {
        // Sample contacts are for show only: never schedule reminders for them (and clear any real ones while demoing).
        let contacts = store.isShowingSample ? [] : store.contacts
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
