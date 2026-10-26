import SwiftUI
import WidgetKit

@main
struct GontactsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CelebrationsWidget()
        SpotlightWidget()
        QRWidget()
    }
}

/// Small, medium (list), large and lock-screen widgets.
struct CelebrationsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Celebrations", provider: CelebrationProvider()) { entry in
            CelebrationsRoot(entry: entry)
        }
        .configurationDisplayName("Celebrations")
        .description("Birthdays and anniversaries from your contacts, today and coming up.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

/// A medium widget that spotlights the next celebration.
struct SpotlightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CelebrationSpotlight", provider: CelebrationProvider()) { entry in
            SpotlightRoot(entry: entry)
        }
        .configurationDisplayName("Spotlight")
        .description("Today's birthday or anniversary, large, with the next one underneath.")
        .supportedFamilies([.systemMedium])
    }
}
