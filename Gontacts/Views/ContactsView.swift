import SwiftUI

enum ContactSort: String, CaseIterable, Identifiable {
    case name, recent
    var id: String { rawValue }
    var title: String { self == .name ? "Name" : "Recently Modified" }
}

struct ContactRow: View {
    @Environment(AppModel.self) private var model
    let contact: Contact
    var showModified = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(contact: contact, size: 40)
            if showModified, let modified = contact.modified {
                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.displayName)
                    Text(modified.formatted(.relative(presentation: .named))).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text(contact.displayName)
            }
            Spacer(minLength: 0)
            if model.store.todayIDs.contains(contact.id) {
                Image(systemName: "birthday.cake").foregroundStyle(.pink).imageScale(.small)
                    .accessibilityLabel("Event today")
            }
        }
    }
}

/// The Contacts list: A–Z sections, sort, and the system bottom search bar with an add button, like iOS Contacts.
struct ContactsList: View {
    @Environment(AppModel.self) private var model
    @AppStorage("contacts.sort") private var sort = ContactSort.name

    private var sections: [(letter: String, contacts: [Contact])] {
        let cardID = model.store.myCard?.id
        let grouped = Dictionary(grouping: model.store.sorted.filter { $0.id != cardID }, by: \.sectionLetter)
        return grouped.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }.map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        @Bindable var model = model
        List(selection: $model.contactsSelection) {
            if let card = model.store.myCard {
                // Like iOS Contacts: no line above My Card, and none between it and the first letter.
                MyCardRow(contact: card).tag(card.id).contactContextMenu(card)
                    .listRowSeparator(.hidden)
            }
            if sort == .recent {
                ForEach(model.store.recentlyModified.filter { $0.id != model.store.myCard?.id }) { contact in
                    ContactRow(contact: contact, showModified: true).tag(contact.id).contactContextMenu(contact)
                }
            } else {
                ForEach(sections, id: \.letter) { section in
                    Section {
                        ForEach(section.contacts) { contact in
                            ContactRow(contact: contact).tag(contact.id).contactContextMenu(contact)
                                // The full-width line under the letter replaces the first row's own top line.
                                .listRowSeparator(contact.id == section.contacts.first?.id ? .hidden : .automatic, edges: .top)
                                // ...and the last row ends the section without a line, as in iOS Contacts.
                                .listRowSeparator(contact.id == section.contacts.last?.id ? .hidden : .automatic, edges: .bottom)
                        }
                    } header: {
                        SectionLetterHeader(letter: section.letter)
                    }
                    .sectionIndexLabel(section.letter)
                }
            }
            Section {} footer: {
                Text("\(model.store.contacts.count) Contacts").frame(maxWidth: .infinity)
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListHeaderHeight, 30)
        .listSectionSpacing(.compact)
        .listSectionIndexVisibility(sort == .name ? .visible : .hidden)
        .refreshable { await model.store.sync() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sort) {
                        ForEach(ContactSort.allCases) { Text($0.title).tag($0) }
                    }
                } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
            }
        }
        .overlay {
            if model.store.contacts.isEmpty {
                ContentUnavailableView("No Contacts", systemImage: "person.2", description: Text("Pull down to sync, or tap + to add one."))
            }
        }
    }
}

/// The letter that starts a section, with a full-width line under it; the contacts below keep their indented lines.
private struct SectionLetterHeader: View {
    let letter: String
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(letter).font(.subheadline).foregroundStyle(.secondary)
            Rectangle().fill(Color(.separator)).frame(height: 1 / displayScale)
        }
        .padding(.top, -6)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The user's own contact, first in the list, like My Card in iOS Contacts.
struct MyCardRow: View {
    @Environment(AppModel.self) private var model
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(contact: contact, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName).font(.title3.weight(.semibold))
                Text("My Card").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            // Your contact cards: the named sets of details you share.
            Button { model.showCards = true } label: { Label("Contact Cards", systemImage: "person.text.rectangle") }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        }
        .padding(.vertical, 4)
    }
}

/// Contacts matching the search text. Shown in place of whichever list is open, so search works from Events too.
struct ContactSearchResults: View {
    @Environment(AppModel.self) private var model
    let query: String

    var body: some View {
        @Bindable var model = model
        let results = model.store.search(query)
        List(results, selection: $model.contactsSelection) { contact in
            ContactRow(contact: contact).tag(contact.id).contactContextMenu(contact)
        }
        .listStyle(.plain)
        .overlay {
            if results.isEmpty { ContentUnavailableView.search(text: query) }
        }
    }
}
