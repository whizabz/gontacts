import Foundation
import Observation

/// User-facing reminder preferences, persisted in UserDefaults.
@MainActor @Observable
final class ReminderSettings {
    private let defaults = UserDefaults.standard

    var birthdays: Bool { didSet { defaults.set(birthdays, forKey: "rs.birthdays") } }
    var anniversaries: Bool { didSet { defaults.set(anniversaries, forKey: "rs.anniversaries") } }
    var otherDates: Bool { didSet { defaults.set(otherDates, forKey: "rs.other") } }
    var dayBefore: Bool { didSet { defaults.set(dayBefore, forKey: "rs.dayBefore") } }
    var weekBefore: Bool { didSet { defaults.set(weekBefore, forKey: "rs.weekBefore") } }
    /// Confetti when opening a contact with an event today. Also skipped when iOS Reduce Motion is on.
    var confetti: Bool { didSet { defaults.set(confetti, forKey: "rs.confetti") } }
    /// Minutes after midnight.
    var timeOfDay: Int { didSet { defaults.set(timeOfDay, forKey: "rs.time") } }
    var mutedIDs: Set<String> { didSet { defaults.set(Array(mutedIDs), forKey: "rs.muted") } }

    var timeAsDate: Date {
        get { Calendar.current.date(bySettingHour: timeOfDay / 60, minute: timeOfDay % 60, second: 0, of: .now) ?? .now }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            timeOfDay = (c.hour ?? 9) * 60 + (c.minute ?? 0)
        }
    }

    init() {
        let d = UserDefaults.standard
        func bool(_ key: String, _ fallback: Bool) -> Bool { d.object(forKey: key) as? Bool ?? fallback }
        birthdays = bool("rs.birthdays", true)
        anniversaries = bool("rs.anniversaries", true)
        otherDates = bool("rs.other", false)
        dayBefore = bool("rs.dayBefore", false)
        weekBefore = bool("rs.weekBefore", false)
        confetti = bool("rs.confetti", true)
        timeOfDay = d.object(forKey: "rs.time") as? Int ?? 9 * 60
        mutedIDs = Set(d.stringArray(forKey: "rs.muted") ?? [])
    }

    func isEnabled(_ kind: EventKind) -> Bool {
        switch kind {
        case .birthday: birthdays
        case .anniversary: anniversaries
        case .other: otherDates
        }
    }

    var leadDays: [Int] { [0] + (dayBefore ? [1] : []) + (weekBefore ? [7] : []) }
}
