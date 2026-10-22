import Foundation
import Network
import Observation

/// An edit to an existing Google contact that hasn't reached Google yet. Kept on disk until it has.
struct PendingChange: Codable {
    var contact: Contact
    var fields: [String]
}

/// Where a contact stands with Google, for the status line on its screen.
enum ContactSyncState: Equatable {
    case synced, syncing, waiting
    case failed(String)
}

@MainActor @Observable
final class ContactsStore {
    enum Mode: String { case signedOut, demo, google }

    private(set) var mode: Mode
    /// Demo overlay: signed in to Google, but showing sample contacts instead. Google is neither read nor written.
    private(set) var isDemoOverlay: Bool
    private(set) var isSyncing = false
    /// Contacts whose edits are being sent to Google right now.
    private(set) var syncingIDs: Set<String> = []
    /// Edits waiting to be sent (offline, interrupted, or being retried). Persisted.
    private(set) var pending: [String: PendingChange] = [:]
    /// Edits Google refused for a reason retrying won't fix; shown on the contact until retried.
    private(set) var failures: [String: String] = [:]
    /// Bumps when the data source changes (demo on/off, sign in/out) so screens can drop stale selections.
    private(set) var sourceVersion = 0
    /// The contact the user marked as theirs ("My Card"). Falls back to the contact with the account's email.
    private(set) var myCardID: String? = UserDefaults.standard.string(forKey: "store.myCardID")
    private(set) var lastSynced: Date?
    var errorMessage: String?

    // What the UI shows. Rebuilt whenever the underlying data changes, so views never sort or scan per render.
    private(set) var contacts: [Contact] = []
    private(set) var sorted: [Contact] = []
    private(set) var recentlyModified: [Contact] = []
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
    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var resolvingConflict = false

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
        pending = loadPending()
        rebuild()

