import Foundation
import Observation

@MainActor @Observable
final class ContactsStore {
    enum Mode: String { case signedOut, demo, google }

    private(set) var mode: Mode
    /// Demo overlay: signed in to Google, but showing sample contacts instead. Google is neither read nor written.
    private(set) var isDemoOverlay: Bool
    private(set) var isSyncing = false
    private(set) var lastSynced: Date?
    var errorMessage: String?

    // What the UI shows. Rebuilt whenever the underlying data changes, so views never sort or scan per render.
    private(set) var contacts: [Contact] = []
    private(set) var sorted: [Contact] = []
    private(set) var todayIDs: Set<String> = []
    /// Bumps on every change; lets views cache derived data (like the events timeline).
    private(set) var revision = 0

    @ObservationIgnored private var liveContacts: [Contact] = []
    @ObservationIgnored private var sampleContacts: [Contact] = []
    @ObservationIgnored private var index: [String: Contact] = [:]
    @ObservationIgnored private var searchKeys: [String: String] = [:]

    @ObservationIgnored private let auth: GoogleAuth
    @ObservationIgnored private let api: PeopleAPI
    @ObservationIgnored private let defaults = UserDefaults.standard

    var accountEmail: String? { mode == .google ? auth.email : nil }
    var isSignedIn: Bool { mode != .signedOut }
    /// True when the contacts on screen are the sample ones.
    var isShowingSample: Bool { mode == .demo || isDemoOverlay }
    var canSync: Bool { mode == .google && !isDemoOverlay }

    init() {
        let auth = GoogleAuth()
        self.auth = auth
        api = PeopleAPI(auth: auth)
        let saved = Mode(rawValue: UserDefaults.standard.string(forKey: "store.mode") ?? "") ?? .signedOut
        let resolved: Mode = (saved == .google && !auth.isSignedIn) ? .signedOut : saved
        mode = resolved
        isDemoOverlay = resolved == .google && UserDefaults.standard.bool(forKey: "store.demoOverlay")
        lastSynced = defaults.object(forKey: "store.lastSynced") as? Date

        if mode == .google { liveContacts = load(.google) }
        if isShowingSample {
            sampleContacts = load(.demo)
            if sampleContacts.isEmpty { sampleContacts = SampleData.contacts() }
        }
        rebuild()
    }

    func contact(id: String) -> Contact? { index[id] }

    /// Contacts matching `query` by name, company, email or phone digits.
    func search(_ query: String) -> [Contact] {
        let q = Self.fold(query)
        guard !q.isEmpty else { return sorted }
        let digits = query.filter(\.isNumber)
        return sorted.filter { c in
            guard let key = searchKeys[c.id] else { return false }
            return key.contains(q) || (digits.count >= 3 && key.contains(digits))
        }
    }

    /// Re-evaluates "who has an event today", e.g. after midnight.
    func refreshToday() {
        let t = Self.todayIDs(in: contacts)
        if t != todayIDs { todayIDs = t }
    }

    // MARK: - Sign in / out

