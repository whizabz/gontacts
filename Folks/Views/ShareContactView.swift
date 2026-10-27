import SwiftUI
import UIKit

/// "Share Contact". For your own card, once you have contact cards, it first asks which card to share (or Custom).
/// For anyone else, or when you have no cards yet, it goes straight to picking details.
/// (iOS has no public version of this screen, so it's built from system pieces.)
struct ShareContactView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let contact: Contact
    /// Called with the .vcf to share; the caller opens the iOS share sheet once this screen has closed.
    let onShare: (URL) -> Void

    @State private var selectedCard: UUID
    @State private var showCustom = false
    @State private var showQR = false
    @State private var qrFields: Set<ShareField> = []
    @State private var qrCard: ContactCard?

    init(contact: Contact, onShare: @escaping (URL) -> Void) {
        self.contact = contact
        self.onShare = onShare
        _selectedCard = State(initialValue: ContactCard.fullID)
    }

    private var cards: [ContactCard] {
        model.store.myCard?.id == contact.id ? model.cards.cards : []
    }

    private var selectedFields: Set<ShareField> {
        if selectedCard == ContactCard.fullID { return contact.allShareFields }
        return model.cards.card(selectedCard).map { contact.shareFields(for: $0.fields) } ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    CustomShareView(contact: contact, isRoot: true, onShare: send, onQR: { qrFields = $0; qrCard = $1; showQR = true })
                } else {
                    cardList
                }
            }
            .navigationDestination(isPresented: $showQR) { ContactQRView(contact: contact.keeping(qrFields), card: qrCard) }
        }
        .onAppear {
            if let last = model.cards.lastUsedID, last == ContactCard.fullID || model.cards.card(last) != nil { selectedCard = last }
        }
    }

    // MARK: Choose a card

    private var cardList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose a card").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 20).padding(.bottom, -8)
                VStack(spacing: 0) {
                    cardRow(id: ContactCard.fullID, name: "Full contact", summary: "Everything · \(contact.allShareFields.count) details",
                            symbol: "person.text.rectangle", color: 0)
                    ForEach(cards) { card in
                        Divider().padding(.leading, 70)
                        cardRow(id: card.id, name: card.name, summary: contact.cardSummary(card.fields), symbol: card.symbol, color: card.colorIndex)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))

                Button { showCustom = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "slider.horizontal.3").font(.title3).foregroundStyle(.secondary)
                            .frame(width: 40, height: 40).background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom").font(.body)
                            Text("Pick individual details only for this share").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Share Contact")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showCustom) {
            CustomShareView(contact: contact, isRoot: false, onShare: send, onQR: { qrFields = $0; qrCard = $1; showQR = true })
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
        }
        .safeAreaInset(edge: .bottom) {
            ShareActions(disabled: selectedFields.isEmpty, share: shareSelectedCard) {
                qrFields = selectedFields; model.cards.lastUsedID = selectedCard; showQR = true
            }
        }
    }

    private func cardRow(id: UUID, name: String, summary: String, symbol: String, color: Int) -> some View {
        Button { selectedCard = id } label: {
            HStack(spacing: 14) {
                CardTile(symbol: symbol, colorIndex: color, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.headline).foregroundStyle(.primary)
                    Text(summary).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                // Always takes up its space, so the text doesn't re-wrap when the tick moves.
                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.tint)
                    .opacity(selectedCard == id ? 1 : 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedCard == id ? .isSelected : [])
    }

    private func shareSelectedCard() {
        model.cards.lastUsedID = selectedCard
        send(selectedFields, saveAs: nil)
    }

    private func send(_ fields: Set<ShareField>, saveAs card: ContactCard?) {
        guard let url = try? contact.keeping(fields).writeVCardFile() else { return }
        if var card {
            card.fields = contact.shareKeys(for: fields)
            model.cards.save(card)
            model.cards.lastUsedID = card.id
        }
        onShare(url)
        dismiss()
    }
}

