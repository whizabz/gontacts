import Foundation

/// Sample contacts whose dates are relative to today, so the demo always has
/// something happening today (and confetti to show for it).
enum SampleData {
    static func contacts(today: Date = .now, calendar: Calendar = .current) -> [Contact] {
        let year = calendar.component(.year, from: today)

        func day(_ offset: Int, yearsAgo: Int? = nil) -> EventDate {
            let d = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
            let c = calendar.dateComponents([.month, .day], from: d)
            return EventDate(month: c.month!, day: c.day!, year: yearsAgo.map { year - $0 })
        }

        func person(_ given: String, _ family: String, org: String = "", title: String = "", phone: String? = nil, email: String? = nil, events: [ContactEvent] = []) -> Contact {
            var c = Contact(id: "people/sample-\(given.lowercased())-\(family.lowercased())")
            c.givenName = given
            c.familyName = family
            c.organization = org
            c.jobTitle = title
            if let phone { c.phones = [LabeledValue(label: "mobile", value: phone)] }
            if let email { c.emails = [LabeledValue(label: "work", value: email)] }
            c.events = events
            return c
        }

        func birthday(_ d: EventDate) -> ContactEvent { ContactEvent(kind: .birthday, date: d) }
        func anniversary(_ d: EventDate) -> ContactEvent { ContactEvent(kind: .anniversary, date: d) }
        func other(_ label: String, _ d: EventDate) -> ContactEvent { ContactEvent(kind: .other, label: label, date: d) }

        return [
            person("Aanya", "Kapoor", phone: "+1 415 555 0101", events: [birthday(day(8))]),
            person("Ben", "Okafor", org: "Northwind", phone: "+1 415 555 0102", events: [anniversary(day(-12, yearsAgo: 5))]),
            person("Carla", "Mendes", phone: "+1 415 555 0103", email: "carla@example.com", events: [anniversary(day(1, yearsAgo: 8))]),
            person("Daniel", "Park", org: "Orbit Labs", phone: "+1 415 555 0104", events: [anniversary(day(14, yearsAgo: 3))]),
            person("Elena", "Rossi", phone: "+39 06 555 0105", events: [other("Graduation", day(4))]),
            person("Farah", "Siddiqui", phone: "+1 415 555 0106", events: [birthday(day(-8))]),
            person("Greg", "Larsen", email: "greg@example.com", events: [birthday(day(3))]),
            person("Hana", "Ito", org: "Lumen Studio", title: "Product Designer", phone: "+81 90 5550 0142", email: "hana@lumen.example",
                   events: [birthday(day(0, yearsAgo: 34)), anniversary(EventDate(month: 6, day: 14))]),
            person("Ivan", "Petrov", phone: "+1 415 555 0108", events: [birthday(day(-1))]),
            person("Jasmine", "Cole", phone: "+1 415 555 0109", events: [birthday(day(19))]),
            person("Kenji", "Lee", phone: "+1 415 555 0110", events: [birthday(day(-25))]),
            person("Lena", "Martin", phone: "+33 1 55 50 01 11", events: [other("Graduation", day(-35))]),
            person("Priya", "Nair", phone: "+91 98 5550 0112", events: [anniversary(day(-24, yearsAgo: 2))]),
            person("Marcus", "Webb", org: "Webb & Sons", phone: "+1 415 555 0113"),
        ]
    }
}
