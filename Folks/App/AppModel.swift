import Observation
import SwiftUI
import UserNotifications

enum HomeMode: String, CaseIterable, Identifiable {
    case contacts = "Contacts", events = "Events"
    var id: String { rawValue }
}

@MainActor @Observable
final class AppModel {
    static weak var current: AppModel?
    let store = ContactsStore()
    let settings = ReminderSettings()
    let cards: ContactCardStore

    /// Which list the segmented control at the top is showing.
    var homeMode: HomeMode = .contacts
    var contactsSelection: String?
    /// Selected event occurrence id (contactID|event|time).
    var eventsSelection: String?
    /// Set by the contact context menu; HomeView shows the Share Contact screen / delete confirmation.
    var shareRequest: Contact?
    var deleteRequest: Contact?
    /// Set by the card button on My Card; HomeView shows Contact Cards.
    var showCards = false
    /// A contact card to open straight away in Contact Cards, e.g. from tapping a QR widget.
    var cardRequest: UUID?
    /// Set when a notification asks to open the wish composer for a contact.
    var wishRequestID: String?

    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "hasOnboarded") }
    }

    init() {
        cards = ContactCardStore(isDemo: { [store] in store.isShowingSample })
        hasOnboarded = UserDefaults.standard.bool(forKey: "hasOnboarded") && store.isSignedIn
        ReminderScheduler.registerCategories()
        AppModel.current = self
        ContactDirectory.store = store
        AppDelegate.onNotification = { [weak self] contactID, eventKey, action in
            self?.handleNotification(contactID: contactID, eventKey: eventKey, action: action)
        }
    }

    /// Drops open contacts and sheets, e.g. when the contacts on screen are swapped (Demo Mode, sign in/out).
    func resetNavigation() {
        contactsSelection = nil
        eventsSelection = nil
        wishRequestID = nil
    }

    /// Handles a tap or action button on a reminder notification.
    func handleNotification(contactID: String, eventKey: String?, action: String) {
        switch action {
        case ReminderSchedulerConstants.wishAction:
            open(contactID: contactID, wish: true)
        case ReminderSchedulerConstants.muteEventAction:
            if let eventKey { settings.mutedEvents.insert(eventKey) }
            rescheduleReminders()
        case ReminderSchedulerConstants.muteContactAction:
            settings.mutedIDs.insert(contactID)
            rescheduleReminders()
        default:
            open(contactID: contactID, wish: false)
        }
    }

    func open(contactID: String, wish: Bool) {
        homeMode = .contacts
        contactsSelection = contactID
        wishRequestID = wish ? contactID : nil
    }

    /// Your contact cards with the vCard each one shares, for the QR widgets.
    var qrCardSnapshots: [QRCardSnapshot] {
        guard let me = store.myCard else { return [] }
        let full = QRCardSnapshot(id: QRCardSnapshot.fullID, name: "Full contact", symbol: "person.text.rectangle", colorIndex: 0,
                                  vCard: me.keeping(me.allShareFields).vCard)
        return [full] + cards.cards.map {
            QRCardSnapshot(id: $0.id.uuidString, name: $0.name, symbol: $0.symbol, colorIndex: $0.colorIndex,
                           vCard: me.keeping(me.shareFields(for: $0.fields)).vCard)
        }
    }

    /// Opens Contact Cards on the card the widget names.
    func open(cardID: String) {
        homeMode = .contacts
        cardRequest = cardID == QRCardSnapshot.fullID ? ContactCard.fullID : UUID(uuidString: cardID)
        showCards = true
    }

    func rescheduleReminders() {
        // Sample contacts are for show only: never schedule reminders for them (and clear any real ones while demoing).
        let contacts = store.isShowingSample ? [] : store.contacts
        Task { await ReminderScheduler.reschedule(contacts: contacts, settings: settings) }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor static var onNotification: ((_ contactID: String, _ eventKey: String?, _ action: String) -> Void)?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["contactID"] as? String else { return }
        let eventKey = response.notification.request.content.userInfo["eventKey"] as? String
        let action = response.actionIdentifier
        await MainActor.run { Self.onNotification?(id, eventKey, action) }
    }
}

enum ReminderSchedulerConstants {
    static let wishAction = "WISH"
    static let muteEventAction = "MUTE_EVENT"
    static let muteContactAction = "MUTE_CONTACT"
}
