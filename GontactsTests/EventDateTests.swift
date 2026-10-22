import XCTest
@testable import Gontacts

final class EventDateTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 1
        return c
    }()

    func testApplePlaceholderYearIsTreatedAsNoYear() {
        XCTAssertNil(EventDate(month: 11, day: 26, year: 1604).year)
        XCTAssertNil(EventDate(month: 11, day: 26, year: 0).year)
        XCTAssertEqual(EventDate(month: 11, day: 26, year: 1992).year, 1992)
    }

    func testYearlessDateIsWrittenToGoogleWithoutYearKey() throws {
        var contact = Contact(id: "people/c1")
        contact.givenName = "Test"
        contact.events = [ContactEvent(kind: .birthday, date: EventDate(month: 11, day: 26))]
        let json = try JSONEncoder().encode(PersonDTO(contact: contact))
        let text = String(decoding: json, as: UTF8.self)
        XCTAssertTrue(text.contains("\"month\":11"))
        XCTAssertTrue(text.contains("\"day\":26"))
        XCTAssertFalse(text.contains("year"), "A year-less date must be sent as {month, day} only: \(text)")
    }

    func testGoogleBirthdayWithoutYearDecodesAsYearless() throws {
        let json = #"{"resourceName":"people/c1","etag":"x","names":[{"givenName":"A","familyName":"B"}],"birthdays":[{"date":{"month":11,"day":26}}],"events":[{"date":{"month":6,"day":14},"type":"anniversary"},{"date":{"year":2018,"month":5,"day":2},"type":"Graduation","formattedType":"Graduation"}]}"#
        let contact = try XCTUnwrap(JSONDecoder().decode(PersonDTO.self, from: Data(json.utf8)).toContact())
        XCTAssertEqual(contact.events.count, 3)
        XCTAssertEqual(contact.events[0].kind, .birthday)
        XCTAssertFalse(contact.events[0].date.hasYear)
        XCTAssertEqual(contact.events[1].kind, .anniversary)
        XCTAssertEqual(contact.events[2].kind, .other)
        XCTAssertEqual(contact.events[2].label, "Graduation")
        XCTAssertEqual(contact.events[2].date.year, 2018)
    }

    func testLeapDayFallsBackToFeb28InCommonYears() {
        let d = EventDate(month: 2, day: 29)
        let common = d.date(inYear: 2027, calendar: calendar)!
        XCTAssertEqual(calendar.component(.day, from: common), 28)
        let leap = d.date(inYear: 2028, calendar: calendar)!
        XCTAssertEqual(calendar.component(.day, from: leap), 29)
    }

    func testTimelineGroupsTodayTomorrowAndMonths() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))! // Tuesday
        func contact(_ name: String, offset: Int, year: Int? = nil) -> Contact {
            let d = calendar.date(byAdding: .day, value: offset, to: today)!
            let c = calendar.dateComponents([.month, .day], from: d)
            var p = Contact(id: "people/\(name)")
            p.givenName = name
            p.events = [ContactEvent(kind: .birthday, date: EventDate(month: c.month!, day: c.day!, year: year))]
            return p
        }
        let contacts = [contact("Yesterday", offset: -1), contact("Today", offset: 0, year: 1992), contact("Tomorrow", offset: 1), contact("Friday", offset: 3), contact("Nov", offset: 20), contact("Earlier", offset: -30), contact("EarlierOct", offset: -5), contact("LaterOct", offset: 8)]
        let all = EventTimeline.occurrences(for: contacts, from: calendar.date(byAdding: .month, value: -12, to: today)!, to: calendar.date(byAdding: .month, value: 12, to: today)!, calendar: calendar)
        let sections = EventTimeline.sections(from: all, today: today, calendar: calendar)
        let ids = sections.map(\.id)

        XCTAssertEqual(ids.firstIndex(of: "yesterday")! + 1, ids.firstIndex(of: "today")!)
        XCTAssertEqual(ids.firstIndex(of: "today")! + 1, ids.firstIndex(of: "tomorrow")!)
        XCTAssertTrue(ids.contains("week"))
        XCTAssertTrue(ids.contains("m2026-11"))
        XCTAssertTrue(ids.contains("p2026-9"))
        XCTAssertEqual(ids.count, Set(ids).count, "Section ids must be unique")
        XCTAssertEqual(EventTimeline.anchorID(in: sections), "today")
        XCTAssertEqual(sections.first { $0.id == "today" }?.occurrences.first?.years, 34)
    }

    func testExtraGoogleFieldsRoundTripWithoutLoss() throws {
        let json = #"{"resourceName":"people/c9","etag":"e","names":[{"honorificPrefix":"Dr","givenName":"Ada","middleName":"Byron","familyName":"King","honorificSuffix":"PhD"}],"nicknames":[{"value":"Countess"}],"addresses":[{"type":"home","streetAddress":"1 Main St","extendedAddress":"Apt 2","poBox":"PO 7","city":"London","region":"LDN","postalCode":"N1","country":"UK"}],"urls":[{"value":"https://example.com","type":"blog"}],"relations":[{"person":"Charles","type":"friend"}]}"#
        let contact = try XCTUnwrap(JSONDecoder().decode(PersonDTO.self, from: Data(json.utf8)).toContact())
        XCTAssertEqual(contact.middleName, "Byron")
        XCTAssertEqual(contact.namePrefix, "Dr")
        XCTAssertEqual(contact.nickname, "Countess")
        XCTAssertEqual(contact.addresses.first?.poBox, "PO 7")
        XCTAssertEqual(contact.relations.first?.value, "Charles")

        let back = PersonDTO(contact: contact)
        XCTAssertEqual(back.names?.first?.middleName, "Byron")
        XCTAssertEqual(back.names?.first?.honorificSuffix, "PhD")
        XCTAssertEqual(back.addresses?.first?.extendedAddress, "Apt 2")
        XCTAssertEqual(back.addresses?.first?.poBox, "PO 7")
        XCTAssertEqual(back.urls?.first?.type, "blog")
        XCTAssertEqual(back.relations?.first?.person, "Charles")
    }

    func testOlderCachedContactsStillDecode() throws {
        let old = #"{"id":"people/c1","givenName":"Old","familyName":"Cache","phones":[],"emails":[],"events":[],"notes":""}"#
        let c = try JSONDecoder().decode(Contact.self, from: Data(old.utf8))
        XCTAssertEqual(c.givenName, "Old")
        XCTAssertTrue(c.addresses.isEmpty)
    }

    func testNewFieldsRoundTripAndUpdatesOnlySendChangedGroups() throws {
        let json = #"{"resourceName":"people/c5","etag":"e","names":[{"givenName":"Ada","familyName":"King","phoneticGivenName":"AY-da"}],"organizations":[{"name":"Acme","title":"CEO","department":"Ops"},{"name":"Side Co","title":"Advisor"}],"imClients":[{"username":"ada","protocol":"WhatsApp"}],"userDefined":[{"key":"Pronouns","value":"she/her"}],"phoneNumbers":[{"value":"+44 20 7946 0000","type":"mobile"}]}"#
        let original = try XCTUnwrap(JSONDecoder().decode(PersonDTO.self, from: Data(json.utf8)).toContact())
        XCTAssertEqual(original.department, "Ops")
        XCTAssertEqual(original.phoneticGivenName, "AY-da")
        XCTAssertEqual(original.otherOrganizations.first?.name, "Side Co")
        XCTAssertEqual(original.ims.first?.label, "WhatsApp")
        XCTAssertEqual(original.customFields.first?.label, "Pronouns")

        XCTAssertEqual(original.changedGoogleFields(from: original), [])

        var edited = original
        edited.phones[0].value = "+44 20 7946 1111"
        XCTAssertEqual(edited.changedGoogleFields(from: original), ["phoneNumbers"])

        edited.department = "Engineering"
        XCTAssertEqual(Set(edited.changedGoogleFields(from: original)), ["phoneNumbers", "organizations"])

        // Editing the primary organization must not drop the second one.
        let body = PersonDTO(contact: edited)
        XCTAssertEqual(body.organizations?.count, 2)
        XCTAssertEqual(body.organizations?.first?.department, "Engineering")
        XCTAssertEqual(body.names?.first?.phoneticGivenName, "AY-da")
    }
}

final class PendingEditTests: XCTestCase {
    func testApplyingOnlyTakesTheListedFieldGroups() {
        var server = Contact(id: "people/c1")
        server.givenName = "Ada"
        server.phones = [LabeledValue(label: "mobile", value: "111")]
        server.notes = "from Google"

        var edited = server
        edited.givenName = "Grace"
        edited.phones = [LabeledValue(label: "mobile", value: "222")]
        edited.notes = "edited"

        let result = server.applying(fields: ["phoneNumbers"], from: edited)
        XCTAssertEqual(result.phones.first?.value, "222")
        XCTAssertEqual(result.givenName, "Ada")
        XCTAssertEqual(result.notes, "from Google")
    }
}
