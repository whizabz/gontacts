import Foundation

extension Contact {
    /// This contact as a vCard 3.0, the format iOS Contacts and most other apps import.
    ///
    /// Dates without a year use Apple's convention (year 1604 plus `X-APPLE-OMIT-YEAR`) so iOS shows
    /// "13 December" rather than a made-up year.
    var vCard: String {
        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        func add(_ line: String) { lines.append(line) }
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ";", with: "\\;")
                .replacingOccurrences(of: ",", with: "\\,").replacingOccurrences(of: "\n", with: "\\n")
        }
        func type(_ label: String, _ map: [String: String]) -> String {
            map[label.lowercased()].map { ";TYPE=\($0)" } ?? ""
        }
        func date(_ d: EventDate) -> (param: String, value: String) {
            let md = String(format: "%02d-%02d", d.month, d.day)
            if let y = d.year { return ("", String(format: "%04d-", y) + md) }
            return (";X-APPLE-OMIT-YEAR=1604", "1604-" + md)
        }

        add("N:\(esc(familyName));\(esc(givenName));\(esc(middleName));\(esc(namePrefix));\(esc(nameSuffix))")
        add("FN:\(esc(displayName))")
        if !nickname.isEmpty { add("NICKNAME:\(esc(nickname))") }
        if !organization.isEmpty || !department.isEmpty { add("ORG:\(esc(organization));\(esc(department))") }
        if !jobTitle.isEmpty { add("TITLE:\(esc(jobTitle))") }

        let kinds = ["mobile": "CELL", "home": "HOME", "work": "WORK", "main": "PREF"]
        for p in phones where !p.value.isEmpty { add("TEL\(type(p.label, kinds)):\(esc(p.value))") }
        for e in emails where !e.value.isEmpty { add("EMAIL\(type(e.label, kinds)):\(esc(e.value))") }
        for u in urls where !u.value.isEmpty { add("URL:\(esc(u.value))") }
        for a in addresses where !a.isEmpty {
            add("ADR\(type(a.label, kinds)):\(esc(a.poBox));\(esc(a.extendedAddress));\(esc(a.street));\(esc(a.city));\(esc(a.region));\(esc(a.postalCode));\(esc(a.country))")
        }
        if let b = events.first(where: { $0.kind == .birthday }) {
            let d = date(b.date)
            add("BDAY\(d.param):\(d.value)")
        }
        var item = 0
        for e in events where e.kind != .birthday {
            item += 1
            let d = date(e.date)
            let label = e.kind == .anniversary ? "_$!<Anniversary>!$_" : e.displayTitle
            add("item\(item).X-ABDATE\(d.param):\(d.value)")
            add("item\(item).X-ABLabel:\(esc(label))")
        }
        if !notes.isEmpty { add("NOTE:\(esc(notes))") }
        add("END:VCARD")
        return lines.joined(separator: "\r\n") + "\r\n"
    }
}

/// One thing that can be ticked on the "Share Contact" screen.
enum ShareField: Hashable {
    case name, nickname, company, jobTitle, notes
    case phone(UUID), email(UUID), url(UUID), address(UUID), event(UUID)
}

extension Contact {
    /// A copy holding only the ticked fields, ready to turn into a vCard.
    func keeping(_ chosen: Set<ShareField>) -> Contact {
        var c = Contact(id: id)
        if chosen.contains(.name) {
            c.namePrefix = namePrefix; c.givenName = givenName; c.middleName = middleName
            c.familyName = familyName; c.nameSuffix = nameSuffix
        }
        if chosen.contains(.nickname) { c.nickname = nickname }
        if chosen.contains(.company) { c.organization = organization; c.department = department }
        if chosen.contains(.jobTitle) { c.jobTitle = jobTitle }
        if chosen.contains(.notes) { c.notes = notes }
        c.phones = phones.filter { chosen.contains(.phone($0.id)) }
        c.emails = emails.filter { chosen.contains(.email($0.id)) }
        c.urls = urls.filter { chosen.contains(.url($0.id)) }
        c.addresses = addresses.filter { chosen.contains(.address($0.id)) }
        c.events = events.filter { chosen.contains(.event($0.id)) }
        return c
    }

    /// Writes `vCard` to a temporary `.vcf` named after the contact and returns its URL.
    func writeVCardFile() throws -> URL {
        let name = displayName.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(name).vcf")
        try vCard.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
