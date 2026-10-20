import Foundation

// MARK: - Wire format (Google People API v1)

struct PersonDTO: Codable {
    struct Name: Codable {
        var honorificPrefix: String?
        var givenName: String?
        var middleName: String?
        var familyName: String?
        var honorificSuffix: String?
    }
    struct Field: Codable { var value: String?; var type: String?; var formattedType: String? }
    struct Nickname: Codable { var value: String? }
    struct Address: Codable {
        var type: String?
        var formattedType: String?
        var streetAddress: String?
        var extendedAddress: String?
        var poBox: String?
        var city: String?
        var region: String?
        var postalCode: String?
        var country: String?
    }
    struct Relation: Codable { var person: String?; var type: String?; var formattedType: String? }
    struct Org: Codable { var name: String?; var title: String? }
    struct DateDTO: Codable { var year: Int?; var month: Int?; var day: Int? }
    struct Birthday: Codable { var date: DateDTO? }
    struct Event: Codable { var date: DateDTO?; var type: String?; var formattedType: String? }
    struct Photo: Codable { var url: String?; var `default`: Bool? }

    var resourceName: String?
    var etag: String?
    var names: [Name]?
    var nicknames: [Nickname]?
    var phoneNumbers: [Field]?
    var emailAddresses: [Field]?
    var addresses: [Address]?
    var urls: [Field]?
    var relations: [Relation]?
    var organizations: [Org]?
    var birthdays: [Birthday]?
    var events: [Event]?
    var biographies: [Field]?
    var photos: [Photo]?
}

extension PersonDTO {
    static let readFields = "names,nicknames,phoneNumbers,emailAddresses,addresses,urls,relations,organizations,birthdays,events,biographies,photos"
    /// Every field in this mask is replaced wholesale on update, so each must be fully round-tripped in `toContact`/`init(contact:)`.
    static let writeFields = "names,nicknames,phoneNumbers,emailAddresses,addresses,urls,relations,organizations,birthdays,events,biographies"

    func toContact() -> Contact? {
        guard let resourceName else { return nil }
        var c = Contact(id: resourceName)
        c.etag = etag
        if let n = names?.first {
            c.namePrefix = n.honorificPrefix ?? ""
            c.givenName = n.givenName ?? ""
            c.middleName = n.middleName ?? ""
            c.familyName = n.familyName ?? ""
            c.nameSuffix = n.honorificSuffix ?? ""
        }
        c.nickname = nicknames?.first?.value ?? ""
        c.organization = organizations?.first?.name ?? ""
        c.jobTitle = organizations?.first?.title ?? ""
        c.phones = (phoneNumbers ?? []).compactMap { f in f.value.map { LabeledValue(label: f.type ?? f.formattedType ?? "other", value: $0) } }
        c.emails = (emailAddresses ?? []).compactMap { f in f.value.map { LabeledValue(label: f.type ?? f.formattedType ?? "other", value: $0) } }
        c.urls = (urls ?? []).compactMap { f in f.value.map { LabeledValue(label: f.type ?? f.formattedType ?? "other", value: $0) } }
        c.relations = (relations ?? []).compactMap { r in r.person.map { LabeledValue(label: r.type ?? r.formattedType ?? "other", value: $0) } }
        c.addresses = (addresses ?? []).map { a in
            PostalAddress(label: a.type ?? a.formattedType ?? "other", street: a.streetAddress ?? "", city: a.city ?? "", region: a.region ?? "",
                          postalCode: a.postalCode ?? "", country: a.country ?? "", extendedAddress: a.extendedAddress ?? "", poBox: a.poBox ?? "")
        }
        c.notes = biographies?.first?.value ?? ""
        c.photoURL = photos?.first(where: { $0.default != true })?.url.flatMap(URL.init(string:))

        var events: [ContactEvent] = (birthdays ?? []).compactMap { b in
            guard let d = b.date?.eventDate else { return nil }
            return ContactEvent(kind: .birthday, date: d)
        }
        for e in self.events ?? [] {
            guard let d = e.date?.eventDate else { continue }
            let type = (e.type ?? "other")
            if type.lowercased() == "anniversary" {
                events.append(ContactEvent(kind: .anniversary, date: d))
            } else {
                let label = type.lowercased() == "other" ? "" : (e.formattedType ?? type)
                events.append(ContactEvent(kind: .other, label: label, date: d))
            }
        }
        c.events = events
        return c
    }

    init(contact c: Contact) {
        func empty(_ s: String) -> String? { s.isEmpty ? nil : s }
        resourceName = c.isNew ? nil : c.id
        etag = c.etag
        names = [Name(honorificPrefix: empty(c.namePrefix), givenName: c.givenName, middleName: empty(c.middleName),
                      familyName: c.familyName, honorificSuffix: empty(c.nameSuffix))]
        nicknames = c.nickname.isEmpty ? [] : [Nickname(value: c.nickname)]
        phoneNumbers = c.phones.filter { !$0.value.isEmpty }.map { Field(value: $0.value, type: $0.label) }
        emailAddresses = c.emails.filter { !$0.value.isEmpty }.map { Field(value: $0.value, type: $0.label) }
        urls = c.urls.filter { !$0.value.isEmpty }.map { Field(value: $0.value, type: $0.label) }
        relations = c.relations.filter { !$0.value.isEmpty }.map { Relation(person: $0.value, type: $0.label) }
        addresses = c.addresses.filter { !$0.isEmpty }.map { a in
            Address(type: a.label, streetAddress: empty(a.street), extendedAddress: empty(a.extendedAddress), poBox: empty(a.poBox),
                    city: empty(a.city), region: empty(a.region), postalCode: empty(a.postalCode), country: empty(a.country))
        }
        organizations = (c.organization.isEmpty && c.jobTitle.isEmpty) ? [] : [Org(name: c.organization, title: c.jobTitle)]
        biographies = c.notes.isEmpty ? [] : [Field(value: c.notes)]
        // Year-less dates are written as {month, day} only: Google's own representation.
        birthdays = c.events.filter { $0.kind == .birthday }.map { Birthday(date: DateDTO(eventDate: $0.date)) }
        events = c.events.filter { $0.kind != .birthday }.map { e in
            let type: String
            switch e.kind {
            case .anniversary: type = "anniversary"
            default: type = e.label.trimmingCharacters(in: .whitespaces).isEmpty ? "other" : e.label
            }
            return Event(date: DateDTO(eventDate: e.date), type: type)
        }
    }
}

extension PersonDTO.DateDTO {
    var eventDate: EventDate? {
        guard let month, let day, (1...12).contains(month), (1...31).contains(day) else { return nil }
        return EventDate(month: month, day: day, year: year)
    }

    init(eventDate d: EventDate) {
        self.init(year: d.year, month: d.month, day: d.day)
    }
}
