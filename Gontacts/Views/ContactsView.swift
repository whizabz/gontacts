import SwiftUI

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(contact: contact, size: 40)
            Text(contact.displayName)
            Spacer(minLength: 0)
            if !EventTimeline.events(on: .now, for: contact).isEmpty {
                Image(systemName: "birthday.cake").foregroundStyle(.pink).imageScale(.small)
                    .accessibilityLabel("Event today")
            }
        }
    }
}

struct ContactsView: View {
    @Environment(AppModel.self) private var model
    @State private var showNew = false

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
                ForEach(sections, id: \.letter) { section in
                    Section(section.letter) {
                        ForEach(section.contacts) { contact in
                            NavigationLink(value: contact.id) { ContactRow(contact: contact) }
                        }
                    }
                }
                Section {} footer: {
                    Text("\(model.store.contacts.count) Contacts").frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListHeaderHeight, 30)
            .listSectionSpacing(.compact)
            .listSectionIndexVisibility(.visible)
            .navigationTitle("Contacts")
            .refreshable { await model.store.sync() }
            .toolbar {
                if model.store.mode == .google {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Task { await model.store.sync() } } label: {
                            Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .symbolEffect(.rotate, isActive: model.store.isSyncing)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Label("New Contact", systemImage: "plus") }
                }
            }
            .overlay {
                if model.store.contacts.isEmpty {
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

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    private var results: [Contact] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.store.sorted }
        return model.store.sorted.filter {
            $0.displayName.localizedStandardContains(q)
                || $0.organization.localizedStandardContains(q)
                || $0.phones.contains { $0.value.contains(q) }
                || $0.emails.contains { $0.value.localizedStandardContains(q) }
        }
    }

    var body: some View {
        NavigationStack {
            List(results) { contact in
                NavigationLink(value: contact.id) { ContactRow(contact: contact) }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .navigationDestination(for: String.self) { ContactDetailView(contactID: $0) }
            .searchable(text: $query, prompt: "Contacts")
            .overlay {
                if results.isEmpty { ContentUnavailableView.search(text: query) }
            }
        }
    }
}
