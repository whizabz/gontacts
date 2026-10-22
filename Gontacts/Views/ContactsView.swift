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
        let grouped = Dictionary(grouping: model.store.sorted, by: \.sectionLetter)
        return grouped.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }.map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        @Bindable var model = model
        List(selection: $model.contactsSelection) {
            if sort == .recent {
                ForEach(model.store.recentlyModified) { contact in
                    ContactRow(contact: contact, showModified: true).tag(contact.id)
                }
            } else {
                ForEach(sections, id: \.letter) { section in
                    Section(section.letter) {
                        ForEach(section.contacts) { contact in
                            ContactRow(contact: contact).tag(contact.id)
                        }
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

/// Contacts matching the search text. Shown in place of whichever list is open, so search works from Events too.
struct ContactSearchResults: View {
    @Environment(AppModel.self) private var model
    let query: String

    var body: some View {
        @Bindable var model = model
        let results = model.store.search(query)
        List(results, selection: $model.contactsSelection) { contact in
            ContactRow(contact: contact).tag(contact.id)
        }
        .listStyle(.plain)
        .overlay {
            if results.isEmpty { ContentUnavailableView.search(text: query) }
        }
    }
}
