import SwiftUI

struct ContactRow: View {
    @Environment(AppModel.self) private var model
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(contact: contact, size: 40)
            Text(contact.displayName)
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
    @Environment(\.horizontalSizeClass) private var sizeClass

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
                            ContactRow(contact: contact).tag(contact.id)
                        }
                    }
                    .sectionIndexLabel(section.letter)
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
                if sizeClass == .regular {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { model.showSearch = true } label: { Label("Search", systemImage: "magnifyingglass") }
                    }
                }
                if model.store.canSync {
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
