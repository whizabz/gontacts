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

struct ContactsView: View {
    @Environment(AppModel.self) private var model
    @State private var showNew = false
    @AppStorage("contacts.sort") private var sort = ContactSort.name
    @State private var query = ""

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
        NavigationSplitView {
            List(selection: $model.contactsSelection) {
                if !query.isEmpty {
                    ForEach(model.store.search(query)) { contact in
                        ContactRow(contact: contact).tag(contact.id)
                    }
                } else if sort == .recent {
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
                if query.isEmpty {
                    Section {} footer: {
                        Text("\(model.store.contacts.count) Contacts").frame(maxWidth: .infinity)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListHeaderHeight, 30)
            .listSectionSpacing(.compact)
            .listSectionIndexVisibility(sort == .name && query.isEmpty ? .visible : .hidden)
            .navigationTitle("Contacts")
            .refreshable { await model.store.sync() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $sort) {
                            ForEach(ContactSort.allCases) { Text($0.title).tag($0) }
                        }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Label("New Contact", systemImage: "plus") }
                }
            }
            // Search is an icon in the toolbar that expands into a field; results filter this list in place.
            .searchable(text: $query, prompt: "Search contacts")
            .searchToolbarBehavior(.minimize)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .overlay {
                if !query.isEmpty && model.store.search(query).isEmpty {
                    ContentUnavailableView.search(text: query)
                } else if model.store.contacts.isEmpty {
                    ContentUnavailableView("No Contacts", systemImage: "person.2", description: Text("Pull down to sync, or tap + to add one."))
                }
            }
        } detail: {
            NavigationStack {
                if let id = model.contactsSelection {
                    ContactDetailView(contactID: id)
                } else {
                    ContentUnavailableView("Select a Contact", systemImage: "person.crop.circle")
                }
            }
        }
        .sheet(isPresented: $showNew) {
            EditContactView(contact: .blank()) { saved in model.contactsSelection = saved.id }
        }
    }
}