        // Retry waiting edits as soon as the network comes back.
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.flushPending() }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    /// The user's own contact, shown pinned at the top of Contacts. Never for the sample contacts.
    var myCard: Contact? {
        _ = revision
        guard !isShowingSample else { return nil }
        if let id = myCardID, let c = index[id] { return c }
        guard myCardID == nil, let email = accountEmail?.lowercased() else { return nil }
        return contacts.first { $0.emails.contains { $0.value.lowercased() == email } }
    }

    func setMyCard(_ id: String?) {
        myCardID = id
        defaults.set(id, forKey: "store.myCardID")
    }

    func syncState(for id: String) -> ContactSyncState {
        if syncingIDs.contains(id) { return .syncing }
        if let message = failures[id] { return .failed(message) }
        return pending[id] != nil ? .waiting : .synced
    }

    func contact(id: String) -> Contact? {
        _ = revision // `index` isn't observed on its own; reading `revision` makes views refresh when a contact changes
        return index[id]
    }

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
        pending = [:]
        failures = [:]
        setMyCard(nil)
        savePending()
        try? FileManager.default.removeItem(at: cacheURL(for: .google))
        try? FileManager.default.removeItem(at: cacheURL(for: .demo))
        rebuild()
        WidgetPublisher.publish(contacts)
    }

    // MARK: - Sync

    /// Automatic syncs (on launch / foreground) fail silently, retrying once, since the network is often
    /// still waking up; the cached contacts stay on screen. Syncs the user asks for report errors.
    func sync(userInitiated: Bool = true) async {
        guard canSync, !isSyncing, syncingIDs.isEmpty else { return }
        isSyncing = true
        defer { isSyncing = false }
        for attempt in 0..<(userInitiated ? 1 : 2) {
            do {
                liveContacts = try await api.listContacts().map { fetched in
                    // Edits still waiting to be sent stay on screen, rebased on Google's latest version.
                    guard let change = pending[fetched.id] else { return fetched }
                    return fetched.applying(fields: change.fields, from: change.contact)
                }
                lastSynced = .now
                defaults.set(lastSynced, forKey: "store.lastSynced")
                rebuild()
                persist()
                errorMessage = nil
                isSyncing = false
                await flushPending()
                return
            } catch {
                if userInitiated { errorMessage = error.localizedDescription; return }
                if attempt == 0 { try? await Task.sleep(for: .seconds(4)) }
            }
        }
    }

    // MARK: - Edit

    /// Saves and returns the contact. Edits to an existing Google contact apply on screen at once and are sent to
    /// Google in the background (see `syncingIDs`); if Google rejects them, the previous version comes back.
    @discardableResult
    func save(_ contact: Contact, original: Contact? = nil) async throws -> Contact {
        var contact = contact
        contact.events = contact.events.map { var e = $0; e.date.clamp(); return e }
        contact.modified = .now
        if isShowingSample {
            if contact.isNew { contact.id = "people/local-\(UUID().uuidString)" }
            upsert(contact, into: &sampleContacts)
        } else if contact.isNew {
            contact = try await api.create(contact)
            upsert(contact, into: &liveContacts)
        } else {
            // Only the field groups that changed are sent, so data the app doesn't model survives the edit.
            let fields = original.map { contact.changedGoogleFields(from: $0) } ?? PersonDTO.writeFields.split(separator: ",").map(String.init)
            upsert(contact, into: &liveContacts)
            let merged = Set(pending[contact.id]?.fields ?? []).union(fields)
            pending[contact.id] = PendingChange(contact: contact, fields: Array(merged))
            failures[contact.id] = nil
            savePending()
            Task { await flushPending() }
        }
        rebuild()
        persist()
        return contact
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

    // MARK: - Pending edits

    /// Sends waiting edits to Google. Offline or interrupted edits stay queued and are retried quietly (when the
    /// app opens, when the network returns, or when the user taps retry); nothing here raises an alert.
    func flushPending() async {
        guard canSync, !isSyncing, !pending.isEmpty else { return }
        var conflicted = false
        var editedAgain = false
        for id in Array(pending.keys) where !syncingIDs.contains(id) {
            guard let change = pending[id] else { continue }
            syncingIDs.insert(id)
            failures[id] = nil
            do {
                var saved = try await api.update(change.contact, fields: change.fields)
                saved.modified = saved.modified ?? change.contact.modified
                // Keep anything edited again while this was in flight.
                if let newer = pending[id], newer.fields != change.fields || newer.contact != change.contact {
                    pending[id] = PendingChange(contact: newer.contact, fields: newer.fields)
                    editedAgain = true
                    upsert(newer.contact, into: &liveContacts)
                } else {
                    pending[id] = nil
                    upsert(saved, into: &liveContacts)
                }
            } catch APIError.conflict {
                if resolvingConflict { failures[id] = APIError.conflict.localizedDescription } else { conflicted = true }
            } catch {
                if Self.isTransient(error) {
                    // Stays queued as "waiting".
                } else {
                    failures[id] = error.localizedDescription
                }
            }
            syncingIDs.remove(id)
        }
        savePending()
        rebuild()
        persist()
        if conflicted {
            // Google's copy changed since we last looked: fetch it, rebase the edit on it, and send again.
            resolvingConflict = true
            await sync(userInitiated: false)
            resolvingConflict = false
        } else if editedAgain {
            await flushPending()
        }
    }

    /// Tap-to-retry on a contact that failed.
    func retry(_ id: String) async {
        failures[id] = nil
        await flushPending()
    }

    private static func isTransient(_ error: Error) -> Bool {
        if error is URLError { return true }
        if case APIError.http(let code, _) = error { return code == 429 || code >= 500 }
        return false
    }

    private func pendingURL() -> URL {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "pending-edits.json")
    }

    private func loadPending() -> [String: PendingChange] {
        guard mode == .google, let data = try? Data(contentsOf: pendingURL()) else { return [:] }
        return (try? JSONDecoder().decode([String: PendingChange].self, from: data)) ?? [:]
    }

    private func savePending() {
        if pending.isEmpty {
            try? FileManager.default.removeItem(at: pendingURL())
        } else if let data = try? JSONEncoder().encode(pending) {
            try? data.write(to: pendingURL(), options: .atomic)
        }
    }

    private func upsert(_ c: Contact, into list: inout [Contact]) {
        if let i = list.firstIndex(where: { $0.id == c.id }) { list[i] = c } else { list.append(c) }
    }

    // MARK: - Derived data

    private func rebuild() {
        contacts = isShowingSample ? sampleContacts : liveContacts
        sorted = contacts.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        recentlyModified = sorted.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
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
        sourceVersion += 1
        defaults.set(m.rawValue, forKey: "store.mode")
    }

    private func setOverlayFlag(_ on: Bool) {
        isDemoOverlay = on
        sourceVersion += 1
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
        WidgetPublisher.publish(contacts)
        if mode == .google, let data = try? JSONEncoder().encode(liveContacts) {
            try? data.write(to: cacheURL(for: .google), options: .atomic)
        }
        if isShowingSample, let data = try? JSONEncoder().encode(sampleContacts) {
            try? data.write(to: cacheURL(for: .demo), options: .atomic)
        }
    }
}
