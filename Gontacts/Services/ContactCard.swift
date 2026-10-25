import Foundation
import Observation
import SwiftUI

/// A named selection of the user's own details (Work, Social…) that can be shared in one tap.
///
/// Details are remembered by what they say ("email:me@work.com"), not by the id the app gave them, so a card keeps
/// working after a sync. If a detail changes, it has to be selected again on the card.
struct ContactCard: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// An SF Symbol name.
    var symbol: String
    /// Index into `CardColor.all`.
    var colorIndex: Int
    var fields: Set<String>

    /// The built-in card that shares everything. Not stored.
    static let fullID = UUID(uuidString: "00000000-0000-0000-0000-00000000F011")!
}

/// The pastel tiles cards use, each a light background with a darker symbol colour.
struct CardColor {
    let background: Color
    let foreground: Color

    static let all: [CardColor] = [
        CardColor(background: Color(red: 0.878, green: 0.871, blue: 1.0), foreground: Color(red: 0.247, green: 0.239, blue: 0.659)),
        CardColor(background: Color(red: 0.804, green: 0.937, blue: 0.890), foreground: Color(red: 0.043, green: 0.361, blue: 0.267)),
        CardColor(background: Color(red: 1.0, green: 0.851, blue: 0.894), foreground: Color(red: 0.612, green: 0.114, blue: 0.278)),
        CardColor(background: Color(red: 1.0, green: 0.890, blue: 0.780), foreground: Color(red: 0.761, green: 0.255, blue: 0.047)),
        CardColor(background: Color(red: 0.812, green: 0.937, blue: 0.953), foreground: Color(red: 0.055, green: 0.455, blue: 0.565)),
        CardColor(background: Color(red: 1.0, green: 0.945, blue: 0.722), foreground: Color(red: 0.541, green: 0.353, blue: 0.0)),
        CardColor(background: Color(red: 1.0, green: 0.839, blue: 0.820), foreground: Color(red: 0.702, green: 0.149, blue: 0.118)),
        CardColor(background: Color(red: 0.925, green: 0.925, blue: 0.945), foreground: Color(red: 0.294, green: 0.294, blue: 0.333)),
    ]

    static func at(_ index: Int) -> CardColor { all[min(max(index, 0), all.count - 1)] }
}

/// The user's contact cards. They live on this phone.
@MainActor @Observable
final class ContactCardStore {
    private var liveCards: [ContactCard]
    private var demoCards: [ContactCard]
    /// Demo mode keeps its own sample cards so it never touches yours.
    @ObservationIgnored private let isDemo: () -> Bool

    var cards: [ContactCard] { isDemo() ? demoCards : liveCards }
    /// The card chosen last time on the Share screen (`ContactCard.fullID` for Full contact).
    var lastUsedID: UUID? {
        didSet { UserDefaults.standard.set(lastUsedID?.uuidString, forKey: Self.lastUsedKey) }
    }

    private static let cardsKey = "contactCards"
    private static let demoKey = "contactCards.demo"
    private static let lastUsedKey = "contactCards.lastUsed"

    init(isDemo: @escaping () -> Bool = { false }) {
        self.isDemo = isDemo
        liveCards = Self.load(Self.cardsKey) ?? []
        // The sample My Card comes with a few cards to show off; they're made once, then yours to change.
        demoCards = Self.load(Self.demoKey) ?? Self.sampleCards()
        lastUsedID = UserDefaults.standard.string(forKey: Self.lastUsedKey).flatMap(UUID.init(uuidString:))
    }

    func save(_ card: ContactCard) {
        update { list in
            if let i = list.firstIndex(where: { $0.id == card.id }) { list[i] = card } else { list.append(card) }
        }
    }

    func delete(_ id: UUID) {
        update { $0.removeAll { $0.id == id } }
        if lastUsedID == id { lastUsedID = nil }
    }

    func move(from: IndexSet, to: Int) {
        update { $0.move(fromOffsets: from, toOffset: to) }
    }

    private func update(_ change: (inout [ContactCard]) -> Void) {
        if isDemo() { change(&demoCards) } else { change(&liveCards) }
        persist()
    }

    func card(_ id: UUID) -> ContactCard? { cards.first { $0.id == id } }

    private func persist() {
        if let data = try? JSONEncoder().encode(liveCards) { UserDefaults.standard.set(data, forKey: Self.cardsKey) }
        if let data = try? JSONEncoder().encode(demoCards) { UserDefaults.standard.set(data, forKey: Self.demoKey) }
    }

