import SwiftUI

/// Full-screen contact search, opened from the search tab. The leading control is a plain back chevron that
/// closes search and returns to the screen you came from. (The system search tab would show the previous
/// tab's icon there instead.)
///
/// Picking a result closes search and opens that contact in Contacts, so going back from the contact
/// returns to the Contacts list rather than back into search.
struct SearchScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [Contact] { model.store.search(query) }

    var body: some View {
        List(results) { contact in
            Button {
                dismiss()
                model.open(contactID: contact.id, wish: false)
            } label: {
                ContactRow(contact: contact).contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
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
        .onAppear { focused = true }
        .onDisappear { query = "" }
    }
}
