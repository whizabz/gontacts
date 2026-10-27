import Foundation
import UserNotifications

/// Schedules local notifications from synced contact dates. iOS allows 64 pending
/// requests, so we schedule the soonest ones and refresh whenever data or settings change.
@MainActor
enum ReminderScheduler {
    static let center = UNUserNotificationCenter.current()
    static let wishAction = "WISH"
    static let category = "EVENT"

    static func registerCategories() {
        let wish = UNNotificationAction(identifier: wishAction, title: "Wish", options: [.foreground])
        center.setNotificationCategories([UNNotificationCategory(identifier: category, actions: [wish], intentIdentifiers: [])])
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
            .filter { settings.isEnabled($0.event.kind) }

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
                content.userInfo = ["contactID": o.contactID]
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                requests.append((fire, UNNotificationRequest(identifier: "\(o.id)|\(lead)", content: content, trigger: trigger)))
            }
        }
        for item in requests.sorted(by: { $0.fire < $1.fire }).prefix(60) {
            try? await center.add(item.request)
        }
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
        switch (o.event.kind, o.years) {
        case (.birthday, let y?): return "Turns \(y) \(when). Send wishes?"
        case (.anniversary, let y?): return "\(y) \(y == 1 ? "year" : "years") \(when). Send wishes?"
        default: return "\(o.event.displayTitle) \(when). Send wishes?"
        }
    }
}
