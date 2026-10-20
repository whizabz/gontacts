import Foundation

// MARK: - Wire format (Google People API v1)

struct PersonDTO: Codable {
    struct Name: Codable { var givenName: String?; var familyName: String? }
    struct Field: Codable { var value: String?; var type: String?; var formattedType: String? }
    struct Org: Codable { var name: String?; var title: String? }
    struct DateDTO: Codable { var year: Int?; var month: Int?; var day: Int? }
    struct Birthday: Codable { var date: DateDTO? }
    struct Event: Codable { var date: DateDTO?; var type: String?; var formattedType: String? }
    struct Photo: Codable { var url: String?; var `default`: Bool? }

    var resourceName: String?
    var etag: String?
    var names: [Name]?
    var phoneNumbers: [Field]?
    var emailAddresses: [Field]?
    var organizations: [Org]?
    var birthdays: [Birthday]?
    var events: [Event]?
    var biographies: [Field]?
    var photos: [Photo]?
}

extension PersonDTO {
    static let readFields = "names,phoneNumbers,emailAddresses,organizations,birthdays,events,biographies,photos"
    static let writeFields = "names,phoneNumbers,emailAddresses,organizations,birthdays,events,biographies"

    func toContact() -> Contact? {
        guard let resourceName else { return nil }
        var c = Contact(id: resourceName)
        c.etag = etag
        c.givenName = names?.first?.givenName ?? ""
        c.familyName = names?.first?.familyName ?? ""
        c.organization = organizations?.first?.name ?? ""
        c.jobTitle = organizations?.first?.title ?? ""
        c.phones = (phoneNumbers ?? []).compactMap { f in f.value.map { LabeledValue(label: f.type ?? f.formattedType ?? "other", value: $0) } }
        c.emails = (emailAddresses ?? []).compactMap { f in f.value.map { LabeledValue(label: f.type ?? f.formattedType ?? "other", value: $0) } }
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
        resourceName = c.isNew ? nil : c.id
        etag = c.etag
        names = [Name(givenName: c.givenName, familyName: c.familyName)]
        phoneNumbers = c.phones.filter { !$0.value.isEmpty }.map { Field(value: $0.value, type: $0.label) }
        emailAddresses = c.emails.filter { !$0.value.isEmpty }.map { Field(value: $0.value, type: $0.label) }
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

// MARK: - Client

enum APIError: LocalizedError {
    case http(Int, String)
    case conflict

    var errorDescription: String? {
        switch self {
        case .http(let code, let message): "Google returned \(code). \(message)"
        case .conflict: "This contact changed on another device. Pull to refresh and try again."
        }
    }
}

@MainActor
final class PeopleAPI {
    private let auth: GoogleAuth
    private let base = URL(string: "https://people.googleapis.com/v1/")!

    init(auth: GoogleAuth) { self.auth = auth }

    func listContacts() async throws -> [Contact] {
        var all: [Contact] = []
        var pageToken: String?
        repeat {
            var query = [URLQueryItem(name: "personFields", value: PersonDTO.readFields), URLQueryItem(name: "pageSize", value: "1000")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let page: ConnectionsPage = try await send("people/me/connections", query: query)
            all += (page.connections ?? []).compactMap { $0.toContact() }
            pageToken = page.nextPageToken
        } while pageToken != nil
        return all
    }

    func create(_ contact: Contact) async throws -> Contact {
        let dto: PersonDTO = try await send("people:createContact", method: "POST", query: [URLQueryItem(name: "personFields", value: PersonDTO.readFields)], body: PersonDTO(contact: contact))
        return dto.toContact() ?? contact
    }

    func update(_ contact: Contact) async throws -> Contact {
        let query = [URLQueryItem(name: "updatePersonFields", value: PersonDTO.writeFields), URLQueryItem(name: "personFields", value: PersonDTO.readFields)]
        let dto: PersonDTO = try await send("\(contact.id):updateContact", method: "PATCH", query: query, body: PersonDTO(contact: contact))
        return dto.toContact() ?? contact
    }

    func delete(_ contact: Contact) async throws {
        let _: EmptyResponse = try await send("\(contact.id):deleteContact", method: "DELETE")
    }

    // MARK: -

    private struct ConnectionsPage: Decodable { var connections: [PersonDTO]?; var nextPageToken: String? }
    private struct EmptyResponse: Decodable {}
    private struct APIErrorBody: Decodable { struct E: Decodable { var message: String?; var status: String? }; var error: E? }

    private func send<T: Decodable>(_ path: String, method: String = "GET", query: [URLQueryItem] = [], body: PersonDTO? = nil, retry: Bool = true) async throws -> T {
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        // Keep the literal ':' for Google's custom verbs like ":updateContact".
        comps.percentEncodedPath = "/v1/" + path
        comps.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: comps.url!)
        request.httpMethod = method
        request.setValue("Bearer \(try await auth.validAccessToken())", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401, retry {
            auth.invalidateAccessToken()
            return try await send(path, method: method, query: query, body: body, retry: false)
        }
        guard (200..<300).contains(status) else {
            let parsed = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            if status == 409 || parsed?.error?.status == "FAILED_PRECONDITION" { throw APIError.conflict }
            throw APIError.http(status, parsed?.error?.message ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
    }
}
