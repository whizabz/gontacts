import Foundation
import Observation

@MainActor @Observable
final class ContactsStore {
    enum Mode: String { case signedOut, demo, google }

    private(set) var mode: Mode
    private(set) var contacts: [Contact] = []
    private(set) var isSyncing = false
    private(set) var lastSynced: Date?
    var errorMessage: String?

    @ObservationIgnored private let auth: GoogleAuth
    @ObservationIgnored private let api: PeopleAPI
    @ObservationIgnored private let defaults = UserDefaults.standard

    var accountEmail: String? { mode == .google ? auth.email : nil }
    var isSignedIn: Bool { mode != .signedOut }

    init() {
        let auth = GoogleAuth()
        self.auth = auth
        api = PeopleAPI(auth: auth)
        let saved = Mode(rawValue: UserDefaults.standard.string(forKey: "store.mode") ?? "") ?? .signedOut
        mode = (saved == .google && !auth.isSignedIn) ? .signedOut : saved
        lastSynced = defaults.object(forKey: "store.lastSynced") as? Date
        contacts = loadCache()
        if mode == .demo && contacts.isEmpty { contacts = SampleData.contacts() }
    }

    func contact(id: String) -> Contact? { contacts.first { $0.id == id } }

    var sorted: [Contact] {
        contacts.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - Sign in / out

    func signInWithGoogle() async {
        do {
            try await auth.signIn()
            setMode(.google)
            contacts = []
            await sync()
        } catch AuthError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func useSampleContacts() {
        setMode(.demo)
        contacts = SampleData.contacts()
        persist()
    }

    func signOut() {
        auth.signOut()
        setMode(.signedOut)
        contacts = []
        lastSynced = nil
        try? FileManager.default.removeItem(at: cacheURL(for: .google))
        try? FileManager.default.removeItem(at: cacheURL(for: .demo))
    }

    // MARK: - Sync

    func sync() async {
        guard mode == .google, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            contacts = try await api.listContacts()
            lastSynced = .now
            defaults.set(lastSynced, forKey: "store.lastSynced")
            persist()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Edit

    /// Saves to Google (or locally in demo mode) and returns the saved contact.
    @discardableResult
    func save(_ contact: Contact) async throws -> Contact {
        var contact = contact
        contact.events = contact.events.map { var e = $0; e.date.clamp(); return e }
        let saved: Contact
        switch mode {
        case .google:
            saved = contact.isNew ? try await api.create(contact) : try await api.update(contact)
        default:
            if contact.isNew { contact.id = "people/local-\(UUID().uuidString)" }
            saved = contact
        }
        if let i = contacts.firstIndex(where: { $0.id == contact.id }) { contacts[i] = saved } else { contacts.append(saved) }
        persist()
        return saved
    }

    func delete(_ contact: Contact) async throws {
        if mode == .google, !contact.isNew { try await api.delete(contact) }
        contacts.removeAll { $0.id == contact.id }
        persist()
    }

    // MARK: - Persistence

    private func setMode(_ m: Mode) {
        mode = m
        defaults.set(m.rawValue, forKey: "store.mode")
    }

    private func cacheURL(for mode: Mode) -> URL {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "contacts-\(mode.rawValue).json")
    }

    private func loadCache() -> [Contact] {
        guard mode != .signedOut, let data = try? Data(contentsOf: cacheURL(for: mode)) else { return [] }
        return (try? JSONDecoder().decode([Contact].self, from: data)) ?? []
    }

    private func persist() {
        guard mode != .signedOut, let data = try? JSONEncoder().encode(contacts) else { return }
        try? data.write(to: cacheURL(for: mode), options: .atomic)
    }
}