    private static func load(_ key: String) -> [ContactCard]? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([ContactCard].self, from: $0) }
    }

    /// Work, Social and Personal cards for the sample My Card.
    private static func sampleCards() -> [ContactCard] {
        guard let me = SampleData.contacts().first(where: { $0.id == SampleData.myCardID }) else { return [] }
        func card(_ name: String, _ symbol: String, _ color: Int, _ nouns: Set<String>) -> ContactCard {
            let keys = Set(me.shareGroups.flatMap { $0 }.filter { nouns.contains($0.noun) }.map(\.key))
            return ContactCard(name: name, symbol: symbol, colorIndex: color, fields: keys)
        }
        return [
            card("Work", "briefcase", 1, ["Name", "company", "job title", "work phone", "work email", "website"]),
            card("Social", "bubble.left", 2, ["Name", "nickname", "linkedin", "website"]),
            card("Personal", "house", 3, ["Name", "mobile", "home email", "home address", "birthday"]),
        ]
    }
}

// MARK: - The details of a contact that can be picked

/// One pickable detail: a row on the Share and Edit Contact Card screens.
struct ShareRow: Identifiable {
    let field: ShareField
    let label: String
    let value: String
    /// What it is called in a card's summary, e.g. "work email".
    let noun: String
    /// What the card remembers it by.
    let key: String
    var id: ShareField { field }
}

extension Contact {
    /// The pickable details in the order they're shown, grouped as on the screen.
    var shareGroups: [[ShareRow]] {
        var identity: [ShareRow] = []
        let name = [namePrefix, givenName, middleName, familyName, nameSuffix].filter { !$0.isEmpty }.joined(separator: " ")
        if !name.isEmpty { identity.append(ShareRow(field: .name, label: "Name", value: name, noun: "Name", key: "name")) }
        if !nickname.isEmpty { identity.append(ShareRow(field: .nickname, label: "Nickname", value: nickname, noun: "nickname", key: "nickname")) }
        let company = [organization, department].filter { !$0.isEmpty }.joined(separator: " · ")
        if !company.isEmpty { identity.append(ShareRow(field: .company, label: "Company", value: company, noun: "company", key: "company")) }
        if !jobTitle.isEmpty { identity.append(ShareRow(field: .jobTitle, label: "Job title", value: jobTitle, noun: "job title", key: "jobTitle")) }

        func noun(_ label: String, _ kind: String) -> String {
            let l = label.displayLabel.lowercased()
            return ["mobile", "iphone", "main"].contains(l) && kind == "phone" ? l : "\(l) \(kind)"
        }
        let phones = phones.filter { !$0.value.isEmpty }.map {
            ShareRow(field: .phone($0.id), label: $0.label.displayLabel, value: $0.value, noun: noun($0.label, "phone"), key: "phone:\($0.value)")
        }
        let emails = emails.filter { !$0.value.isEmpty }.map {
            ShareRow(field: .email($0.id), label: $0.label.displayLabel, value: $0.value, noun: noun($0.label, "email"), key: "email:\($0.value)")
        }
        let addresses = addresses.filter { !$0.isEmpty }.map {
            ShareRow(field: .address($0.id), label: $0.label.displayLabel, value: $0.formatted.replacingOccurrences(of: "\n", with: ", "),
                     noun: noun($0.label, "address"), key: "address:\($0.formatted)")
        }
        let urls = urls.filter { !$0.value.isEmpty }.map {
            ShareRow(field: .url($0.id), label: $0.label.displayLabel, value: $0.value, noun: $0.label.lowercased(), key: "url:\($0.value)")
        }
        let dates = events.map {
            ShareRow(field: .event($0.id), label: $0.displayTitle, value: $0.date.formatted(), noun: $0.displayTitle.lowercased(), key: "event:\($0.displayTitle):\($0.date.formatted())")
        }
        var notes: [ShareRow] = []
        if !self.notes.isEmpty { notes.append(ShareRow(field: .notes, label: "Notes", value: self.notes, noun: "notes", key: "notes")) }

        return [identity, phones, emails, addresses, urls, dates, notes].filter { !$0.isEmpty }
    }

    var allShareFields: Set<ShareField> { Set(shareGroups.flatMap { $0.map(\.field) }) }

    /// The details of this contact that a card with these keys includes.
    func shareFields(for keys: Set<String>) -> Set<ShareField> {
        Set(shareGroups.flatMap { $0 }.filter { keys.contains($0.key) }.map(\.field))
    }

    func shareKeys(for fields: Set<ShareField>) -> Set<String> {
        Set(shareGroups.flatMap { $0 }.filter { fields.contains($0.field) }.map(\.key))
    }

    /// "Name, mobile, work email +3 more details": only what's included, cut after about two lines.
    func cardSummary(_ keys: Set<String>) -> String {
        let nouns = shareGroups.flatMap { $0 }.filter { keys.contains($0.key) }.map(\.noun)
        guard !nouns.isEmpty else { return "No details" }
        var shown: [String] = []
        var length = 0
        for noun in nouns {
            let next = length + noun.count + 2
            if next > 58, !shown.isEmpty { break }
            shown.append(shown.isEmpty ? noun.prefix(1).uppercased() + noun.dropFirst() : noun)
            length = next
        }
        let rest = nouns.count - shown.count
        var text = shown.joined(separator: ", ")
        if rest > 0 { text += " +\(rest) more \(rest == 1 ? "detail" : "details")" }
        return text
    }
}
