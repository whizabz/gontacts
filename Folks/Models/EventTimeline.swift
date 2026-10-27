import Foundation

struct EventOccurrence: Identifiable, Hashable {
    let contactID: String
    let contactName: String
    let event: ContactEvent
    /// Start of the day this occurrence falls on.
    let date: Date
    /// Age or years, when the event has a year.
    let years: Int?

    var id: String { "\(contactID)|\(event.id)|\(date.timeIntervalSince1970)" }

    var detail: String {
        switch (event.kind, years) {
        case (.birthday, let y?): "Birthday · turns \(y)"
        case (.anniversary, let y?): "Anniversary · \(y) \(y == 1 ? "year" : "years")"
        case (_, let y?): "\(event.displayTitle) · \(y) \(y == 1 ? "year" : "years")"
        default: event.displayTitle
        }
    }
}

struct EventSection: Identifiable {
    enum Role { case past, today, future }
    let id: String
    let title: String
    let trailing: String?
    let role: Role
    let occurrences: [EventOccurrence]
}

enum EventTimeline {
    /// Every occurrence between `start` and `end` (inclusive), sorted by date then name.
    static func occurrences(for contacts: [Contact], from start: Date, to end: Date, calendar: Calendar = .current) -> [EventOccurrence] {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let years = calendar.component(.year, from: startDay)...calendar.component(.year, from: endDay)
        var result: [EventOccurrence] = []
        for contact in contacts {
            for event in contact.events {
                for year in years {
                    guard let date = event.date.date(inYear: year, calendar: calendar), date >= startDay, date <= endDay else { continue }
                    let age = event.date.year.map { year - $0 }
                    result.append(EventOccurrence(contactID: contact.id, contactName: contact.displayName, event: event, date: date, years: (age ?? 0) > 0 ? age : nil))
                }
            }
        }
        return result.sorted { ($0.date, $0.contactName) < ($1.date, $1.contactName) }
    }

    /// Events happening on the given day for one contact.
    static func events(on day: Date, for contact: Contact, calendar: Calendar = .current) -> [EventOccurrence] {
        occurrences(for: [contact], from: day, to: day, calendar: calendar)
    }

    /// Groups a flat, sorted list into Yesterday / Today / Tomorrow / This week / month sections.
    static func sections(from occurrences: [EventOccurrence], today: Date, calendar: Calendar = .current) -> [EventSection] {
        let todayStart = calendar.startOfDay(for: today)
        let monthTitle = Date.FormatStyle(calendar: calendar).month(.wide).year()
        let dayTitle = Date.FormatStyle(calendar: calendar).weekday(.abbreviated).day().month(.abbreviated)

        struct Key: Hashable { let order: Int; let id: String; let title: String; let role: EventSection.Role }
        var buckets: [Key: [EventOccurrence]] = [:]

        for o in occurrences {
            let diff = calendar.dateComponents([.day], from: todayStart, to: o.date).day ?? 0
            let sameMonth = calendar.isDate(o.date, equalTo: todayStart, toGranularity: .month)
            let monthName = o.date.formatted(Date.FormatStyle(calendar: calendar).month(.wide))
            let key: Key
            switch diff {
            case -1:
                key = Key(order: -1, id: "yesterday", title: "Yesterday · \(o.date.formatted(dayTitle))", role: .past)
            case 0:
                key = Key(order: 0, id: "today", title: "Today · \(o.date.formatted(dayTitle))", role: .today)
            case 1:
                key = Key(order: 1, id: "tomorrow", title: "Tomorrow · \(o.date.formatted(dayTitle))", role: .future)
            case 2... where calendar.isDate(o.date, equalTo: todayStart, toGranularity: .weekOfYear):
                key = Key(order: 2, id: "week", title: "This week", role: .future)
            case ..<(-1):
                let id = "p\(calendar.component(.year, from: o.date))-\(calendar.component(.month, from: o.date))"
                let order = -1_000_000 + (calendar.component(.year, from: o.date) * 12 + calendar.component(.month, from: o.date))
                key = Key(order: order, id: id, title: sameMonth ? "\(monthName) · so far" : o.date.formatted(monthTitle), role: .past)
            default:
                let id = "m\(calendar.component(.year, from: o.date))-\(calendar.component(.month, from: o.date))"
                let order = 1_000 + (calendar.component(.year, from: o.date) * 12 + calendar.component(.month, from: o.date))
                key = Key(order: order, id: id, title: sameMonth ? "Later in \(monthName)" : o.date.formatted(monthTitle), role: .future)
            }
            buckets[key, default: []].append(o)
        }

        return buckets.keys.sorted { $0.order < $1.order }.map { key in
            let items = buckets[key] ?? []
            let showCount = key.id == "week" || key.id.hasPrefix("m") || key.id.hasPrefix("p")
            return EventSection(id: key.id, title: key.title, trailing: showCount ? "\(items.count) \(items.count == 1 ? "event" : "events")" : nil, role: key.role, occurrences: items)
        }
    }

    /// The section to land on: today's, or the first one after today.
    static func anchorID(in sections: [EventSection]) -> String? {
        sections.first(where: { $0.role != .past })?.id ?? sections.last?.id
    }
}
