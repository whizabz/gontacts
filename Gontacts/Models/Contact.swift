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
    var givenName = ""
    var familyName = ""
    var organization = ""
    var jobTitle = ""
    var phones: [LabeledValue] = []
    var emails: [LabeledValue] = []
    var events: [ContactEvent] = []
    var notes = ""
    var photoURL: URL?

    static func blank() -> Contact { Contact(id: "new-\(UUID().uuidString)") }
    var isNew: Bool { id.hasPrefix("new-") }

    var displayName: String {
        let name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        if !name.isEmpty { return name }
        if !organization.isEmpty { return organization }
        return emails.first?.value ?? phones.first?.value ?? "No Name"
    }

    var initials: String {
        let letters = [givenName, familyName].compactMap { $0.first }.map(String.init)
        if !letters.isEmpty { return letters.joined().uppercased() }
        return displayName.first.map { String($0).uppercased() } ?? "?"
    }

    var subtitle: String {
        [jobTitle, organization].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Letter used for the A–Z list; "#" for anything non-alphabetic.
    var sectionLetter: String {
        let key = (familyName.isEmpty ? givenName : familyName).isEmpty ? displayName : (givenName.isEmpty ? familyName : givenName)
        guard let c = key.folding(options: .diacriticInsensitive, locale: .current).first?.uppercased(),
              c.unicodeScalars.first.map(CharacterSet.letters.contains) == true else { return "#" }
        return c
    }

    /// Whether anything worth saving is filled in.
    var isEmpty: Bool {
        givenName.isEmpty && familyName.isEmpty && organization.isEmpty
            && phones.allSatisfy { $0.value.isEmpty } && emails.allSatisfy { $0.value.isEmpty }
    }
}
