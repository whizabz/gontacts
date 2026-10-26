import AppIntents
import SwiftUI
import WidgetKit

/// A contact card the QR widget can be pointed at.
struct QRCardEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Contact Card"
    static let defaultQuery = QRCardQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct QRCardQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [QRCardEntity] {
        WidgetStore.readQRCards().filter { identifiers.contains($0.id) }.map { QRCardEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [QRCardEntity] {
        WidgetStore.readQRCards().map { QRCardEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> QRCardEntity? {
        WidgetStore.readQRCards().first.map { QRCardEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectQRCardIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Contact Card"
    static let description = IntentDescription("The contact card whose QR code this widget shows.")

    @Parameter(title: "Card") var card: QRCardEntity?
}

struct QREntry: TimelineEntry {
    let date: Date
    /// Nil until the app has published your cards.
    let card: QRCardSnapshot?
}

struct QRProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QREntry {
        QREntry(date: .now, card: QRCardSnapshot(id: "x", name: "Work", symbol: "briefcase", colorIndex: 1, vCard: "BEGIN:VCARD"))
    }

    func snapshot(for configuration: SelectQRCardIntent, in context: Context) async -> QREntry { entry(for: configuration) }

    func timeline(for configuration: SelectQRCardIntent, in context: Context) async -> Timeline<QREntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SelectQRCardIntent) -> QREntry {
        let cards = WidgetStore.readQRCards()
        let chosen = cards.first { $0.id == configuration.card?.id } ?? cards.first
        return QREntry(date: .now, card: chosen)
    }
}

/// A QR code of one of your contact cards, in the small and large square sizes.
struct QRWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ContactQR", intent: SelectQRCardIntent.self, provider: QRProvider()) { entry in
            QRRoot(entry: entry)
        }
        .configurationDisplayName("QR Code")
        .description("Share one of your contact cards: anyone can scan the code with their Camera app.")
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct QRRoot: View {
    @Environment(\.widgetFamily) private var family
    let entry: QREntry

    var body: some View {
        let large = family == .systemLarge
        Group {
            if let card = entry.card, let image = QRCode.image(from: card.vCard, modulesOnly: true) {
                // The code is a template image: dark on a white widget, light on a black one, and in the clear look
                // it is drawn in the tint colour straight onto the glass.
                Image(uiImage: image)
                    .renderingMode(.template)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
                    .widgetAccentable()
                    .padding(large ? 20 : 10)
                    .accessibilityLabel("QR code for \(card.name)")
                    .widgetURL(WidgetStore.cardURL(for: card.id))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "qrcode").font(.system(size: large ? 44 : 28))
                    Text(entry.card == nil ? "Open Gontacts to set up your cards" : "Too much for a QR code. Untick some details.")
                        .font(.system(size: large ? 15 : 11)).multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .padding(16)
            }
        }
        .containerBackground(for: .widget) { Color(light: 0xFFFFFF, dark: 0x000000) }
    }
}
