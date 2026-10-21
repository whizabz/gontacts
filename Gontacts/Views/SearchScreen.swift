import SwiftUI

/// Contact search, the content of the system search tab. Results open inside this tab, so going back from a
/// contact returns to the results.
struct SearchScreen: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    private var results: [Contact] { model.store.search(query) }

    var body: some View {
        NavigationStack {
            List(results) { contact in
                NavigationLink(value: contact.id) { ContactRow(contact: contact) }
                    .navigationLinkIndicatorVisibility(.hidden)
            }
            .listStyle(.plain)
            .overlay {
                if results.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .navigationTitle("Search")
            .navigationDestination(for: String.self) { ContactDetailView(contactID: $0) }
        }
        .searchable(text: $query, prompt: "Search contacts")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }
}