/// Pick individual details to share. Also the whole Share Contact screen when there are no cards to choose from.
private struct CustomShareView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let contact: Contact
    /// True when this is the first screen, so it has its own close button and the title "Share Contact".
    let isRoot: Bool
    let onShare: (Set<ShareField>, ContactCard?) -> Void
    let onQR: (Set<ShareField>, ContactCard?) -> Void

    @State private var chosen: Set<ShareField>
    @State private var saveAsCard = false
    @State private var draft = ContactCard(name: "", symbol: "briefcase", colorIndex: 1, fields: [])
    @State private var pickingIcon = false
    /// Set once the card is saved, so the screen can say so.
    @State private var savedName: String?
    @State private var savedCard: ContactCard?

    init(contact: Contact, isRoot: Bool, onShare: @escaping (Set<ShareField>, ContactCard?) -> Void, onQR: @escaping (Set<ShareField>, ContactCard?) -> Void) {
        self.contact = contact
        self.isRoot = isRoot
        self.onShare = onShare
        self.onQR = onQR
        // Like iOS: name, phones and emails start selected; the rest is opt-in.
        var start: Set<ShareField> = []
        if !contact.displayName.isEmpty { start.insert(.name) }
        contact.phones.forEach { start.insert(.phone($0.id)) }
        contact.emails.forEach { start.insert(.email($0.id)) }
        _chosen = State(initialValue: start)
    }

    private var allFields: Set<ShareField> { contact.allShareFields }
    private var isMyCard: Bool { model.store.myCard?.id == contact.id }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Only selected details are shared").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Button(chosen == allFields ? "Deselect All" : "Select All") {
                        chosen = chosen == allFields ? [] : allFields
                    }
                    .font(.footnote.weight(.semibold))
                    // The label just swaps, with no animation.
                    .contentTransition(.identity)
                    .animation(nil, value: chosen == allFields)
                }
                .padding(.horizontal, 20).padding(.bottom, -8)
                ShareFieldList(contact: contact, chosen: $chosen)
                if isMyCard { saveSection }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isRoot ? "Share Contact" : "Custom")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $pickingIcon) { CardIconPicker(symbol: $draft.symbol, colorIndex: $draft.colorIndex) }
        .sensoryFeedback(.success, trigger: savedName)
        .toolbar {
            if isRoot {
                ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
            }
            // With the switch on this saves the card; otherwise (or once it's saved) it just closes the screen.
            ToolbarItem(placement: .confirmationAction) {
                let saving = pendingCard() != nil
                Button(saving ? "Save" : "Done") {
                    if saving { saveCard() } else { dismiss() }
                }
                .fontWeight(.semibold)
                .contentTransition(.identity)
                .disabled(saving && chosen.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ShareActions(disabled: chosen.isEmpty, share: share) { let card = pendingCard() ?? savedCard; saveCard(); onQR(chosen, card) }
        }
    }

    /// "Save as a new contact card": keeps these details as a card while sharing them.
    private var saveSection: some View {
        VStack(spacing: 0) {
            if let savedName {
                Label("Saved as \u{201C}\(savedName)\u{201D} in Contact Cards", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            } else {
                Toggle("Save as a new contact card", isOn: $saveAsCard.animation())
                    .padding(.horizontal, 16).frame(minHeight: 48)
            }
            if saveAsCard, savedName == nil {
                Divider().padding(.leading, 16)
                HStack(spacing: 12) {
                    Button { pickingIcon = true } label: {
                        CardTile(symbol: draft.symbol, colorIndex: draft.colorIndex, size: 40)
                            .overlay(alignment: .bottomTrailing) { PencilBadge(size: 20).offset(x: 5, y: 5) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change icon")
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Name").font(.caption).foregroundStyle(.secondary)
                        TextField("Card name", text: $draft.name).font(.body.weight(.semibold))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
    }

    /// The card to save from what's ticked, or nil when the switch is off or it's already saved.
    private func pendingCard() -> ContactCard? {
        guard isMyCard, saveAsCard, savedName == nil else { return nil }
        var card = draft
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        card.name = name.isEmpty ? model.cards.nextDefaultName() : name
        card.id = UUID()
        card.fields = contact.shareKeys(for: chosen)
        return card
    }

    private func saveCard() {
        guard let card = pendingCard() else { return }
        model.cards.save(card)
        savedCard = card
        withAnimation {
            savedName = card.name
            saveAsCard = false
        }
    }

    /// Sharing also saves the card if the switch is still on, so it isn't lost.
    private func share() { onShare(chosen, pendingCard()) }
}

/// The two ways to send what's chosen: the iOS share sheet, or a QR code.
private struct ShareActions: View {
    let disabled: Bool
    let share: () -> Void
    let showQR: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: share) {
                Label("Share", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent).prominentButtonShadow()
            Button(action: showQR) {
                Label("Show QR Code", systemImage: "qrcode").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .controlSize(.extraLarge)
        .disabled(disabled)
        .padding(.horizontal, 20).padding(.bottom, 8)
    }
}

/// The groups of tickable details for a contact. Used by Share and by Edit Contact Card.
struct ShareFieldList: View {
    let contact: Contact
    @Binding var chosen: Set<ShareField>

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(contact.shareGroups.enumerated()), id: \.offset) { _, rows in
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Divider().padding(.leading, 56) }
                        fieldRow(row)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
            }
        }
    }

    private func fieldRow(_ row: ShareRow) -> some View {
        let on = chosen.contains(row.field)
        return Button {
            if on { chosen.remove(row.field) } else { chosen.insert(row.field) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(on ? Color.accentColor : Color.accentColor.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.label).font(.subheadline).foregroundStyle(.secondary)
                    Text(row.value).foregroundStyle(.primary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Opens the standard iOS share sheet over whatever is on screen.
@MainActor
enum ShareSheet {
    static func present(_ url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var top = scene.keyWindow?.rootViewController else { return }
        while let next = top.presentedViewController { top = next }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.maxX - 40, y: 60, width: 1, height: 1)
        top.present(sheet, animated: true)
    }
}
