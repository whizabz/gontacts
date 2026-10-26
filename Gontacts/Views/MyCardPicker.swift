import SwiftUI

/// Pick which contact is you ("My Card"), or none. Used from Settings and the onboarding step.
struct MyCardPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Called after a choice is made (the onboarding flow uses it to move on). Settings just goes back.
    var onPicked: (() -> Void)?
    @State private var query = ""

    var body: some View {
        let currentID = model.store.myCard?.id
        List {
            if query.isEmpty {
                Button { choose(nil) } label: {
                    HStack {
                        Text("None").foregroundStyle(.primary)
                        Spacer()
                        if currentID == nil { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
            }
            ForEach(model.store.search(query)) { contact in
                Button { choose(contact.id) } label: {
                    HStack {
                        ContactRow(contact: contact)
                        Spacer()
                        if contact.id == currentID { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .navigationTitle("My Card")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search contacts")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }

    private func choose(_ id: String?) {
        // An empty id means "none, and don't guess from the account email".
        model.store.setMyCard(id ?? "")
        if let onPicked { onPicked() } else { dismiss() }
    }
}

/// Optional onboarding step, right after signing in: confirm or choose which contact is you.
struct MyCardSetupView: View {
    @Environment(AppModel.self) private var model
    let onDone: () -> Void
    @State private var choosing = false

    var body: some View {
        let suggestion = model.store.myCard
        VStack(alignment: .leading, spacing: 16) {
            Text("Which contact is you?").font(.largeTitle.bold())
            Text("Your own contact stays at the top of Contacts, like My Card in iOS Contacts. You can change this any time in Settings.")
                .font(.title3).foregroundStyle(.secondary)

            if let suggestion {
                HStack(spacing: 14) {
                    AvatarView(contact: suggestion, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.displayName).font(.title3.weight(.semibold))
                        Text("Found using your Google email address").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(.top, 8)
            }

            Spacer()

            if let suggestion {
                Button {
                    model.store.setMyCard(suggestion.id)
                    onDone()
                } label: {
                    Text("Use this contact").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent).prominentButtonShadow().controlSize(.extraLarge)
                Button { choosing = true } label: {
                    Text("Choose a different contact").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass).controlSize(.extraLarge)
            } else {
                Button { choosing = true } label: {
                    Text("Choose my contact").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent).prominentButtonShadow().controlSize(.extraLarge)
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Skip") {
                // Skipping means no My Card (an empty id also stops the automatic email match).
                model.store.setMyCard("")
                onDone()
            } }
        }
        .sheet(isPresented: $choosing) {
            NavigationStack {
                MyCardPicker { choosing = false; onDone() }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { choosing = false } } }
            }
        }
    }
}
