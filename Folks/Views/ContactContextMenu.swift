import AppIntents
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The press-and-hold menu on a contact in a list, as in iOS Contacts: Message, Call and Video hand off to iOS;
/// Copy, Share, My Card and Delete are ours.
private struct ContactContextMenu: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let contact: Contact

    func body(content: Content) -> some View {
        content
            .appEntityIdentifier(EntityIdentifier(for: ContactEntity.self, identifier: contact.id))
            .contextMenu {
            let phones = contact.phones.filter { !$0.value.isEmpty }
            if !phones.isEmpty {
                numberMenu("Message", "message", scheme: "sms:", phones)
                numberMenu("Call", "phone", scheme: "tel:", phones)
                numberMenu("Video", "video", scheme: "facetime:", phones)
                Divider()
            }
            Button("Copy", systemImage: "doc.on.doc") { copy() }
            Button("Share", systemImage: "square.and.arrow.up") { model.shareRequest = contact }
            if model.store.canSync {
                let isMine = model.store.myCard?.id == contact.id
                Divider()
                Button(isMine ? "Remove as My Card" : "Make This My Card", systemImage: "person.crop.circle") {
                    model.store.setMyCard(isMine ? "" : contact.id)
                }
            }
            Divider()
            Button("Delete Contact", systemImage: "trash", role: .destructive) { model.deleteRequest = contact }
        }
    }

    private func numberMenu(_ title: String, _ symbol: String, scheme: String, _ phones: [LabeledValue]) -> some View {
        Menu {
            ForEach(phones) { p in
                Button("\(p.label.displayLabel)  \(p.value)") {
                    if let url = URL(string: scheme + ContactDetailView.digits(p.value)) { openURL(url) }
                }
            }
        } label: { Label(title, systemImage: symbol) }
    }

    /// Puts the contact on the pasteboard as a vCard, with the same text as a plain-text fallback.
    private func copy() {
        let card = contact.vCard
        UIPasteboard.general.setItems([[UTType.vCard.identifier: Data(card.utf8), UTType.utf8PlainText.identifier: card]])
    }
}

extension View {
    func contactContextMenu(_ contact: Contact) -> some View { modifier(ContactContextMenu(contact: contact)) }
}
