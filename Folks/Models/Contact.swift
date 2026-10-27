import Foundation

enum EventKind: String, Codable, CaseIterable, Sendable {
    case birthday, anniversary, other

    var title: String {
        switch self {
        case .birthday: "Birthday"
        case .anniversary: "Anniversary"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .birthday: "birthday.cake"
        case .anniversary: "wineglass"
        case .other: "star"
        }
    }
}

struct LabeledValue: Hashable, Codable, Identifiable, Sendable {
    var id = UUID()
    var label: String
    var value: String
}

struct PostalAddress: Hashable, Codable, Identifiable, Sendable {
    var id = UUID()
    var label: String = "home"
    var street = ""
    var city = ""
    var region = ""
    var postalCode = ""
    var country = ""
    /// Sub-fields we don't edit but must send back so an update doesn't erase them.
    var extendedAddress = ""
    var poBox = ""

    var isEmpty: Bool { [street, city, region, postalCode, country, extendedAddress, poBox].allSatisfy { $0.isEmpty } }

    /// Multi-line text for display.
    var formatted: String {
        let cityLine = [city, region, postalCode].filter { !$0.isEmpty }.joined(separator: " ")
        return [poBox, street, extendedAddress, cityLine, country].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

/// An additional organization beyond the primary one. Not editable in the app, but kept so editing the
/// primary organization never drops the others.
struct OrganizationEntry: Hashable, Codable, Sendable {
    var name = ""
    var title = ""
    var department = ""
}

struct ContactEvent: Hashable, Codable, Identifiable, Sendable {
    var id = UUID()
    var kind: EventKind
    /// Custom label for `.other` events, e.g. "Graduation".
    var label: String = ""
    var date: EventDate

    var displayTitle: String {
        if kind == .other, !label.trimmingCharacters(in: .whitespaces).isEmpty { return label }
        return kind.title
    }
}

struct Contact: Hashable, Codable, Identifiable, Sendable {
    /// People API resource name, e.g. "people/c123". New, unsaved contacts use "new-<uuid>".
    var id: String
    var etag: String?

    var namePrefix = ""
    var givenName = ""
    var middleName = ""
    var familyName = ""
    var nameSuffix = ""
    var nickname = ""
    var phoneticGivenName = ""
    var phoneticMiddleName = ""
    var phoneticFamilyName = ""
    var organization = ""
    var department = ""
    var jobTitle = ""
    var otherOrganizations: [OrganizationEntry] = []

    var phones: [LabeledValue] = []
    var emails: [LabeledValue] = []
    var addresses: [PostalAddress] = []
    var urls: [LabeledValue] = []
    /// Related people: `label` is the relationship ("spouse", "friend"), `value` the person's name.
    var relations: [LabeledValue] = []
    /// Chat and social handles: `label` is the service ("WhatsApp"), `value` the username.
    var ims: [LabeledValue] = []
    /// Google "custom fields": `label` is the field name, `value` its content.
    var customFields: [LabeledValue] = []
    var events: [ContactEvent] = []
    var notes = ""
    var photoURL: URL?
    /// When the contact was last changed (Google's update time, or now after a local edit).
    var modified: Date?

    // Fields added later; decode leniently so older cached data still loads.
    init(id: String) { self.id = id }

    enum CodingKeys: String, CodingKey {
        case id, etag, namePrefix, givenName, middleName, familyName, nameSuffix, nickname, organization, jobTitle
        case phoneticGivenName, phoneticMiddleName, phoneticFamilyName, department, otherOrganizations
        case phones, emails, addresses, urls, relations, ims, customFields, events, notes, photoURL, modified
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        etag = try c.decodeIfPresent(String.self, forKey: .etag)
        namePrefix = try c.decodeIfPresent(String.self, forKey: .namePrefix) ?? ""
        givenName = try c.decodeIfPresent(String.self, forKey: .givenName) ?? ""
        middleName = try c.decodeIfPresent(String.self, forKey: .middleName) ?? ""
        familyName = try c.decodeIfPresent(String.self, forKey: .familyName) ?? ""
        nameSuffix = try c.decodeIfPresent(String.self, forKey: .nameSuffix) ?? ""
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        organization = try c.decodeIfPresent(String.self, forKey: .organization) ?? ""
        jobTitle = try c.decodeIfPresent(String.self, forKey: .jobTitle) ?? ""
        phoneticGivenName = try c.decodeIfPresent(String.self, forKey: .phoneticGivenName) ?? ""
        phoneticMiddleName = try c.decodeIfPresent(String.self, forKey: .phoneticMiddleName) ?? ""
        phoneticFamilyName = try c.decodeIfPresent(String.self, forKey: .phoneticFamilyName) ?? ""
        department = try c.decodeIfPresent(String.self, forKey: .department) ?? ""
        otherOrganizations = try c.decodeIfPresent([OrganizationEntry].self, forKey: .otherOrganizations) ?? []
        ims = try c.decodeIfPresent([LabeledValue].self, forKey: .ims) ?? []
        customFields = try c.decodeIfPresent([LabeledValue].self, forKey: .customFields) ?? []
        phones = try c.decodeIfPresent([LabeledValue].self, forKey: .phones) ?? []
        emails = try c.decodeIfPresent([LabeledValue].self, forKey: .emails) ?? []
        addresses = try c.decodeIfPresent([PostalAddress].self, forKey: .addresses) ?? []
        urls = try c.decodeIfPresent([LabeledValue].self, forKey: .urls) ?? []
        relations = try c.decodeIfPresent([LabeledValue].self, forKey: .relations) ?? []
        events = try c.decodeIfPresent([ContactEvent].self, forKey: .events) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        photoURL = try c.decodeIfPresent(URL.self, forKey: .photoURL)
        modified = try c.decodeIfPresent(Date.self, forKey: .modified)
    }

    static func blank() -> Contact { Contact(id: "new-\(UUID().uuidString)") }
    var isNew: Bool { id.hasPrefix("new-") }

    var displayName: String {
        let name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        if !name.isEmpty { return name }
        if !nickname.isEmpty { return nickname }
        if !organization.isEmpty { return organization }
        return emails.first?.value ?? phones.first?.value ?? "No Name"
    }

    var initials: String {
        let letters = [givenName, familyName].compactMap { $0.first }.map(String.init)
        if !letters.isEmpty { return letters.joined().uppercased() }
        return displayName.first.map { String($0).uppercased() } ?? "?"
    }

    var subtitle: String {
        [jobTitle, department, organization].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Letter used for the A–Z list; "#" for anything non-alphabetic.
    var sectionLetter: String {
        let key = displayName
        guard let c = key.folding(options: .diacriticInsensitive, locale: .current).first?.uppercased(),
              c.unicodeScalars.first.map(CharacterSet.letters.contains) == true else { return "#" }
        return c
    }

    /// Whether anything worth saving is filled in.
    var isEmpty: Bool {
        givenName.isEmpty && familyName.isEmpty && middleName.isEmpty && nickname.isEmpty && organization.isEmpty
            && phones.allSatisfy { $0.value.isEmpty } && emails.allSatisfy { $0.value.isEmpty }
            && addresses.allSatisfy(\.isEmpty) && urls.allSatisfy { $0.value.isEmpty } && relations.allSatisfy { $0.value.isEmpty }
            && ims.allSatisfy { $0.value.isEmpty } && customFields.allSatisfy { $0.value.isEmpty }
    }

    /// People API field groups that differ from `original`. Updates send only these, so anything the app
    /// doesn't edit (or doesn't fully model) is left exactly as Google has it.
    func changedGoogleFields(from original: Contact) -> [String] {
        func values(_ a: [LabeledValue]) -> [String] { a.filter { !$0.value.isEmpty }.map { "\($0.label)\u{1F}\($0.value)" } }
        var fields: [String] = []
        if [namePrefix, givenName, middleName, familyName, nameSuffix, phoneticGivenName, phoneticMiddleName, phoneticFamilyName]
            != [original.namePrefix, original.givenName, original.middleName, original.familyName, original.nameSuffix,
                original.phoneticGivenName, original.phoneticMiddleName, original.phoneticFamilyName] { fields.append("names") }
        if nickname != original.nickname { fields.append("nicknames") }
        if [organization, department, jobTitle] != [original.organization, original.department, original.jobTitle] { fields.append("organizations") }
        if values(phones) != values(original.phones) { fields.append("phoneNumbers") }
        if values(emails) != values(original.emails) { fields.append("emailAddresses") }
        if addresses.filter({ !$0.isEmpty }) != original.addresses.filter({ !$0.isEmpty }) { fields.append("addresses") }
        if values(urls) != values(original.urls) { fields.append("urls") }
        if values(relations) != values(original.relations) { fields.append("relations") }
        if values(ims) != values(original.ims) { fields.append("imClients") }
        if values(customFields) != values(original.customFields) { fields.append("userDefined") }
        if events.filter({ $0.kind == .birthday }) != original.events.filter({ $0.kind == .birthday }) { fields.append("birthdays") }
        if events.filter({ $0.kind != .birthday }) != original.events.filter({ $0.kind != .birthday }) { fields.append("events") }
        if notes != original.notes { fields.append("biographies") }
        return fields
    }

    /// A copy of `self` with only the given People API field groups taken from `edited`.
    func applying(fields: [String], from edited: Contact) -> Contact {
        var c = self
        for f in fields {
            switch f {
            case "names":
                c.namePrefix = edited.namePrefix; c.givenName = edited.givenName; c.middleName = edited.middleName
                c.familyName = edited.familyName; c.nameSuffix = edited.nameSuffix
                c.phoneticGivenName = edited.phoneticGivenName; c.phoneticMiddleName = edited.phoneticMiddleName
                c.phoneticFamilyName = edited.phoneticFamilyName
            case "nicknames": c.nickname = edited.nickname
            case "organizations":
                c.organization = edited.organization; c.department = edited.department; c.jobTitle = edited.jobTitle
                c.otherOrganizations = edited.otherOrganizations
            case "phoneNumbers": c.phones = edited.phones
            case "emailAddresses": c.emails = edited.emails
            case "addresses": c.addresses = edited.addresses
            case "urls": c.urls = edited.urls
            case "relations": c.relations = edited.relations
            case "imClients": c.ims = edited.ims
            case "userDefined": c.customFields = edited.customFields
            case "birthdays": c.events = c.events.filter { $0.kind != .birthday } + edited.events.filter { $0.kind == .birthday }
            case "events": c.events = c.events.filter { $0.kind == .birthday } + edited.events.filter { $0.kind != .birthday }
            case "biographies": c.notes = edited.notes
            default: break
            }
        }
        c.modified = edited.modified
        return c
    }
}
