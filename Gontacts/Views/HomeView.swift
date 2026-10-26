import SwiftUI

/// The whole app in one screen, like iOS Contacts: a segmented control at the top switches between the
/// Contacts list and the Events list; Settings opens from the toolbar.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false
    @State private var showNew = false
    @State private var query = ""
    @State private var pendingShare: URL?

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            Group {
                switch model.homeMode {
                case .contacts:
                    if query.isEmpty { ContactsList() } else { ContactSearchResults(query: query) }
                case .events:
                    EventsList(query: query)
                }
            }
            // Search and add live here, not in either list, so they stay put on both Contacts and Events.
            .searchable(text: $query, prompt: model.homeMode == .events ? "Search events" : "Search contacts")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $model.homeMode) {
                        ForEach(HomeMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(minWidth: 250, maxWidth: 320)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
                // As in iOS Contacts: the search field in the bottom bar with the add button beside it.
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button { showNew = true } label: { Label("New Contact", systemImage: "plus") }
                }
            }
        } detail: {
            NavigationStack {
                switch model.homeMode {
                case .contacts:
                    if let id = model.contactsSelection {
                        ContactDetailView(contactID: id)
                    } else {
                        ContentUnavailableView("Select a Contact", systemImage: "person.crop.circle")
                    }
                case .events:
                    if let selection = model.eventsSelection {
                        // List selection is the occurrence id ("contactID|event|time"); the contact id is its first part.
                        ContactDetailView(contactID: String(selection.prefix { $0 != "|" }))
                    } else {
                        ContentUnavailableView("Select an Event", systemImage: "calendar")
                    }
                }
            }
        }
        .sheet(isPresented: $model.showCards, onDismiss: { model.cardRequest = nil }) {
            NavigationStack { ContactCardsView(inSheet: true) }
        }
        .sheet(item: $model.shareRequest, onDismiss: {
            if let url = pendingShare { pendingShare = nil; ShareSheet.present(url) }
        }) { contact in
            ShareContactView(contact: contact) { pendingShare = $0 }
        }
        .confirmationDialog("Delete this contact?", isPresented: Binding(get: { model.deleteRequest != nil }, set: { if !$0 { model.deleteRequest = nil } }), titleVisibility: .visible, presenting: model.deleteRequest) { contact in
            Button("Delete \(contact.displayName)", role: .destructive) {
                Task {
                    do {
                        try await model.store.delete(contact)
                        if model.contactsSelection == contact.id { model.contactsSelection = nil }
                    } catch { model.store.errorMessage = error.localizedDescription }
                }
            }
        } message: { _ in Text("This also deletes it from Google Contacts.") }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showNew) {
            EditContactView(contact: .blank()) { saved in
                model.homeMode = .contacts
                model.contactsSelection = saved.id
            }
        }
    }
}
