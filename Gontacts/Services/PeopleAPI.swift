import Foundation

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

    /// Updates only `fields` (People API field names), leaving every other part of the contact untouched.
    func update(_ contact: Contact, fields: [String]) async throws -> Contact {
        guard !fields.isEmpty else { return contact }
        let query = [URLQueryItem(name: "updatePersonFields", value: fields.joined(separator: ",")), URLQueryItem(name: "personFields", value: PersonDTO.readFields)]
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
