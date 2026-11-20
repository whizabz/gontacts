import UIKit

/// Holds the profile photos of people with an event today, decoded and ready, so opening one of them
/// shows the photo at once instead of fetching it while the celebration plays.
///
/// In memory only: nothing is written to storage, and it empties itself when the app quits, when iOS needs the
/// memory back, and whenever the set of today's people changes. A handful of small images is all it ever holds.
@MainActor
final class PhotoCache {
    static let shared = PhotoCache()

    private var images: [URL: UIImage] = [:]

    init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.images.removeAll() }
        }
    }

    func image(for url: URL) -> UIImage? { images[url] }

    /// True when there is nothing to wait for: no photo, a bundled demo photo, or one that is already loaded.
    func isReady(_ url: URL?) -> Bool {
        guard let url else { return true }
        return url.scheme == "sample" || images[url] != nil
    }

    /// Keeps exactly these photos: anything else is dropped, and the missing ones are downloaded and decoded.
    func prefetch(_ urls: Set<URL>) async {
        for url in images.keys where !urls.contains(url) { images[url] = nil }
        for url in urls where url.scheme != "sample" && images[url] == nil {
            guard let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) else { continue }
            // Decoding here, off the main thread, is what keeps the page from hitching when it shows the photo.
            images[url] = await image.byPreparingForDisplay() ?? image
        }
    }
}
