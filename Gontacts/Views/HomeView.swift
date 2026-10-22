import SwiftUI

/// The whole app in one screen, like iOS Contacts: a segmented control at the top switches between the
/// Contacts list and the Events list; Settings opens from the toolbar.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            Group {
                switch model.homeMode {
                case .contacts: ContactsList()
                case .events: EventsList()
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $model.homeMode) {
                        ForEach(HomeMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
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
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}