    func signInWithGoogle() async {
        do {
            try await auth.signIn()
            setMode(.google)
            setOverlayFlag(false)
            liveContacts = []
            sampleContacts = []
            try? FileManager.default.removeItem(at: cacheURL(for: .demo))
            rebuild()
            await sync()
        } catch AuthError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func useSampleContacts() {
        setMode(.demo)
        setOverlayFlag(false)
        sampleContacts = SampleData.contacts()
        rebuild()
        persist()
    }

    /// Switch between your real contacts and the sample ones, without signing out of Google.
    func setDemoOverlay(_ on: Bool) {
        guard mode == .google, on != isDemoOverlay else { return }
        if on, sampleContacts.isEmpty { sampleContacts = load(.demo) }
        if on, sampleContacts.isEmpty { sampleContacts = SampleData.contacts() }
        setOverlayFlag(on)
        rebuild()
        persist()
    }

    func signOut() {
        auth.signOut()
        setMode(.signedOut)
        setOverlayFlag(false)
        liveContacts = []
        sampleContacts = []
        lastSynced = nil
        try? FileManager.default.removeItem(at: cacheURL(for: .google))
        try? FileManager.default.removeItem(at: cacheURL(for: .demo))
        rebuild()
    }

    // MARK: - Sync

    func sync() async {
        guard canSync, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            liveContacts = try await api.listContacts()
            lastSynced = .now
            defaults.set(lastSynced, forKey: "store.lastSynced")
            rebuild()
            persist()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Edit

    /// Saves to Google (or locally when showing sample contacts) and returns the saved contact.
    @discardableResult
    func save(_ contact: Contact, original: Contact? = nil) async throws -> Contact {
        var contact = contact
        contact.events = contact.events.map { var e = $0; e.date.clamp(); return e }
        let saved: Contact
        if isShowingSample {
            if contact.isNew { contact.id = "people/local-\(UUID().uuidString)" }
            saved = contact
            upsert(saved, into: &sampleContacts)
        } else {
            if contact.isNew {
                saved = try await api.create(contact)
            } else {
                // Only the field groups that changed are sent, so data the app doesn't model survives the edit.
                let fields = original.map { contact.changedGoogleFields(from: $0) } ?? PersonDTO.writeFields.split(separator: ",").map(String.init)
                saved = try await api.update(contact, fields: fields)
            }
            upsert(saved, into: &liveContacts)
        }
        rebuild()
        persist()
        return saved
    }

    func delete(_ contact: Contact) async throws {
        if isShowingSample {
            sampleContacts.removeAll { $0.id == contact.id }
        } else {
            if !contact.isNew { try await api.delete(contact) }
            liveContacts.removeAll { $0.id == contact.id }
        }
        rebuild()
        persist()
    }

    private func upsert(_ c: Contact, into list: inout [Contact]) {
        if let i = list.firstIndex(where: { $0.id == c.id }) { list[i] = c } else { list.append(c) }
    }

    // MARK: - Derived data

    private func rebuild() {
        contacts = isShowingSample ? sampleContacts : liveContacts
        sorted = contacts.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        index = Dictionary(contacts.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        searchKeys = Dictionary(contacts.map { ($0.id, Self.searchKey(for: $0)) }, uniquingKeysWith: { a, _ in a })
        todayIDs = Self.todayIDs(in: contacts)
        revision += 1
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).trimmingCharacters(in: .whitespaces)
    }

    private static func searchKey(for c: Contact) -> String {
        let parts = [c.displayName, c.nickname, c.organization, c.department, c.jobTitle] + c.emails.map(\.value) + c.phones.map(\.value) + c.ims.map(\.value)
        return fold(parts.joined(separator: " ")) + " " + c.phones.map { $0.value.filter(\.isNumber) }.joined(separator: " ")
    }

    private static func todayIDs(in contacts: [Contact], calendar: Calendar = .current) -> Set<String> {
        let today = calendar.dateComponents([.year, .month, .day], from: .now)
        guard let year = today.year, let month = today.month else { return [] }
        let startOfToday = calendar.startOfDay(for: .now)
        var ids = Set<String>()
        for c in contacts {
            for e in c.events where e.date.month == month {
                if let d = e.date.date(inYear: year, calendar: calendar), calendar.isDate(d, inSameDayAs: startOfToday) {
                    ids.insert(c.id)
                    break
                }
            }
        }
        return ids
    }

    // MARK: - Persistence

    private func setMode(_ m: Mode) {
        mode = m
        defaults.set(m.rawValue, forKey: "store.mode")
    }

    private func setOverlayFlag(_ on: Bool) {
        isDemoOverlay = on
        defaults.set(on, forKey: "store.demoOverlay")
    }

    private func cacheURL(for mode: Mode) -> URL {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "contacts-\(mode.rawValue).json")
    }

    private func load(_ mode: Mode) -> [Contact] {
        guard let data = try? Data(contentsOf: cacheURL(for: mode)) else { return [] }
        return (try? JSONDecoder().decode([Contact].self, from: data)) ?? []
    }

    private func persist() {
        if mode == .google, let data = try? JSONEncoder().encode(liveContacts) {
            try? data.write(to: cacheURL(for: .google), options: .atomic)
        }
        if isShowingSample, let data = try? JSONEncoder().encode(sampleContacts) {
            try? data.write(to: cacheURL(for: .demo), options: .atomic)
        }
    }
}
