import Foundation

/// A calendar date that may or may not carry a year.
///
/// This mirrors the People API `Date` object exactly: a year-less date is
/// `{month, day}` with no `year` key. Apple Contacts instead stores such dates
/// with a placeholder year (1604), which is the interop problem this app avoids.
struct EventDate: Hashable, Codable, Sendable {
    var month: Int
    var day: Int
    var year: Int?

    var hasYear: Bool { year != nil }

    /// Apple's placeholder year for "no year" dates, and `0` which some clients send.
    private static let sentinelYears: Set<Int> = [0, 1604]

    init(month: Int, day: Int, year: Int? = nil) {
        self.month = month
        self.day = day
        self.year = year.flatMap { Self.sentinelYears.contains($0) ? nil : $0 }
    }

    /// Length of the month for picker bounds. Feb always allows 29 so year-less
    /// leap-day birthdays can be entered.
    func daysInMonth() -> Int {
        switch month {
        case 2: return (year.map(Self.isLeap) ?? true) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    /// Clamps `day` into the valid range for the current month/year.
    mutating func clamp() { day = min(max(day, 1), daysInMonth()) }

    /// The date this event falls on in `year`. Feb 29 falls back to Feb 28 in non-leap years.
    func date(inYear year: Int, calendar: Calendar = .current) -> Date? {
        var d = day
        if month == 2, d == 29, !Self.isLeap(year) { d = 28 }
        return calendar.date(from: DateComponents(year: year, month: month, day: d))
    }

    /// "20 October 1992" or "14 June".
    func formatted(calendar: Calendar = .current) -> String {
        let refYear = year ?? 2000 // a leap year, so 29 Feb always exists
        guard let date = calendar.date(from: DateComponents(year: refYear, month: month, day: day)) else { return "\(day)/\(month)" }
        var style = Date.FormatStyle(calendar: calendar).day().month(.wide)
        if hasYear { style = style.year() }
        return date.formatted(style)
    }

    /// Short month name, e.g. "Jun".
    var shortMonth: String {
        Calendar.current.shortMonthSymbols[(month - 1).clamped(0, 11)]
    }
}

extension Int {
    func clamped(_ lo: Int, _ hi: Int) -> Int { Swift.min(Swift.max(self, lo), hi) }
}
