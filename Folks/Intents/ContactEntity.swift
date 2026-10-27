import AppIntents
import CoreTransferable
import UniformTypeIdentifiers

/// Describes a contact to Siri and Shortcuts. Rows and contact screens are tagged with it, which is what lets
/// iOS offer "Ask Siri" on a contact (Siri can then see which contact is on screen and read its vCard).
struct ContactEntity: AppEntity, Transferable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Contact"
    static let defaultQuery = ContactEntityQuery()

    var id: String
    @Property(title: "Name") var name: String
    var vCard: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ contact: Contact) {
        id = contact.id
        vCard = contact.vCard
        name = contact.displayName
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .vCard) { Data($0.vCard.utf8) }
    }
}

struct ContactEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ContactEntity] {
        await MainActor.run {
            identifiers.compactMap { ContactDirectory.store?.contact(id: $0) }.map(ContactEntity.init)
        }
    }

    func suggestedEntities() async throws -> [ContactEntity] { [] }
}

/// Lets the Siri/Shortcuts side look contacts up in the running app.
@MainActor
enum ContactDirectory {
    static weak var store: ContactsStore?
}

/// "Open <contact>" for Siri and Shortcuts.
struct OpenContactIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Contact"

    @Parameter(title: "Contact") var target: ContactEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.current?.open(contactID: target.id, wish: false)
        return .result()
    }
}
