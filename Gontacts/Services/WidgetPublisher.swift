import Foundation
import UIKit
import WidgetKit

/// Keeps the home-screen and lock-screen widgets up to date: after the contacts change, writes what the widgets
/// need to the App Group, fetches photo thumbnails for people with a celebration soon, and asks WidgetKit to reload.
@MainActor
enum WidgetPublisher {
    private static var pending: Task<Void, Never>?

    static func publish(_ contacts: [Contact]) {
        pending?.cancel()
        pending = Task {
            // Contacts change in bursts (a sync, an edit): wait for it to settle.
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            WidgetStore.write(contacts)
            WidgetCenter.shared.reloadAllTimelines()

            let soon = upcoming(contacts)
            WidgetStore.prunePhotos(keeping: Set(soon.map(\.id)))
            var fetched = false
            for contact in soon where !WidgetStore.hasPhoto(for: contact.id) {
                guard !Task.isCancelled, let url = contact.photoURL else { continue }
                if let data = await thumbnail(from: url) {
                    WidgetStore.savePhoto(data, for: contact.id)
                    fetched = true
                }
            }
            if fetched { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    /// People with a birthday or anniversary in the next six weeks (the most a widget shows), with a photo.
    private static func upcoming(_ contacts: [Contact]) -> [Contact] {
        let now = Date.now
        let end = Calendar.current.date(byAdding: .day, value: 42, to: now) ?? now
        let ids = Set(EventTimeline.occurrences(for: contacts.filter { $0.photoURL != nil }, from: now, to: end)
            .filter { $0.event.kind != .other }.map(\.contactID))
        return contacts.filter { ids.contains($0.id) }
    }

    private static func thumbnail(from url: URL) async -> Data? {
        guard let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) else { return nil }
        let side: CGFloat = 160
        let scale = max(side / image.size.width, side / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
