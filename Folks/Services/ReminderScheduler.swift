import Foundation
import UserNotifications

/// Schedules local notifications from synced contact dates. iOS allows 64 pending
/// requests, so we schedule the soonest ones and refresh whenever data or settings change.
@MainActor
enum ReminderScheduler {
    static let center = UNUserNotificationCenter.current()
    static let category = "EVENT"

    static func registerCategories() {
        let wish = UNNotificationAction(identifier: ReminderSchedulerConstants.wishAction, title: "Send wishes", options: [.foreground],
                                        icon: UNNotificationActionIcon(systemImageName: "paperplane"))
        let muteEvent = UNNotificationAction(identifier: ReminderSchedulerConstants.muteEventAction, title: "Mute this reminder", options: [],
                                             icon: UNNotificationActionIcon(systemImageName: "bell.slash"))
        let muteContact = UNNotificationAction(identifier: ReminderSchedulerConstants.muteContactAction, title: "Mute this contact", options: [],
                                               icon: UNNotificationActionIcon(systemImageName: "person.crop.circle.badge.minus"))
        center.setNotificationCategories([UNNotificationCategory(identifier: category, actions: [wish, muteEvent, muteContact], intentIdentifiers: [])])
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(contacts: [Contact], settings: ReminderSettings, now: Date = .now, calendar: Calendar = .current) async {
        center.removeAllPendingNotificationRequests()
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let enabled = contacts.filter { !settings.mutedIDs.contains($0.id) }
        let horizon = calendar.date(byAdding: .day, value: 400, to: now)!
        let occurrences = EventTimeline.occurrences(for: enabled, from: now, to: horizon, calendar: calendar)
            .filter { settings.isEnabled($0.event.kind) && !settings.mutedEvents.contains($0.event.muteKey(contactID: $0.contactID)) }

        var requests: [(fire: Date, request: UNNotificationRequest)] = []
        for o in occurrences {
            for lead in settings.leadDays {
                guard let day = calendar.date(byAdding: .day, value: -lead, to: o.date),
                      let fire = calendar.date(bySettingHour: settings.timeOfDay / 60, minute: settings.timeOfDay % 60, second: 0, of: day),
                      fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = title(for: o)
                content.body = body(for: o, lead: lead)
                content.sound = .default
                content.categoryIdentifier = category
                content.userInfo = ["contactID": o.contactID, "eventKey": o.event.muteKey(contactID: o.contactID)]
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                requests.append((fire, UNNotificationRequest(identifier: "\(o.id)|\(lead)", content: content, trigger: trigger)))
            }
        }
        // Keep a few of the 64 pending slots for icon-badge updates.
        for item in requests.sorted(by: { $0.fire < $1.fire }).prefix(44) {
            try? await center.add(item.request)
        }
        await scheduleBadges(occurrences: occurrences, now: now, calendar: calendar)
    }

    /// The app icon badge shows how many events fall on today. The current value is set directly;
    /// later days get a silent, badge-only notification just after midnight so it updates without opening the app.
    private static func scheduleBadges(occurrences: [EventOccurrence], now: Date, calendar: Calendar) async {
        let perDay = Dictionary(grouping: occurrences, by: { calendar.startOfDay(for: $0.date) }).mapValues(\.count)
        let today = calendar.startOfDay(for: now)
        try? await center.setBadgeCount(perDay[today] ?? 0)

        var changes: [(day: Date, count: Int)] = []
        for day in perDay.keys.sorted() where day > today {
            changes.append((day, perDay[day] ?? 0))
            // Clear the day after, unless that day has events of its own.
            if let next = calendar.date(byAdding: .day, value: 1, to: day), perDay[next] == nil { changes.append((next, 0)) }
        }
        for change in changes.prefix(18) {
            guard let fire = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: change.day), fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.badge = NSNumber(value: change.count)
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "badge|\(Int(change.day.timeIntervalSince1970))", content: content, trigger: trigger))
        }
    }

    /// Title names the person and the occasion; the body adds only what the title doesn't (age, timing) and the nudge.
    /// Fires a sample reminder a few seconds from now so the notification and its actions can be tried (Demo Mode).
    /// Returns false when notifications aren't allowed.
    static func sendTest(for contact: Contact, after seconds: TimeInterval = 5, calendar: Calendar = .current) async -> Bool {
        if await authorizationStatus() == .notDetermined { await requestAuthorization() }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return false }

        let event = contact.events.first(where: { $0.kind == .birthday }) ?? contact.events.first
            ?? ContactEvent(kind: .birthday, date: EventDate(month: 1, day: 1))
        let today = calendar.startOfDay(for: .now)
        let age = event.date.year.map { calendar.component(.year, from: today) - $0 }
        let o = EventOccurrence(contactID: contact.id, contactName: contact.shortName, event: event, date: today, years: (age ?? 0) > 0 ? age : nil)

        let content = UNMutableNotificationContent()
        content.title = title(for: o)
        content.body = body(for: o, lead: 0)
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = ["contactID": o.contactID, "eventKey": event.muteKey(contactID: o.contactID)]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger))
        return true
    }

    private static func title(for o: EventOccurrence) -> String {
        switch o.event.kind {
        case .birthday: "\(o.contactName)'s birthday"
        case .anniversary: "\(o.contactName)'s anniversary"
        case .other: "\(o.contactName): \(o.event.displayTitle)"
        }
    }

    private static func body(for o: EventOccurrence, lead: Int) -> String {
        let when = lead == 0 ? "today" : lead == 1 ? "tomorrow" : "in \(lead) days"
        let detail: String
        switch (o.event.kind, o.years) {
        case (.birthday, let y?): detail = "Turns \(y) \(when)"
        case (_, let y?): detail = "\(y) \(y == 1 ? "year" : "years") \(when)"
        default: detail = when.prefix(1).uppercased() + when.dropFirst()
        }
        return "\(detail) · Send wishes"
    }
}
