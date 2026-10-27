import Foundation

/// Sample contacts whose dates are relative to today, so the demo always has
/// something happening today (and confetti to show for it).
enum SampleData {
    /// The sample contact shown as My Card in demo mode.
    static let myCardID = "people/sample-alex-morgan"

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

        var me = person("Alex", "Morgan", org: "Fieldwork Design", title: "Design Director", phone: "+1 415 555 0199", email: "alex@fieldwork.example",
                        events: [birthday(day(41, yearsAgo: 36))])
        me.nickname = "Lex"
        me.phones.append(LabeledValue(label: "work", value: "+1 415 555 0123"))
        me.emails.append(LabeledValue(label: "home", value: "alex.morgan@example.com"))
        me.addresses = [PostalAddress(label: "home", street: "48 Harbour Street", city: "San Francisco", region: "CA", postalCode: "94107", country: "USA")]
        me.urls = [LabeledValue(label: "website", value: "https://alexmorgan.example"), LabeledValue(label: "LinkedIn", value: "https://linkedin.com/in/alexmorgan")]

        return [
            me,
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
            // More people, several under the same letter, with a few dates sprinkled in.
            person("Aaron", "Blake", org: "Northwind", phone: "+1 415 555 0114"),
            person("Amelia", "Cruz", phone: "+1 415 555 0115", email: "amelia@example.com", events: [birthday(day(27, yearsAgo: 29))]),
            person("Abdul", "Rahman", phone: "+44 20 5550 0116"),
            person("Beatriz", "Santos", phone: "+55 11 55550 0117", events: [birthday(day(-6, yearsAgo: 31))]),
            person("Bruno", "Weber", org: "Orbit Labs", phone: "+49 30 5550 0118"),
            person("Bella", "Nguyen", phone: "+1 415 555 0119", email: "bella@example.com"),
            person("Chloe", "Dubois", phone: "+33 1 55 50 01 20", events: [anniversary(day(9, yearsAgo: 6))]),
            person("Caleb", "Foster", org: "Foster & Co", phone: "+1 415 555 0121"),
            person("Dev", "Malhotra", phone: "+91 98 5550 0122", events: [birthday(day(12, yearsAgo: 33))]),
            person("Diana", "Ivanova", phone: "+7 495 555 0123"),
            person("Dmitri", "Volkov", phone: "+1 415 555 0124"),
            person("Emma", "Johansson", org: "Lumen Studio", title: "Art Director", phone: "+46 8 555 0125", email: "emma@lumen.example"),
            person("Ethan", "Brooks", phone: "+1 415 555 0126", events: [other("Moved to Austin", day(-18))]),
            person("Fatima", "Zahra", phone: "+971 4 555 0127"),
            person("Felix", "Baumann", phone: "+41 44 555 0128", events: [birthday(day(33, yearsAgo: 40))]),
            person("Grace", "Okoye", org: "Northwind", title: "Engineer", phone: "+234 1 555 0129"),
            person("Gabriel", "Torres", phone: "+34 91 555 0130", events: [anniversary(day(-3, yearsAgo: 10))]),
            person("Hugo", "Lambert", phone: "+33 1 55 50 01 31"),
            person("Harper", "Reid", phone: "+1 415 555 0132", email: "harper@example.com"),
            person("Isla", "Fraser", phone: "+44 131 555 0133", events: [birthday(day(6, yearsAgo: 27))]),
            person("Idris", "Karim", phone: "+1 415 555 0134"),
            person("Jonas", "Berg", org: "Orbit Labs", phone: "+47 22 55 01 35"),
            person("Julia", "Costa", phone: "+351 21 555 0136", events: [other("Wedding", day(21, yearsAgo: 1))]),
            person("Kavya", "Menon", phone: "+91 98 5550 0137"),
            person("Kofi", "Mensah", phone: "+233 30 555 0138", events: [birthday(day(-14, yearsAgo: 35))]),
            person("Leo", "Fischer", phone: "+49 89 5550 0139"),
            person("Layla", "Hassan", phone: "+20 2 5550 0140", events: [anniversary(day(16, yearsAgo: 4))]),
            person("Mia", "Andersen", phone: "+45 33 55 01 41"),
            person("Mateo", "Silva", phone: "+54 11 5550 0142", events: [birthday(day(2, yearsAgo: 30))]),
            person("Nina", "Kowalski", phone: "+48 22 555 0143"),
            person("Noah", "Bennett", org: "Webb & Sons", phone: "+1 415 555 0144"),
            person("Olivia", "Grant", phone: "+1 415 555 0145", events: [birthday(day(-30, yearsAgo: 28))]),
            person("Omar", "Haddad", phone: "+962 6 555 0146"),
            person("Peter", "Novak", phone: "+420 2 5550 0147"),
            person("Quinn", "Adler", phone: "+1 415 555 0148"),
            person("Rohan", "Desai", org: "Lumen Studio", phone: "+91 98 5550 0149", events: [birthday(day(11, yearsAgo: 32))]),
            person("Rosa", "Alvarez", phone: "+52 55 5550 0150"),
            person("Sofia", "Marino", phone: "+39 06 555 0151", events: [anniversary(day(-9, yearsAgo: 7))]),
            person("Sam", "Whitfield", phone: "+1 415 555 0152"),
            person("Tara", "Singh", phone: "+91 98 5550 0153", events: [birthday(day(5, yearsAgo: 26))]),
            person("Tomas", "Eriksson", phone: "+46 8 555 0154"),
            person("Uma", "Patel", phone: "+1 415 555 0155"),
            person("Victor", "Hugo", phone: "+33 1 55 50 01 56"),
            person("Vera", "Lindqvist", phone: "+46 8 555 0157", events: [other("Retirement", day(24))]),
            person("Wendy", "Chu", phone: "+852 2555 0158"),
            person("Yusuf", "Demir", phone: "+90 212 555 0159", events: [birthday(day(-20, yearsAgo: 37))]),
            person("Zara", "Quinn", phone: "+1 415 555 0160", email: "zara@example.com"),
            person("Zoe", "Papadakis", phone: "+30 21 5550 0161", events: [anniversary(day(30, yearsAgo: 9))]),
        ]
    }

    /// Sample contacts that were saved on an earlier day, with every sample date moved back to "today" terms: Hana
    /// Ito's birthday is today, the others fall around it. Names, numbers and contacts you added are left alone, and
    /// sample contacts you deleted stay deleted, except Hana, who is always there so the birthday can be demoed.
    static func refreshed(_ saved: [Contact], today: Date = .now, calendar: Calendar = .current) -> [Contact] {
        let fresh = Dictionary(uniqueKeysWithValues: contacts(today: today, calendar: calendar).map { ($0.id, $0) })
        var result = saved.map { c -> Contact in
            guard let f = fresh[c.id] else { return c }
            var updated = c
            updated.events = f.events
            return updated
        }
        for id in ["people/sample-hana-ito", myCardID] {
            if let sample = fresh[id], !result.contains(where: { $0.id == id }) { result.append(sample) }
        }
        return result
    }
}
