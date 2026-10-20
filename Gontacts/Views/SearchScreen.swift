import SwiftUI

/// Full-screen contact search. The leading control is a plain back chevron, so it's obvious it returns to
/// where you were (the system search tab shows the previous tab's icon there instead).
struct SearchScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [Contact] { model.store.search(query) }

    var body: some View {
        NavigationStack {
            List(results) { contact in
                NavigationLink(value: contact.id) { ContactRow(contact: contact) }
            }
            .listStyle(.plain)
            .navigationDestination(for: String.self) { ContactDetailView(contactID: $0) }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if results.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.title3.weight(.semibold)).frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Back")

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search contacts", text: $query)
                            .focused($focused)
                            .submitLabel(.search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Clear")
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .onAppear { focused = true }
    }
}
