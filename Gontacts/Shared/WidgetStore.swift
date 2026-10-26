import Foundation

/// Data shared between the app and its widgets, kept in the App Group container.
///
/// The app writes the contacts that have a birthday or anniversary (and small photo thumbnails for the ones coming
/// up soon); the widgets read them and work out what to show for each day.
enum WidgetStore {
    static let group = "group.xyz.saltedchips.gontacts"
    /// Widgets open the app on a contact with `gontacts://contact?id=<contact id>`.
    static let scheme = "gontacts"

    static var container: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) }

    private static var eventsFile: URL? { container?.appending(path: "widget-contacts.json") }
    private static var cardsFile: URL? { container?.appending(path: "widget-qr-cards.json") }
    private static var photoDirectory: URL? { container?.appending(path: "widget-photos", directoryHint: .isDirectory) }

    static func openURL(for contactID: String) -> URL {
        var c = URLComponents()
        c.scheme = scheme
        c.host = "contact"
        c.queryItems = [URLQueryItem(name: "id", value: contactID)]
        return c.url ?? URL(string: "\(scheme)://contact")!
    }

    /// The QR widget opens the app on one of your contact cards with `gontacts://card?id=<card id>`.
    static func cardURL(for cardID: String) -> URL {
        var c = URLComponents()
        c.scheme = scheme
        c.host = "card"
        c.queryItems = [URLQueryItem(name: "id", value: cardID)]
        return c.url ?? URL(string: "\(scheme)://card")!
    }

    /// The card id in a `cardURL`, or nil when the URL isn't one.
    static func cardID(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == "card" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "id" }?.value
    }

    static func contactID(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == "contact" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "id" }?.value
    }

    // MARK: Contacts

    /// Contacts worth showing in a widget: those with a birthday or anniversary.
    static func write(_ contacts: [Contact]) {
        guard let url = eventsFile else { return }
        let relevant = contacts.filter { $0.events.contains { $0.kind != .other } }
        guard let data = try? JSONEncoder().encode(relevant) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func read() -> [Contact] {
        guard let url = eventsFile, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Contact].self, from: data)) ?? []
    }

    // MARK: QR cards

    /// The cards the QR widgets can show, each with the vCard its QR code holds.
    static func writeQRCards(_ cards: [QRCardSnapshot]) {
        guard let url = cardsFile, let data = try? JSONEncoder().encode(cards) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func readQRCards() -> [QRCardSnapshot] {
        guard let url = cardsFile, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([QRCardSnapshot].self, from: data)) ?? []
    }

    // MARK: Photos

    private static func photoFile(for id: String) -> URL? {
        let safe = id.map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
        return photoDirectory?.appending(path: "\(safe).jpg")
    }

    static func photoPath(for id: String) -> String? {
        guard let url = photoFile(for: id), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url.path
    }

    static func hasPhoto(for id: String) -> Bool { photoPath(for: id) != nil }

    static func savePhoto(_ jpeg: Data, for id: String) {
        guard let dir = photoDirectory, let file = photoFile(for: id) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? jpeg.write(to: file, options: .atomic)
    }

    /// Removes thumbnails for contacts that are no longer relevant.
    static func prunePhotos(keeping ids: Set<String>) {
        guard let dir = photoDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let keep = Set(ids.compactMap { photoFile(for: $0)?.lastPathComponent })
        for f in files where !keep.contains(f.lastPathComponent) { try? FileManager.default.removeItem(at: f) }
    }
}
