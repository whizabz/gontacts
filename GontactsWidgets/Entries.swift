import SwiftUI
import WidgetKit

/// One birthday or anniversary, ready to draw.
struct CelebrationRow: Identifiable, Hashable {
    let id: String
    let contactID: String
    let name: String
    let initials: String
    let kind: EventKind
    let years: Int?
    let date: Date
    let photoPath: String?
    let seed: Int

    var symbol: String { kind == .anniversary ? "wineglass" : "birthday.cake" }
    var symbolColor: Color { kind == .anniversary ? Theme.glass : Theme.cake }

    /// "Turns 34", "5 years", or just the kind when the year isn't known.
    var short: String {
        switch (kind, years) {
        case (.birthday, let y?): "Turns \(y)"
        case (_, let y?): "\(y) \(y == 1 ? "year" : "years")"
        case (.anniversary, nil): "Anniversary"
        default: "Birthday"
        }
    }

    /// "Birthday · turns 34", "Anniversary · 5 years".
    var long: String {
        switch (kind, years) {
        case (.birthday, let y?): "Birthday · turns \(y)"
        case (.anniversary, let y?): "Anniversary · \(y) \(y == 1 ? "year" : "years")"
        case (.anniversary, nil): "Anniversary"
        default: "Birthday"
        }
    }

    var url: URL { WidgetStore.openURL(for: contactID) }
}

struct CelebrationEntry: TimelineEntry {
    let date: Date
    /// From the entry's day onward, soonest first.
    let rows: [CelebrationRow]

    private var today: Date { Calendar.current.startOfDay(for: date) }

    func days(until row: CelebrationRow) -> Int {
        Calendar.current.dateComponents([.day], from: today, to: row.date).day ?? 0
    }

    var todayRows: [CelebrationRow] { rows.filter { days(until: $0) == 0 } }
    var upcomingRows: [CelebrationRow] { rows.filter { days(until: $0) > 0 } }

    func when(_ row: CelebrationRow) -> String {
        switch days(until: row) {
        case 0: "Today"
        case 1: "Tomorrow"
        case let d: "In \(d) days"
        }
    }
}

struct CelebrationProvider: TimelineProvider {
    func placeholder(in context: Context) -> CelebrationEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (CelebrationEntry) -> Void) {
        let entries = Self.entries(from: .now)
        completion(context.isPreview || entries.first?.rows.isEmpty != false ? .sample : entries[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CelebrationEntry>) -> Void) {
        let entries = Self.entries(from: .now)
        let start = Calendar.current.startOfDay(for: .now)
        let refresh = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    /// One entry per day for a week, so the widget moves on at midnight without the app running.
    static func entries(from now: Date) -> [CelebrationEntry] {
        let cal = Calendar.current
        let contacts = WidgetStore.read()
        let byID = Dictionary(contacts.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 21, to: start) else { return [] }

        let all = EventTimeline.occurrences(for: contacts, from: start, to: end, calendar: cal)
            .filter { $0.event.kind != .other }
            .map { o -> CelebrationRow in
                let c = byID[o.contactID]
                let seed = o.contactID.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
                return CelebrationRow(id: o.id, contactID: o.contactID, name: o.contactName, initials: c?.initials ?? "?",
                                      kind: o.event.kind, years: o.years, date: o.date,
                                      photoPath: WidgetStore.photoPath(for: o.contactID), seed: seed)
            }

        return (0..<7).compactMap { i in
            guard let day = cal.date(byAdding: .day, value: i, to: start), let limit = cal.date(byAdding: .day, value: 14, to: day) else { return nil }
            return CelebrationEntry(date: i == 0 ? now : day, rows: all.filter { $0.date >= day && $0.date < limit })
        }
    }
}

extension CelebrationEntry {
    /// What the widget gallery and placeholders show.
    static var sample: CelebrationEntry {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: today) ?? today }
        func row(_ id: String, _ name: String, _ initials: String, _ kind: EventKind, _ years: Int?, _ offset: Int, _ seed: Int) -> CelebrationRow {
            CelebrationRow(id: id, contactID: id, name: name, initials: initials, kind: kind, years: years, date: day(offset), photoPath: nil, seed: seed)
        }
        return CelebrationEntry(date: .now, rows: [
            row("a", "Hana Ito", "HI", .birthday, 34, 0, 0),
            row("b", "Maya Ortiz", "MO", .birthday, nil, 1, 1),
            row("c", "Dev & Priya", "DP", .anniversary, 5, 3, 3),
            row("d", "Lena Fischer", "LF", .birthday, 41, 4, 4),
            row("e", "Omar Haddad", "OH", .birthday, nil, 6, 2),
        ])
    }
}
